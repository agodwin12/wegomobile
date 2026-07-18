// lib/presentation/screens/trip/trip_completed_screen.dart
//
// Redesigned to match reference UI:
//   • Dark header with gold check + confetti
//   • Driver card with avatar, name, ride count, stars
//   • Tip selection row (0 / 500 / 1 000 / 2 000 XAF)
//   • Payment method display
//   • Gold Submit + outlined Skip buttons

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../providers/trip_provider.dart';
import '../../../utils/app_colors.dart';

// ─── Tip presets ──────────────────────────────────────────────────────────────
const _kTipAmounts = [0, 500, 1000, 2000]; // XAF

class TripCompletedScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> driver;
  final Map<String, dynamic> tripDetails;

  const TripCompletedScreen({
    super.key,
    required this.tripId,
    required this.driver,
    required this.tripDetails,
  });

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen>
    with TickerProviderStateMixin {

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _entryCtrl;
  late AnimationController _checkCtrl;
  late AnimationController _celebrationCtrl;
  late AnimationController _starCtrl;
  late AnimationController _tipCtrl;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _checkAnim;
  late Animation<double> _celebrationAnim;

  // ── State ─────────────────────────────────────────────────────────────────
  int  _selectedRating  = 0;
  int  _selectedTipIdx  = 1;        // default: 500 XAF
  bool _isSubmitting    = false;
  String? _errorMessage;

  late final TextEditingController _commentCtrl;
  late List<_Particle> _particles;

  // ═══════════════════════════════════════════════════════════════════════════
  // INIT / DISPOSE
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _commentCtrl = TextEditingController();
    _generateParticles();
    _setupAnimations();
  }

  void _generateParticles() {
    final rng = math.Random();
    _particles = List.generate(24, (_) => _Particle(rng));
  }

  void _setupAnimations() {
    _entryCtrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim  = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));

    _checkCtrl = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _checkAnim = CurvedAnimation(parent: _checkCtrl, curve: Curves.easeOutCirc);

    _celebrationCtrl = AnimationController(
        duration: const Duration(milliseconds: 1600), vsync: this);
    _celebrationAnim =
        CurvedAnimation(parent: _celebrationCtrl, curve: Curves.easeOut);

    _starCtrl = AnimationController(
        duration: const Duration(milliseconds: 400), vsync: this);

    _tipCtrl = AnimationController(
        duration: const Duration(milliseconds: 200), vsync: this)
      ..forward();

    _entryCtrl.forward().then((_) {
      _checkCtrl.forward().then((_) => _celebrationCtrl.forward());
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _checkCtrl.dispose();
    _celebrationCtrl.dispose();
    _starCtrl.dispose();
    _tipCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String? _field(Map<String, dynamic>? m, List<String> keys) {
    if (m == null) return null;
    for (final k in keys) {
      final v = m[k];
      if (v != null && v.toString().isNotEmpty) return v.toString();
    }
    return null;
  }

  String get _driverName {
    final first = _field(widget.driver, ['firstName', 'first_name']) ?? '';
    final last  = _field(widget.driver, ['lastName',  'last_name'])  ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : (_field(widget.driver, ['name']) ?? 'Driver');
  }

  String? get _driverAvatarUrl => _field(widget.driver, [
    'avatar', 'avatar_url', 'photo', 'picture', 'profilePhoto', 'profile_photo',
  ]);

  String get _driverRating =>
      _field(widget.driver, ['rating', 'rating_avg', 'ratingAvg']) ?? '4.8';

  int get _driverRideCount {
    final raw = widget.driver['total_trips'] ??
        widget.driver['totalTrips'] ?? widget.driver['rides'];
    if (raw is int) return raw;
    if (raw is double) return raw.toInt();
    if (raw is String) return int.tryParse(raw) ?? 0;
    return 0;
  }

  Map<String, String> get _vehicleInfo {
    final v = widget.driver['vehicle'] as Map<String, dynamic>?;
    return {
      'plate':     _field(v ?? widget.driver, ['plate', 'vehiclePlate', 'vehicle_plate']) ?? 'N/A',
      'makeModel': _field(v ?? widget.driver, ['makeModel', 'vehicle_make_model']) ?? 'Vehicle',
      'color':     _field(v ?? widget.driver, ['color', 'vehicleColor']) ?? '',
      'type':      _field(v ?? widget.driver, ['type', 'vehicleType']) ?? 'Standard',
    };
  }

  String get _rateLabel => _vehicleInfo['type'] ?? 'Standard Rate';

  String get _pickupAddress  =>
      _field(widget.tripDetails, ['pickup_address', 'pickupAddress', 'pickup'])   ?? tr('ride.pickup');
  String get _dropoffAddress =>
      _field(widget.tripDetails, ['dropoff_address', 'dropoffAddress', 'dropoff']) ?? tr('ride.destination');

  int get _baseFare {
    final f = widget.tripDetails['fare_estimate'] ?? widget.tripDetails['fareEstimate'] ??
        widget.tripDetails['final_fare'] ?? widget.tripDetails['finalFare'] ?? 3500;
    if (f is int) return f;
    if (f is double) return f.toInt();
    if (f is String) return int.tryParse(f) ?? 3500;
    return 3500;
  }

  String get _distanceKm {
    final d = widget.tripDetails['distance_m'] ?? widget.tripDetails['distanceM'] ?? 5000;
    int dist = 5000;
    if (d is int) { dist = d; }
    else if (d is double) { dist = d.toInt(); }
    else if (d is String) { dist = int.tryParse(d) ?? 5000; }
    return (dist / 1000).toStringAsFixed(1);
  }

  String get _paymentMethod {
    final m = widget.tripDetails['payment_method'] ??
        widget.tripDetails['paymentMethod'] ?? 'cash';
    return m.toString().toLowerCase();
  }

  String get _paymentLabel {
    switch (_paymentMethod) {
      case 'om':   return 'Orange Money';
      case 'momo': return 'MTN MoMo';
      default:     return 'Cash';
    }
  }

  IconData get _paymentIcon {
    switch (_paymentMethod) {
      case 'om':
      case 'momo': return Icons.phone_android_rounded;
      default:     return Icons.payments_rounded;
    }
  }

  int get _tipAmount => _kTipAmounts[_selectedTipIdx];
  int get _totalAmount => _baseFare + _tipAmount;

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      _snack('Please select a rating first');
      return;
    }
    setState(() { _isSubmitting = true; _errorMessage = null; });
    try {
      final tp      = Provider.of<TripProvider>(context, listen: false);
      final success = await tp.submitRating(
        tripId:  widget.tripId,
        stars:   _selectedRating,
        comment: _commentCtrl.text.isNotEmpty ? _commentCtrl.text : null,
      );
      if (!mounted) return;
      if (success) {
        HapticFeedback.mediumImpact();
        _showSuccessDialog();
      } else {
        _snack(tp.errorMessage ?? 'Failed to submit rating', isError: true);
      }
    } catch (_) {
      if (mounted) _snack('An unexpected error occurred', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _skip() {
    Provider.of<TripProvider>(context, listen: false).clearTrip();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                  color: AppColors.primaryGold.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGold.withOpacity(0.4), width: 2)),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.primaryGold, size: 48),
            ),
            const SizedBox(height: 20),
            Text(tr('trip.thankYou'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 8),
            Text(tr('trip.feedbackSaved'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.5))),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Provider.of<TripProvider>(context, listen: false).clearTrip();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(tr('common.done'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? AppColors.error : const Color(0xFF26262B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeroHeader()),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    20, 0, 20, MediaQuery.of(context).padding.bottom + 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _buildDriverCard(),
                    const SizedBox(height: 16),
                    _buildRouteCard(),
                    const SizedBox(height: 24),
                    _buildRatingCard(),
                    const SizedBox(height: 16),
                    _buildTipCard(),
                    const SizedBox(height: 16),
                    _buildPaymentCard(),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                    const SizedBox(height: 12),
                    _buildSkipButton(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Hero header (dark, check animation + confetti) ───────────────────────

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E10),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
          child: Column(
            children: [
              // Back arrow
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: _skip,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Animated check + confetti
              SizedBox(
                width: 140, height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ..._particles.map((p) => AnimatedBuilder(
                      animation: _celebrationAnim,
                      builder: (_, __) {
                        final t = _celebrationAnim.value;
                        final x = p.dx * t * 65;
                        final y = p.dy * t * 65 + 30 * t * t;
                        final opacity = (1.0 - t * 1.2).clamp(0.0, 1.0);
                        return Positioned(
                          left: 70 + x, top: 70 + y,
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: p.size, height: p.size,
                              decoration: BoxDecoration(
                                color: p.color,
                                shape: p.isCircle ? BoxShape.circle : BoxShape.rectangle,
                                borderRadius: p.isCircle ? null : BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        );
                      },
                    )),
                    AnimatedBuilder(
                      animation: _checkAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _checkAnim.value,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primaryGold.withOpacity(0.3),
                                width: 2),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _checkAnim,
                      builder: (_, __) => Transform.scale(
                        scale: _checkAnim.value,
                        child: Container(
                          width: 96, height: 96,
                          decoration: const BoxDecoration(
                              color: AppColors.primaryGold, shape: BoxShape.circle),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.black, size: 56),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(tr('trip.complete'),
                  style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text(tr('trip.thanksRiding'),
                  style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.45))),
              const SizedBox(height: 28),
              // Stats row
              Row(
                children: [
                  Expanded(child: _StatPill(
                    icon: Icons.payments_rounded,
                    label: tr('trip.totalPaid'),
                    value: '$_baseFare XAF',
                    valueColor: AppColors.primaryGold,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _StatPill(
                    icon: Icons.route_rounded,
                    label: tr('common.distance'),
                    value: '$_distanceKm km',
                    valueColor: Colors.white,
                  )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Driver card ──────────────────────────────────────────────────────────

  Widget _buildDriverCard() {
    final name    = _driverName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'D';
    final rides   = _driverRideCount;
    final url     = _driverAvatarUrl;
    final rating  = _driverRating;
    final plate   = _vehicleInfo['plate'] ?? 'N/A';
    final vehicle = _vehicleInfo['makeModel'] ?? 'Vehicle';

    Widget avatar = Container(
      width: 66, height: 66,
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.3), width: 2),
      ),
      child: Center(child: Text(initial,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.black))),
    );
    if (url != null && url.isNotEmpty) {
      avatar = ClipOval(child: CachedNetworkImage(
        imageUrl: url, width: 66, height: 66, fit: BoxFit.cover,
        placeholder: (_, __) => avatar,
        errorWidget: (_, __, ___) => avatar,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.06), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Avatar + name + rides
          Row(
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  if (rides > 0)
                    Text('$rides rides',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF9A9AA2))),
                ]),
              ),
              // Plate badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(plate,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        letterSpacing: 2, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: Colors.grey.shade100),
          const SizedBox(height: 14),
          // Stars + vehicle
          Row(
            children: [
              ...List.generate(5, (i) => Icon(
                Icons.star_rounded,
                size: 22,
                color: i < 5 ? AppColors.primaryGold : Colors.grey.shade200,
              )),
              const SizedBox(width: 10),
              Text(rating, style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const Spacer(),
              Icon(Icons.directions_car_rounded, size: 16, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Flexible(child: Text(vehicle, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500))),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Route card ───────────────────────────────────────────────────────────

  Widget _buildRouteCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Column(children: [
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
            Container(width: 2, height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFF22C55E), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                )),
            Container(width: 10, height: 10,
                decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
          ]),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _AddrRow(label: tr('ride.pickup'),  address: _pickupAddress),
            Padding(padding: const EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: Colors.grey.shade100)),
            _AddrRow(label: tr('ride.destination'), address: _dropoffAddress),
          ])),
        ],
      ),
    );
  }

  // ─── Rating card ──────────────────────────────────────────────────────────

  Widget _buildRatingCard() {
    final labels = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent!'];
    final colors = [
      Colors.grey, Colors.red, Colors.orange,
      Colors.blue, Colors.green, AppColors.primaryGold,
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(tr('trip.howWasRide'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 4),
          Text(_rateLabel,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
          const SizedBox(height: 24),
          // Stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final filled = i < _selectedRating;
              return GestureDetector(
                onTap: _isSubmitting ? null : () {
                  HapticFeedback.selectionClick();
                  setState(() { _selectedRating = i + 1; _errorMessage = null; });
                  _starCtrl..reset()..forward();
                },
                child: AnimatedScale(
                  scale: (filled && i == _selectedRating - 1) ? 1.25 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 48,
                      color: filled ? AppColors.primaryGold : Colors.grey.shade200,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _selectedRating == 0 ? 'Tap to rate' : labels[_selectedRating],
              key: ValueKey(_selectedRating),
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600,
                color: _selectedRating == 0 ? Colors.grey.shade400 : colors[_selectedRating],
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade100)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red.shade600, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_errorMessage!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 13))),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          // Comment box
          TextField(
            controller: _commentCtrl,
            enabled: !_isSubmitting,
            maxLines: 3, maxLength: 500,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: tr('trip.leaveComment'),
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              filled: true, fillColor: Colors.grey.shade50, counterText: '',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.primaryGold, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Tip card ─────────────────────────────────────────────────────────────

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('trip.leaveTip'),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 14),
          // Tip buttons
          Row(
            children: List.generate(_kTipAmounts.length, (i) {
              final selected = _selectedTipIdx == i;
              final amount   = _kTipAmounts[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _kTipAmounts.length - 1 ? 8 : 0),
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTipIdx = i);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: selected ? const Color(0xFF1A1A1A) : Colors.grey.shade200),
                      ),
                      child: Center(
                        child: Text(
                          amount == 0 ? '0 XAF' : '${amount ~/ 100 == 0 ? amount : "${(amount / 1000).toStringAsFixed(0)}k"} XAF',
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : const Color(0xFF1A1A1A),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tip amount: ${_tipAmount == 0 ? "0 XAF" : "$_tipAmount XAF"}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
              ),
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedTipIdx = 0);
                },
                child: Text(tr('common.remove'),
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: AppColors.primaryGold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tr('trip.tipNote'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  // ─── Payment card ─────────────────────────────────────────────────────────

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_paymentIcon, color: const Color(0xFF1A1A1A), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('payment.title'),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              const SizedBox(height: 2),
              Text(_paymentLabel,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
            ]),
          ),
          Text('$_totalAmount XAF',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  // ─── Buttons ──────────────────────────────────────────────────────────────

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity, height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitRating,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold,
          disabledBackgroundColor: Colors.grey.shade200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))
            : Text(tr('common.submit'),
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black)),
      ),
    );
  }

  Widget _buildSkipButton() {
    return SizedBox(
      width: double.infinity, height: 52,
      child: OutlinedButton(
        onPressed: _isSubmitting ? null : _skip,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(tr('trip.skipForNow'),
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;
  const _StatPill({required this.icon, required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(children: [
        Icon(icon, color: Colors.white.withOpacity(0.4), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: valueColor)),
        ])),
      ]),
    );
  }
}

class _AddrRow extends StatelessWidget {
  final String label;
  final String address;
  const _AddrRow({required this.label, required this.address});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      const SizedBox(height: 2),
      Text(
        address.length > 42 ? '${address.substring(0, 42)}…' : address,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
    ]);
  }
}

class _Particle {
  final double dx, dy, size;
  final Color color;
  final bool isCircle;
  _Particle(math.Random rng)
      : dx       = (rng.nextDouble() - 0.5) * 2.0,
        dy       = -(rng.nextDouble() * 1.5 + 0.5),
        size     = rng.nextDouble() * 7 + 4,
        isCircle = rng.nextBool(),
        color    = const [
          AppColors.primaryGold,
          Colors.white,
          Color(0xFFFFEA80),
          Color(0xFFFFF3B0),
          Colors.white70,
        ][rng.nextInt(5)];
}
