// lib/screens/driver/offer/trip_request_screen.dart
//
// Redesigned: dark theme, Uber-style countdown ring,
// dramatic accept / decline buttons, smooth animations.

import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
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

  late AnimationController _timerCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shakeCtrl;
  late AnimationController _entryCtrl;
  late AnimationController _ringGlowCtrl;

  late Animation<double> _timerAnim;
  late Animation<double> _pulseAnim;
  late Animation<double> _shakeAnim;
  late Animation<double> _entryFadeAnim;
  late Animation<Offset>  _entrySlideAnim;
  late Animation<double> _ringGlowAnim;

  late int remainingSeconds;
  late int totalSeconds;

  Timer? _countdownTimer;
  bool _isProcessing = false;
  bool _hasTimedOut  = false;

  // ═══════════════════════════════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    totalSeconds     = _getExpiresInSeconds();
    remainingSeconds = totalSeconds;
    _setupAnimations();
    _startCountdown();
    HapticFeedback.heavyImpact();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DATA HELPERS
  // ═══════════════════════════════════════════════════════════════════

  int _getExpiresInSeconds() {
    final raw = widget.offer['expiresIn'] ?? widget.offer['expires_in'] ?? widget.offer['timeout'];
    if (raw is int)    return raw.clamp(5, 120);
    if (raw is double) return raw.toInt().clamp(5, 120);
    if (raw is String) return (int.tryParse(raw) ?? 25).clamp(5, 120);
    return 25;
  }

  String _getPassengerName() =>
      widget.offer['passenger']?['name']?.toString() ??
          widget.offer['passengerName']?.toString() ?? 'Passenger';

  String? _getPassengerAvatarUrl() {
    final p = widget.offer['passenger'];
    if (p == null) return null;
    final url = p['avatar_url']?.toString() ?? p['avatar']?.toString();
    return (url != null && url.isNotEmpty) ? url : null;
  }

  double _getPassengerRating() {
    final r = widget.offer['passenger']?['rating'] ?? widget.offer['passengerRating'];
    if (r == null) return 0;
    if (r is num) return r.toDouble();
    return double.tryParse(r.toString()) ?? 0;
  }

  String _getPickupAddress() =>
      widget.offer['pickup']?['address']?.toString() ??
          widget.offer['pickupAddress']?.toString() ?? 'Pickup location';

  String _getDropoffAddress() =>
      widget.offer['dropoff']?['address']?.toString() ??
          widget.offer['destination']?['address']?.toString() ??
          widget.offer['dropoffAddress']?.toString() ?? 'Destination';

  String _getDistance() {
    final raw = widget.offer['distanceM'] ?? widget.offer['distance'] ??
        widget.offer['distance_km'] ?? widget.offer['distanceKm'] ?? 0;
    if (raw is num) {
      final km = raw > 100 ? raw / 1000.0 : raw.toDouble();
      return '${km.toStringAsFixed(1)} km';
    }
    return '$raw km';
  }

  String _getFare() {
    final raw = widget.offer['fareEstimate'] ?? widget.offer['fare_estimate'] ??
        widget.offer['fare'] ?? 0;
    if (raw is num) return '${raw.toInt()} XAF';
    return '$raw XAF';
  }

  Color get _urgencyColor {
    if (remainingSeconds <= 5)  return AppColors.error;
    if (remainingSeconds <= 10) return const Color(0xFFFF8C00);
    return AppColors.primaryGold;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ANIMATIONS
  // ═══════════════════════════════════════════════════════════════════

  void _setupAnimations() {
    // Entry animation
    _entryCtrl = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _entryFadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlideAnim = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic));
    _entryCtrl.forward();

    // Timer countdown ring
    _timerCtrl = AnimationController(duration: Duration(seconds: totalSeconds), vsync: this);
    _timerAnim = Tween<double>(begin: 1.0, end: 0.0)
        .animate(CurvedAnimation(parent: _timerCtrl, curve: Curves.linear));
    _timerCtrl.forward();

    // Pulse for urgency
    _pulseCtrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);

    // Shake
    _shakeCtrl = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _shakeAnim = Tween<double>(begin: 0.0, end: 10.0)
        .animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));

    // Ring glow
    _ringGlowCtrl = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _ringGlowAnim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ringGlowCtrl, curve: Curves.easeInOut));
  }

  // ═══════════════════════════════════════════════════════════════════
  // COUNTDOWN
  // ═══════════════════════════════════════════════════════════════════

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      if (remainingSeconds > 0) {
        setState(() => remainingSeconds--);
        if (remainingSeconds == 10 || remainingSeconds == 5) {
          HapticFeedback.mediumImpact();
          _shakeCtrl.forward().then((_) => _shakeCtrl.reverse());
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
    HapticFeedback.heavyImpact();
    setState(() => _isProcessing = true);
    try {
      _countdownTimer?.cancel();
      final success = await widget.onAccept(widget.offer);
      if (!mounted) return;
      if (success) {
        Navigator.pop(context);
      } else {
        setState(() => _isProcessing = false);
        _showErrorDialog(title: tr('driver.tripTaken'), message: 'Another driver accepted this trip.');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _showErrorDialog(title: tr('common.errorTitle'), message: 'Could not accept trip. Please try again.', onRetry: _handleAccept);
    }
  }

  Future<void> _handleDecline() async {
    if (_isProcessing || _hasTimedOut) return;
    setState(() => _isProcessing = true);
    try {
      _countdownTimer?.cancel();
      await widget.onDecline(widget.offer);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _handleTimeout() async {
    if (_isProcessing || _hasTimedOut) return;
    _hasTimedOut = true;
    try { await widget.onDecline(widget.offer); } catch (_) {}
    if (!mounted) return;
    _showTimeoutDialog();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _entryCtrl.dispose();
    _timerCtrl.dispose();
    _pulseCtrl.dispose();
    _shakeCtrl.dispose();
    _ringGlowCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════

  void _showTimeoutDialog() {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => _DarkDialog(
        icon: Icons.access_time_rounded, iconColor: AppColors.warning,
        title: tr('driver.requestExpired'),
        message: 'You didn\'t respond in time. The trip was declined automatically.',
        actions: [_GoldButton(label: 'OK', onTap: () {
          Navigator.pop(context); Navigator.pop(context);
        })],
      ),
    );
  }

  void _showErrorDialog({required String title, required String message, VoidCallback? onRetry}) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (_) => _DarkDialog(
        icon: Icons.error_outline_rounded, iconColor: AppColors.error,
        title: title, message: message,
        actions: onRetry != null
            ? [
          _OutlinedDarkButton(label: tr('common.cancel'), onTap: () { Navigator.pop(context); Navigator.pop(context); }),
          const SizedBox(width: 12),
          _GoldButton(label: tr('common.retry'), onTap: () { Navigator.pop(context); onRetry(); }),
        ]
            : [_GoldButton(label: 'OK', onTap: () { Navigator.pop(context); Navigator.pop(context); })],
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
        backgroundColor: AppColors.darkBg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _entryFadeAnim,
            child: SlideTransition(
              position: _entrySlideAnim,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  children: [
                    _buildTimerSection(),
                    const SizedBox(height: 24),
                    Expanded(child: _buildTripCard()),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Timer / header ───────────────────────────────────────────────

  Widget _buildTimerSection() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, __) => Transform.translate(
        offset: Offset(_shakeAnim.value * math.sin(remainingSeconds.toDouble()), 0),
        child: Column(
          children: [
            // Ring timer
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, child) => Transform.scale(
                scale: remainingSeconds <= 10 ? _pulseAnim.value : 1.0,
                child: child,
              ),
              child: SizedBox(
                width: 90, height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow circle
                    AnimatedBuilder(
                      animation: _ringGlowAnim,
                      builder: (_, __) => Container(
                        width: 90, height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(
                            color: _urgencyColor.withOpacity(0.35 * _ringGlowAnim.value),
                            blurRadius: 24, spreadRadius: 4,
                          )],
                        ),
                      ),
                    ),
                    // Background ring
                    SizedBox(width: 90, height: 90,
                      child: CircularProgressIndicator(
                        value: 1.0, strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation(AppColors.darkSurfaceAlt),
                      ),
                    ),
                    // Progress ring
                    AnimatedBuilder(
                      animation: _timerAnim,
                      builder: (_, __) => SizedBox(width: 90, height: 90,
                        child: CircularProgressIndicator(
                          value: _timerAnim.value,
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation(_urgencyColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    ),
                    // Countdown number
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 32, fontWeight: FontWeight.w900,
                        color: _urgencyColor,
                      ),
                      child: Text('$remainingSeconds'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('driver.newTripRequest'),
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w900,
                    color: AppColors.darkTextPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 14, fontWeight: remainingSeconds <= 5 ? FontWeight.w700 : FontWeight.w400,
                color: remainingSeconds <= 5 ? AppColors.error : AppColors.darkTextSecondary,
              ),
              child: Text(remainingSeconds <= 5 ? 'Expiring soon!' : '$remainingSeconds seconds to respond'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Trip details card ────────────────────────────────────────────

  Widget _buildTripCard() {
    final name      = _getPassengerName();
    final initial   = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final avatarUrl = _getPassengerAvatarUrl();
    final rating    = _getPassengerRating();

    Widget avatar = Container(
      width: 52, height: 52,
      decoration: const BoxDecoration(color: AppColors.primaryGold, shape: BoxShape.circle),
      child: Center(child: Text(initial,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.black))),
    );
    if (avatarUrl != null) {
      avatar = ClipOval(child: CachedNetworkImage(
        imageUrl: avatarUrl, width: 52, height: 52, fit: BoxFit.cover,
        placeholder: (_, __) => avatar, errorWidget: (_, __, ___) => avatar,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.darkBorder),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Passenger header
          Row(children: [
            avatar,
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkTextPrimary)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.star_rounded, size: 15, color: rating > 0 ? AppColors.primaryGold : AppColors.darkTextTertiary),
                const SizedBox(width: 4),
                Text(
                  rating > 0 ? rating.toStringAsFixed(1) : 'New rider',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: rating > 0 ? AppColors.darkTextSecondary : AppColors.darkTextTertiary,
                  ),
                ),
              ]),
            ])),
            // Verified badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primaryGold.withOpacity(0.3)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_rounded, size: 14, color: AppColors.primaryGold),
                SizedBox(width: 4),
                Text(tr('driver.verified'), style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryGold)),
              ]),
            ),
          ]),

          const SizedBox(height: 20),
          Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: 20),

          // Pickup
          _LocationRow(
            icon: Icons.my_location_rounded,
            label: tr('ride.pickup'),
            address: _getPickupAddress(),
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          // Dropoff
          _LocationRow(
            icon: Icons.location_on_rounded,
            label: tr('driver.dropoff'),
            address: _getDropoffAddress(),
            color: AppColors.error,
          ),

          const SizedBox(height: 20),

          // Stats row
          Row(children: [
            Expanded(child: _StatChip(
              icon: Icons.straighten_rounded,
              label: tr('common.distance'),
              value: _getDistance(),
              color: const Color(0xFF4C8DFF),
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatChip(
              icon: Icons.payments_rounded,
              label: tr('driver.earnings'),
              value: _getFare(),
              color: AppColors.primaryGold,
            )),
          ]),
        ],
      ),
    );
  }

  // ─── Accept / Decline buttons ─────────────────────────────────────

  Widget _buildActionButtons() {
    return Row(children: [
      // Decline
      Expanded(
        flex: 1,
        child: SizedBox(
          height: 58,
          child: OutlinedButton(
            onPressed: _isProcessing || _hasTimedOut ? null : _handleDecline,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: AppColors.error.withOpacity(0.7), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _isProcessing
                ? const SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.error)))
                : Text(tr('driver.decline'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
        ),
      ),

      const SizedBox(width: 14),

      // Accept
      Expanded(
        flex: 2,
        child: SizedBox(
          height: 58,
          child: AnimatedBuilder(
            animation: _ringGlowAnim,
            builder: (_, child) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.35 * _ringGlowAnim.value),
                  blurRadius: 16, offset: const Offset(0, 4),
                )],
              ),
              child: child,
            ),
            child: ElevatedButton(
              onPressed: _isProcessing || _hasTimedOut ? null : _handleAccept,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGold,
                disabledBackgroundColor: AppColors.darkSurfaceHigh,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(Colors.black)))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_rounded, size: 22),
                      SizedBox(width: 8),
                      Text(tr('driver.acceptTrip'),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String address;
  final Color color;
  const _LocationRow({required this.icon, required this.label, required this.address, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextTertiary)),
        const SizedBox(height: 3),
        Text(address,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.darkTextPrimary),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ])),
    ]);
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.darkTextSecondary)),
      ]),
    );
  }
}

class _DarkDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;
  const _DarkDialog({
    required this.icon, required this.iconColor,
    required this.title, required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: iconColor.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkTextPrimary))),
      ]),
      content: Text(message, style: const TextStyle(fontSize: 14, color: AppColors.darkTextSecondary)),
      actions: [Row(children: actions.map((w) => w is _GoldButton ? Expanded(child: w) : (w is _OutlinedDarkButton ? Expanded(child: w) : w)).toList())],
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GoldButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGold, foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0,
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _OutlinedDarkButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlinedDarkButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
          foregroundColor: AppColors.darkTextPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }
}
