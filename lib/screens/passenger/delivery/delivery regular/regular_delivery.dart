// lib/presentation/screens/passenger/delivery/delivery_tracking_regular.dart
//
// REGULAR DELIVERY TRACKING
// Shows step-by-step stage updates. No live map.
// Listens to:
//   delivery:status_update   → advance stage
//   delivery:completed       → show complete screen
//   delivery:cancelled       → show cancellation

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../../../core/config.dart';

class DeliveryTrackingRegular extends StatefulWidget {
  final Map<String, dynamic> delivery;
  final String accessToken;

  const DeliveryTrackingRegular({
    super.key,
    required this.delivery,
    required this.accessToken,
  });

  @override
  State<DeliveryTrackingRegular> createState() =>
      _DeliveryTrackingRegularState();
}

class _DeliveryTrackingRegularState extends State<DeliveryTrackingRegular>
    with SingleTickerProviderStateMixin {

  io.Socket? _socket;
  String     _currentStatus = 'accepted';
  bool       _delivered     = false;
  bool       _cancelled     = false;
  String?    _cancelReason;
  Map<String, dynamic>? _driver;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  // Stage definitions in order
  static const _stages = [
    ('accepted',        '✅', 'Driver accepted',     'Your driver is on the way to pick up your package'),
    ('en_route_pickup', '🚗', 'Heading to pickup',   'Driver is heading to your pickup location'),
    ('arrived_pickup',  '📍', 'Arrived at pickup',   'Driver has arrived — prepare your package'),
    ('picked_up',       '📦', 'Package collected',   'Your package has been picked up'),
    ('en_route_dropoff','🚀', 'Out for delivery',    'Driver is on the way to the recipient'),
    ('arrived_dropoff', '🏁', 'At destination',      'Driver has arrived — recipient should verify PIN'),
    ('delivered',       '🎉', 'Delivered!',           'Your package has been delivered successfully'),
  ];

  int get _currentStageIndex =>
      _stages.indexWhere((s) => s.$1 == _currentStatus).clamp(0, _stages.length - 1);

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _currentStatus = widget.delivery['status'] as String? ?? 'accepted';
    _driver        = widget.delivery['driver'] as Map<String, dynamic>?;
    _connectSocket();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  void _connectSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? widget.accessToken;

    _socket = io.io(AppConfig.socketUrl,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token})
            .disableAutoConnect()
            .build());

    _socket!.connect();

    _socket!.on('delivery:status_update', (data) {
      if (!mounted) return;
      final d      = data as Map<String, dynamic>;
      final status = d['status'] as String?;
      if (status != null) setState(() => _currentStatus = status);
    });

    _socket!.on('delivery:completed', (data) {
      if (!mounted) return;
      setState(() { _currentStatus = 'delivered'; _delivered = true; });
    });

    _socket!.on('delivery:cancelled', (data) {
      if (!mounted) return;
      final d = data as Map<String, dynamic>;
      setState(() {
        _cancelled    = true;
        _cancelReason = d['message'] as String?;
      });
    });

    _socket!.on('delivery:driver_assigned', (data) {
      if (!mounted) return;
      final d = data as Map<String, dynamic>;
      if (d['driver'] != null) setState(() => _driver = d['driver'] as Map<String, dynamic>);
    });
  }

  Future<void> _cancelDelivery() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel delivery?',
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: const Text('Are you sure you want to cancel this delivery?',
            style: TextStyle(fontFamily: 'Roboto', fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Yes, cancel'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final id = widget.delivery['id'];
      await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/deliveries/$id/cancel'),
        headers: {
          'Authorization': 'Bearer ${widget.accessToken}',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'reason': 'Cancelled by sender'}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}

    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    if (_cancelled) return _buildCancelledScreen();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tracking your delivery',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 16,
                    fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            Text(widget.delivery['deliveryCode'] as String? ?? '',
                style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                    color: AppColors.textSecondary)),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: FadeTransition(
        opacity: _fade,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildDriverCard(),
              const SizedBox(height: 20),
              _buildStagesCard(),
              const SizedBox(height: 20),
              _buildDeliveryInfoCard(),
              if (!_delivered && _canCancel()) ...[
                const SizedBox(height: 16),
                _buildCancelButton(),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Driver card ────────────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    final name   = _driver?['name']   as String? ?? 'Your driver';
    final phone  = _driver?['phone']  as String?;
    final rating = _driver?['rating'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
                color: AppColors.primaryGold, shape: BoxShape.circle),
            child: const Icon(Icons.person_rounded,
                color: AppColors.primaryDark, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 15,
                        fontWeight: FontWeight.w700, color: Colors.white)),
                if (rating != null)
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.primaryGold, size: 14),
                    const SizedBox(width: 3),
                    Text(rating.toString(),
                        style: const TextStyle(fontFamily: 'Roboto', fontSize: 12,
                            color: AppColors.primaryGold,
                            fontWeight: FontWeight.w500)),
                  ]),
              ],
            ),
          ),
          if (phone != null)
            GestureDetector(
              onTap: () async {
                final uri = Uri.parse('tel:$phone');
                try {
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                } catch (_) {}
              },
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: AppColors.primaryGold, shape: BoxShape.circle),
                child: const Icon(Icons.phone_rounded,
                    color: AppColors.primaryDark, size: 22),
              ),
            ),
        ],
      ),
    );
  }

  // ── Stages card ────────────────────────────────────────────────────────────

  Widget _buildStagesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery progress',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...List.generate(_stages.length, (i) => _buildStageRow(i)),
        ],
      ),
    );
  }

  Widget _buildStageRow(int index) {
    final stage      = _stages[index];
    final isDone     = index < _currentStageIndex;
    final isActive   = index == _currentStageIndex;
    final isUpcoming = index > _currentStageIndex;
    final isLast     = index == _stages.length - 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline column
        Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.success
                    : isActive
                    ? AppColors.primaryDark
                    : AppColors.borderLight,
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(color: AppColors.primaryGold, width: 2)
                    : null,
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                    : isActive
                    ? Text(stage.$2, style: const TextStyle(fontSize: 14))
                    : Text(stage.$2,
                    style: TextStyle(fontSize: 12,
                        color: AppColors.textLight.withOpacity(0.5))),
              ),
            ),
            if (!isLast)
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 2, height: 36,
                color: isDone ? AppColors.success : AppColors.borderLight,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(stage.$3,
                    style: TextStyle(
                      fontFamily: 'Poppins', fontSize: 13,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isUpcoming ? AppColors.textLight : AppColors.textPrimary,
                    )),
                if (isActive) ...[
                  const SizedBox(height: 3),
                  Text(stage.$4,
                      style: const TextStyle(fontFamily: 'Roboto', fontSize: 11,
                          color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Delivery info card ─────────────────────────────────────────────────────

  Widget _buildDeliveryInfoCard() {
    final d = widget.delivery;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _infoRow('📍 Pickup',   d['pickupAddress']  as String? ?? '—'),
          const Divider(height: 16),
          _infoRow('🏁 Dropoff',  d['dropoffAddress'] as String? ?? '—'),
          const Divider(height: 16),
          _infoRow('💳 Payment',  _paymentLabel(d['paymentMethod'] as String? ?? '')),
          const Divider(height: 16),
          _infoRow('💰 Total',    '${d['totalPrice']} XAF'),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(
              fontFamily: 'Roboto', fontSize: 12, color: AppColors.textSecondary)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(
              fontFamily: 'Roboto', fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  String _paymentLabel(String method) {
    const map = {
      'mtn_mobile_money': 'MTN MoMo',
      'orange_money':     'Orange Money',
      'cash':             'Cash',
    };
    return map[method] ?? method;
  }

  // ── Cancel ─────────────────────────────────────────────────────────────────

  bool _canCancel() {
    const cancellable = ['accepted', 'en_route_pickup'];
    return cancellable.contains(_currentStatus);
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _cancelDelivery,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.error,
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Cancel delivery',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Cancelled screen ───────────────────────────────────────────────────────

  Widget _buildCancelledScreen() {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                    color: AppColors.errorLight, shape: BoxShape.circle),
                child: const Icon(Icons.cancel_rounded,
                    color: AppColors.error, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('Delivery cancelled',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                  _cancelReason ?? 'This delivery has been cancelled.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((r) => r.isFirst),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  child: const Text('Back to home',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}