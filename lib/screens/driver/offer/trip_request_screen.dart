// lib/screens/driver/trip/trip_request_screen.dart

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:wego_v1/utils/app_colors.dart';

class TripRequestScreen extends StatefulWidget {
  final Map<String, dynamic> offer;
  final Future<bool> Function(Map<String, dynamic>) onAccept;
  final Future<void> Function(Map<String, dynamic>) onDecline;

  const TripRequestScreen({
    Key? key,
    required this.offer,
    required this.onAccept,
    required this.onDecline,
  }) : super(key: key);

  @override
  State<TripRequestScreen> createState() => _TripRequestScreenState();
}

class _TripRequestScreenState extends State<TripRequestScreen>
    with TickerProviderStateMixin {

  late AnimationController _timerController;
  late AnimationController _pulseController;
  late AnimationController _shakeController;

  late Animation<double> _timerAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  late int remainingSeconds;
  late int totalSeconds;

  // Single source of truth — countdown drives both UI counter and animation
  Timer? _countdownTimer;
  bool _isProcessing = false;
  bool _hasTimedOut  = false;

  // ═══════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();

    totalSeconds     = _getExpiresInSeconds();
    remainingSeconds = totalSeconds;

    debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚨 [TRIP-REQUEST] Screen initialized');
    debugPrint('⏰ [TRIP-REQUEST] Timeout: $totalSeconds seconds');
    debugPrint('👤 [TRIP-REQUEST] Passenger: ${_getPassengerName()}');
    debugPrint('🖼️  [TRIP-REQUEST] Avatar: ${_getPassengerAvatarUrl() ?? "none"}');
    debugPrint('📦 Offer keys: ${widget.offer.keys.join(", ")}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    _setupAnimations();
    _startCountdown();
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPERS — data extraction
  // ═══════════════════════════════════════════════════════════════════

  int _getExpiresInSeconds() {
    try {
      final raw = widget.offer['expiresIn'] ??
          widget.offer['expires_in'] ??
          widget.offer['timeout'];

      if (raw is int)    return raw;
      if (raw is double) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? 25;

      debugPrint('⚠️ [TRIP-REQUEST] expiresIn not found, defaulting to 25 s');
      return 25;
    } catch (e) {
      debugPrint('❌ [TRIP-REQUEST] Error reading expiresIn: $e');
      return 25;
    }
  }

  String _getPassengerName() {
    return widget.offer['passenger']?['name']?.toString() ??
        widget.offer['passengerName']?.toString() ??
        'Passenger';
  }

  // ✅ NEW: reads both 'avatar_url' and 'avatar' (backend sends both)
  String? _getPassengerAvatarUrl() {
    final passenger = widget.offer['passenger'];
    if (passenger == null) return null;

    final url = passenger['avatar_url']?.toString() ??
        passenger['avatar']?.toString();

    // Treat empty string as null
    return (url != null && url.isNotEmpty) ? url : null;
  }

  double _getPassengerRating() {
    final rating = widget.offer['passenger']?['rating'] ??
        widget.offer['passengerRating'];

    if (rating == null) return 0.0; // 0 means "no rating yet"
    if (rating is num)  return rating.toDouble();
    return double.tryParse(rating.toString()) ?? 0.0;
  }

  String _getPickupAddress() {
    return widget.offer['pickup']?['address']?.toString() ??
        widget.offer['pickupAddress']?.toString() ??
        'Pickup location';
  }

  String _getDropoffAddress() {
    return widget.offer['dropoff']?['address']?.toString() ??
        widget.offer['destination']?['address']?.toString() ??
        widget.offer['dropoffAddress']?.toString() ??
        'Destination';
  }

  String _getDistance() {
    final raw = widget.offer['distanceM'] ??
        widget.offer['distance'] ??
        widget.offer['distance_km'] ??
        widget.offer['distanceKm'] ??
        0;

    if (raw is num) {
      // If value looks like metres (> 100), convert to km
      final km = raw > 100 ? raw / 1000.0 : raw.toDouble();
      return '${km.toStringAsFixed(1)} km';
    }
    return '$raw km';
  }

  String _getFare() {
    final raw = widget.offer['fareEstimate'] ??
        widget.offer['fare_estimate'] ??
        widget.offer['fare'] ??
        0;

    if (raw is num) return '${raw.toInt()} XAF';
    return '$raw XAF';
  }

  Color _getUrgencyColor() {
    if (remainingSeconds <= 5)  return AppColors.error;
    if (remainingSeconds <= 10) return AppColors.warning;
    return AppColors.info;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANIMATIONS
  // ═══════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    // ── Timer ring — driven by countdown, not by AnimationController ──
    // We keep the controller for the circular indicator but sync it manually
    _timerController = AnimationController(
      duration: Duration(seconds: totalSeconds),
      vsync: this,
    );
    _timerAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _timerController, curve: Curves.linear),
    );
    _timerController.forward();

    // ── Pulse (scales timer circle when urgent) ────────────────────
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // ── Shake (horizontal jolt for urgency) ────────────────────────
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }

      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);

        if (remainingSeconds == 10 || remainingSeconds == 5) {
          _shakeController.forward().then((_) => _shakeController.reverse());
        }
      } else {
        timer.cancel();
        _handleTimeout();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _handleAccept() async {
    if (_isProcessing || _hasTimedOut) return;
    setState(() => _isProcessing = true);

    try {
      _countdownTimer?.cancel();
      debugPrint('✅ [TRIP-REQUEST] Accepting...');

      final success = await widget.onAccept(widget.offer);
      if (!mounted) return;

      if (success) {
        Navigator.pop(context);
      } else {
        setState(() => _isProcessing = false);
        _showErrorDialog(
          title: 'Trip Already Taken',
          message: 'Another driver has already accepted this trip.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorDialog(
        title: 'Connection Error',
        message: 'Failed to accept trip. Please try again.',
        onRetry: _handleAccept,
      );
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing || _hasTimedOut) return;
    setState(() => _isProcessing = true);

    try {
      _countdownTimer?.cancel();
      await widget.onDecline(widget.offer);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Future<void> _handleTimeout() async {
    if (_isProcessing || _hasTimedOut) return;
    _hasTimedOut = true;

    debugPrint('⏰ [TRIP-REQUEST] Timed out');

    try {
      await widget.onDecline(widget.offer);
    } catch (_) {}

    if (!mounted) return;
    _showTimeoutDialog();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _timerController.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time, color: AppColors.warning, size: 24),
          ),
          const SizedBox(width: 12),
          const Text('Request Expired',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'You didn\'t respond in time. The trip request has been declined automatically.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                foregroundColor: AppColors.primaryBlack,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Okay',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog({
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error_outline, color: AppColors.error, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Text(message,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        actions: [
          if (onRetry != null) ...[
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderLight),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () { Navigator.pop(context); onRetry(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGold,
                    foregroundColor: AppColors.primaryBlack,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: AppColors.primaryBlack,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Okay',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTimerSection(),
                const SizedBox(height: 32),
                Expanded(child: _buildTripDetails()),
                const SizedBox(height: 24),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TIMER SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTimerSection() {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (_, __) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Transform.scale(
                scale: remainingSeconds <= 10 ? _pulseAnimation.value : 1.0,
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getUrgencyColor().withOpacity(0.1),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _timerAnimation,
                        builder: (_, __) => CircularProgressIndicator(
                          value: _timerAnimation.value,
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation(_getUrgencyColor()),
                          backgroundColor: AppColors.borderLight,
                        ),
                      ),
                      Text(
                        '$remainingSeconds',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: _getUrgencyColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'New Trip Request',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              remainingSeconds <= 5
                  ? 'Hurry! Request expires soon!'
                  : '$remainingSeconds seconds to respond',
              style: TextStyle(
                fontSize: 14,
                fontWeight: remainingSeconds <= 5 ? FontWeight.w700 : FontWeight.w400,
                color: remainingSeconds <= 5 ? AppColors.error : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // TRIP DETAILS CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildTripDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowMedium,
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPassengerInfo(),
          const SizedBox(height: 20),
          Divider(color: AppColors.borderLight, height: 1),
          const SizedBox(height: 20),
          _buildLocationRow(
            icon: Icons.location_on,
            label: 'Pickup',
            address: _getPickupAddress(),
            color: AppColors.success,
            backgroundColor: AppColors.successLight,
          ),
          const SizedBox(height: 16),
          _buildLocationRow(
            icon: Icons.flag,
            label: 'Destination',
            address: _getDropoffAddress(),
            color: AppColors.error,
            backgroundColor: AppColors.errorLight,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.straighten,
                  label: 'Distance',
                  value: _getDistance(),
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.account_balance_wallet,
                  label: 'Fare',
                  value: _getFare(),
                  color: AppColors.primaryGold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASSENGER INFO — with real avatar photo
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPassengerInfo() {
    final name       = _getPassengerName();
    final initial    = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final avatarUrl  = _getPassengerAvatarUrl();
    final rating     = _getPassengerRating();
    final hasRating  = rating > 0;

    return Row(
      children: [
        // ── Avatar: real photo with graceful fallback ──────────────
        _buildPassengerAvatar(avatarUrl, initial),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.star,
                    size: 16,
                    color: hasRating
                        ? AppColors.primaryYellow
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    hasRating ? rating.toStringAsFixed(1) : 'New user',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasRating
                          ? AppColors.textSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Verified badge ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.infoLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.verified, size: 14, color: AppColors.info),
              SizedBox(width: 4),
              Text(
                'Verified',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.info,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Passenger avatar widget — real photo > initial fallback
  Widget _buildPassengerAvatar(String? avatarUrl, String initial) {
    const double size = 48.0;

    // ── Gold initial circle (used as placeholder + error fallback) ──
    final fallbackWidget = Container(
      width:  size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.primaryGold,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlack,
          ),
        ),
      ),
    );

    if (avatarUrl == null) return fallbackWidget;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl:    avatarUrl,
        width:       size,
        height:      size,
        fit:         BoxFit.cover,
        placeholder: (_, __) => fallbackWidget,
        errorWidget: (_, __, ___) {
          debugPrint('⚠️ [TRIP-REQUEST] Avatar failed to load: $avatarUrl');
          return fallbackWidget;
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLocationRow({
    required IconData icon,
    required String   label,
    required String   address,
    required Color    color,
    required Color    backgroundColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                address,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String   label,
    required String   value,
    required Color    color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // ACTION BUTTONS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildActionButtons() {
    return Row(
      children: [
        // ── Decline ────────────────────────────────────────────────
        Expanded(
          flex: 1,
          child: ElevatedButton(
            onPressed: _isProcessing || _hasTimedOut ? null : _handleDecline,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.backgroundWhite,
              foregroundColor: AppColors.error,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.error, width: 2),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
              width:  20,
              height: 20,
              child:  CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation(AppColors.error),
              ),
            )
                : const Text('Decline',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(width: 16),

        // ── Accept ─────────────────────────────────────────────────
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color:  AppColors.primaryGold.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed:
              _isProcessing || _hasTimedOut ? null : _handleAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor:  Colors.transparent,
                foregroundColor:  AppColors.primaryBlack,
                shadowColor:      Colors.transparent,
                elevation:        0,
                padding:
                const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isProcessing
                  ? const SizedBox(
                width:  20,
                height: 20,
                child:  CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                      AppColors.primaryBlack),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, size: 20),
                  SizedBox(width: 8),
                  Text('Accept Trip',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}