// lib/screens/driver/trip complete/trip_complete.dart

import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_v1/main.dart';
import 'package:wego_v1/utils/app_colors.dart';
import 'package:wego_v1/utils/app_typography.dart';

// ═══════════════════════════════════════════════════════════════
// DRIVER TRIP COMPLETE SCREEN
// ═══════════════════════════════════════════════════════════════

class DriverTripCompleteScreen extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic> trip;
  final Map<String, dynamic> passenger;
  final int tripDuration; // seconds

  const DriverTripCompleteScreen({
    Key? key,
    required this.tripId,
    required this.trip,
    required this.passenger,
    required this.tripDuration,
  }) : super(key: key);

  @override
  State<DriverTripCompleteScreen> createState() =>
      _DriverTripCompleteScreenState();
}

class _DriverTripCompleteScreenState extends State<DriverTripCompleteScreen>
    with TickerProviderStateMixin {

  // ── Animations ───────────────────────────────────────────────
  late AnimationController _heroController;
  late AnimationController _cardsController;
  late AnimationController _buttonController;

  late Animation<double>  _heroScale;
  late Animation<double>  _heroFade;
  late Animation<Offset>  _card1Slide;
  late Animation<Offset>  _card2Slide;
  late Animation<Offset>  _card3Slide;
  late Animation<double>  _buttonFade;

  // ── State ────────────────────────────────────────────────────
  bool _isSubmitting     = false;
  bool _paymentConfirmed = false;

  // ── Trip data helpers ─────────────────────────────────────────
  String get _paymentMethod =>
      (widget.trip['payment_method'] ??
          widget.trip['paymentMethod'] ??
          'CASH')
          .toString()
          .toUpperCase();

  double get _fare =>
      (widget.trip['fare_estimate'] ??
          widget.trip['fareEstimate'] ??
          widget.trip['fare_final'] ??
          widget.trip['fareFinal'] ??
          0)
          .toDouble();

  double get _distanceKm =>
      ((widget.trip['distance_m'] ?? widget.trip['distanceM'] ?? 0) / 1000)
          .toDouble();

  // ════════════════════════════════════════════════════════════
  // ✅ PASSENGER HELPERS — name, initial, avatar
  // ════════════════════════════════════════════════════════════

  /// Full display name, resolved from multiple possible keys.
  String get _passengerName {
    final direct = widget.passenger['name']?.toString() ?? '';
    if (direct.isNotEmpty) return direct;
    final first = widget.passenger['firstName']?.toString()
        ?? widget.passenger['first_name']?.toString()  ?? '';
    final last  = widget.passenger['lastName']?.toString()
        ?? widget.passenger['last_name']?.toString()   ?? '';
    final full  = '$first $last'.trim();
    return full.isNotEmpty ? full : 'Passenger';
  }

  /// First character of the passenger's name, uppercased.
  /// Tries first_name specifically before falling back to the full name.
  /// Falls back to 'P' if everything is empty.
  String get _passengerInitial {
    // Prefer the dedicated first-name fields so we get the first letter
    // of the first name rather than the last name.
    final firstName = widget.passenger['firstName']?.toString().trim()
        ?? widget.passenger['first_name']?.toString().trim()
        ?? '';
    if (firstName.isNotEmpty) return firstName[0].toUpperCase();

    final name = _passengerName.trimLeft();
    if (name.isNotEmpty) return name[0].toUpperCase();

    return 'P';
  }

  /// Avatar URL, resolved from multiple possible keys.
  /// Returns null when no valid URL is found.
  String? get _passengerAvatarUrl {
    final candidates = [
      widget.passenger['avatar_url'],
      widget.passenger['avatarUrl'],
      widget.passenger['profile_photo'],
      widget.passenger['photo'],
      widget.passenger['avatar'],
    ];
    for (final c in candidates) {
      final url = c?.toString().trim() ?? '';
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
      }
    }
    return null;
  }

  // ════════════════════════════════════════════════════════════
  // INIT
  // ════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _playAnimations();
  }

  void _setupAnimations() {
    _heroController = AnimationController(
        duration: const Duration(milliseconds: 900), vsync: this);
    _cardsController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _buttonController = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);

    _heroScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _heroController, curve: Curves.elasticOut));
    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _heroController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));

    _card1Slide = Tween<Offset>(
        begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _cardsController,
        curve:
        const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));
    _card2Slide = Tween<Offset>(
        begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _cardsController,
        curve:
        const Interval(0.2, 0.8, curve: Curves.easeOutCubic)));
    _card3Slide = Tween<Offset>(
        begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _cardsController,
        curve:
        const Interval(0.4, 1.0, curve: Curves.easeOutCubic)));

    _buttonFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _buttonController, curve: Curves.easeOut));
  }

  Future<void> _playAnimations() async {
    await _heroController.forward();
    await Future.delayed(const Duration(milliseconds: 150));
    _cardsController.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _buttonController.forward();
  }

  // ════════════════════════════════════════════════════════════
  // ACTIONS
  // ════════════════════════════════════════════════════════════

  Future<void> _confirmPayment() async {
    setState(() => _paymentConfirmed = true);
    _showSnackBar('Cash payment confirmed!', isError: false);
  }

  Future<void> _finishTrip() async {
    if (_paymentMethod == 'CASH' && !_paymentConfirmed) {
      _showSnackBar(
          'Please confirm you received the cash payment',
          isError: true);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await Future.delayed(const Duration(milliseconds: 600));
      _showSnackBar('Great job! Ready for your next trip.', isError: false);
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) {
        _showSnackBar('Something went wrong. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _skipAndFinish() =>
      Navigator.of(context).popUntil((r) => r.isFirst);

  // ════════════════════════════════════════════════════════════
  // HELPERS
  // ════════════════════════════════════════════════════════════

  Future<String> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token') ?? '';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    return '${h}h ${m % 60}m';
  }

  String _formatPayment(String method) {
    switch (method) {
      case 'ORANGE_MONEY':
        return 'Orange Money';
      case 'MTN_MOBILE_MONEY':
        return 'MTN MoMo';
      default:
        return 'Cash';
    }
  }

  void _showSnackBar(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: AppTypography.bodySmall.copyWith(
              color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ════════════════════════════════════════════════════════════
  // DISPOSE
  // ════════════════════════════════════════════════════════════

  @override
  void dispose() {
    _heroController.dispose();
    _cardsController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Text(tr('driver.leaveQ'),
                style: TextStyle(fontWeight: FontWeight.w700)),
            content:
            Text(tr('driver.returnDashboardQ')),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('driver.stay'))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr('driver.leave'),
                      style: TextStyle(color: AppColors.error))),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0A),
        body: Column(
          children: [
            // ── DARK HERO ──────────────────────────────────────
            _buildHeroSection(),

            // ── LIGHT SCROLLABLE BODY ──────────────────────────
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.backgroundLight,
                  borderRadius:
                  BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        MediaQuery.of(context).padding.bottom + 32),
                    child: Column(
                      children: [
                        // Earnings card
                        SlideTransition(
                          position: _card1Slide,
                          child: FadeTransition(
                              opacity: _cardsController,
                              child: _buildEarningsCard()),
                        ),

                        const SizedBox(height: 14),

                        // Stats row
                        SlideTransition(
                          position: _card2Slide,
                          child: FadeTransition(
                              opacity: _cardsController,
                              child: _buildStatsRow()),
                        ),

                        const SizedBox(height: 14),

                        // Cash payment confirmation card
                        if (_paymentMethod == 'CASH') ...[
                          SlideTransition(
                            position: _card2Slide,
                            child: FadeTransition(
                                opacity: _cardsController,
                                child: _buildPaymentCard()),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Passenger card
                        SlideTransition(
                          position: _card3Slide,
                          child: FadeTransition(
                              opacity: _cardsController,
                              child: _buildPassengerCard()),
                        ),

                        const SizedBox(height: 28),

                        // Finish button
                        FadeTransition(
                            opacity: _buttonFade,
                            child: _buildFinishButton()),

                        const SizedBox(height: 12),

                        // Return to dashboard link
                        FadeTransition(
                          opacity: _buttonFade,
                          child: TextButton(
                            onPressed:
                            _isSubmitting ? null : _skipAndFinish,
                            child: Text(tr('driver.returnDashboard'),
                                style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // DARK HERO
  // ════════════════════════════════════════════════════════════

  Widget _buildHeroSection() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
        child: Column(
          children: [
            // Animated gold checkmark badge
            AnimatedBuilder(
              animation: _heroScale,
              builder: (_, __) => Transform.scale(
                scale: _heroScale.value,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color:
                          AppColors.primaryGold.withOpacity(0.55),
                          blurRadius: 32,
                          spreadRadius: 6,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 52, color: Colors.black),
                ),
              ),
            ),

            const SizedBox(height: 22),

            FadeTransition(
              opacity: _heroFade,
              child: Column(
                children: [
                  Text(
                    'Trip Completed!',
                    style: AppTypography.headlineLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Excellent work. Your earnings are ready.',
                    style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white38),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // EARNINGS CARD
  // ════════════════════════════════════════════════════════════

  Widget _buildEarningsCard() {
    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.primaryGold,
                size: 28),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('driver.yourEarnings'),
                    style: AppTypography.bodySmall.copyWith(
                        color: Colors.white38,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '${_fare.toInt()} XAF',
                  style: AppTypography.headlineLarge.copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          // Payment method badge
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: Text(
              _formatPayment(_paymentMethod),
              style: AppTypography.labelSmall.copyWith(
                  color: Colors.white54,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // STATS ROW
  // ════════════════════════════════════════════════════════════

  Widget _buildStatsRow() {
    final shortId = widget.tripId.length >= 6
        ? widget.tripId.substring(0, 6).toUpperCase()
        : widget.tripId.toUpperCase();

    return Row(children: [
      Expanded(child: _StatCard(
        icon:   Icons.straighten_rounded,
        label:  tr('common.distance'),
        value:  '${_distanceKm.toStringAsFixed(1)} km',
        accent: AppColors.info,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        icon:   Icons.access_time_rounded,
        label:  tr('common.duration'),
        value:  _formatDuration(widget.tripDuration),
        accent: AppColors.success,
      )),
      const SizedBox(width: 12),
      Expanded(child: _StatCard(
        icon:   Icons.tag_rounded,
        label:  tr('driver.tripId'),
        value:  '#$shortId',
        accent: AppColors.warning,
      )),
    ]);
  }

  // ════════════════════════════════════════════════════════════
  // CASH PAYMENT CARD
  // ════════════════════════════════════════════════════════════

  Widget _buildPaymentCard() {
    if (_paymentConfirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppColors.success.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('driver.paymentConfirmed'),
                    style: AppTypography.titleMedium.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700)),
                Text(
                    'You received ${_fare.toInt()} XAF in cash',
                    style: AppTypography.bodySmall.copyWith(
                        color:
                        AppColors.success.withOpacity(0.8))),
              ],
            ),
          ),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.warning.withOpacity(0.5), width: 1.5),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.15),
                shape: BoxShape.circle),
            child: const Icon(Icons.payments_rounded,
                color: AppColors.warning, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('driver.confirmCashPayment'),
                    style: AppTypography.titleMedium
                        .copyWith(fontWeight: FontWeight.w700)),
                Text('Did you receive ${_fare.toInt()} XAF?',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            onPressed: _confirmPayment,
            icon: const Icon(Icons.check_rounded,
                color: Colors.white, size: 18),
            label: Text(tr('driver.yesPaymentReceived'),
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // ✅ PASSENGER CARD — photo with first-letter fallback
  // ════════════════════════════════════════════════════════════

  Widget _buildPassengerCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 14,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        // ── Avatar: photo → first-letter fallback ────────────
        _PassengerAvatar(
          initial:   _passengerInitial,
          avatarUrl: _passengerAvatarUrl,
          size:      62,
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _passengerName,
                style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.check_circle_rounded,
                    size: 14, color: AppColors.success),
                const SizedBox(width: 5),
                Text('Trip completed successfully',
                    style: AppTypography.bodySmall.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
          ),
        ),

        // Trophy badge
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.emoji_events_rounded,
              color: Colors.black, size: 22),
        ),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════
  // FINISH BUTTON
  // ════════════════════════════════════════════════════════════

  Widget _buildFinishButton() {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primaryGold.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _finishTrip,
        icon: _isSubmitting
            ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                AlwaysStoppedAnimation(Colors.black)))
            : const Icon(Icons.wifi_tethering_rounded,
            color: Colors.black, size: 22),
        label: Text(
          _isSubmitting ? 'Please wait…' : 'Go Online for Next Trip',
          style: AppTypography.buttonLarge.copyWith(
              fontWeight: FontWeight.w800, color: Colors.black),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor:     Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ✅ PASSENGER AVATAR WIDGET
//    Shows the network photo when a valid URL is available.
//    Falls back to a gold circle with the first letter otherwise.
// ════════════════════════════════════════════════════════════════

class _PassengerAvatar extends StatelessWidget {
  final String  initial;
  final String? avatarUrl;
  final double  size;

  const _PassengerAvatar({
    required this.initial,
    required this.avatarUrl,
    this.size = 50,
  });

  /// True only when the URL is a proper http/https address.
  bool get _hasValidPhoto {
    if (avatarUrl == null) return false;
    final url = avatarUrl!.trim();
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.primaryGold.withOpacity(0.45), width: 2.5),
        boxShadow: [
          BoxShadow(
              color:      AppColors.primaryGold.withOpacity(0.15),
              blurRadius: 10,
              spreadRadius: 2),
        ],
      ),
      child: ClipOval(
        child: _hasValidPhoto
            ? CachedNetworkImage(
          imageUrl:    avatarUrl!,
          width:       size,
          height:      size,
          fit:         BoxFit.cover,
          // Show the initial while the image is loading
          placeholder: (_, __) =>
              _AvatarFallback(initial: initial, size: size),
          // Show the initial if the image fails to load
          errorWidget: (_, __, ___) =>
              _AvatarFallback(initial: initial, size: size),
        )
        // No valid URL — show the initial immediately, no flicker
            : _AvatarFallback(initial: initial, size: size),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AVATAR FALLBACK — gold circle with the passenger's first letter
// ════════════════════════════════════════════════════════════════

class _AvatarFallback extends StatelessWidget {
  final String initial;
  final double size;

  const _AvatarFallback({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:     size,
      height:    size,
      color:     AppColors.primaryGold,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize:   size * 0.42,
          fontWeight: FontWeight.w800,
          color:      Colors.black,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// STAT CARD
// ════════════════════════════════════════════════════════════════

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    accent;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color:      AppColors.textPrimary,
                fontSize:   13),
            textAlign: TextAlign.center,
            maxLines:  1,
            overflow:  TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppTypography.labelSmall
                .copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}