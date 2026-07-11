import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../../service/rental_api_service.dart';
import '../../../../../utils/app_colors.dart';
import '../../../../../widgets/payment/payment_status_view.dart';
import '../my rentals/my_rentals_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RENTAL PAYMENT WAITING SCREEN
// Dark-mode luxury aesthetic. Orbital ring animation while pending.
// Explosive particle burst on success. Shake + collapse on failure.
// ─────────────────────────────────────────────────────────────────────────────

class RentalPaymentWaitingScreen extends StatefulWidget {
  final String campayRef;
  final String paymentId;
  final double totalPrice;
  final String vehicleName;
  final String accessToken;
  final String operator; // 'MTN' or 'ORANGE'
  final Map<String, dynamic> user;

  const RentalPaymentWaitingScreen({
    super.key,
    required this.campayRef,
    required this.paymentId,
    required this.totalPrice,
    required this.vehicleName,
    required this.accessToken,
    required this.operator,
    required this.user,
  });

  @override
  State<RentalPaymentWaitingScreen> createState() =>
      _RentalPaymentWaitingScreenState();
}

class _RentalPaymentWaitingScreenState
    extends State<RentalPaymentWaitingScreen>
    with TickerProviderStateMixin {

  // ── State ──────────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  _PaymentState _paymentState = _PaymentState.pending;

  // ── Animation controllers ──────────────────────────────────────────────────

  // Orbital rings (pending)
  late AnimationController _orbitController;

  // Breathing glow (pending)
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  // Dots (pending)
  late AnimationController _dotsController;

  // Content entrance
  late AnimationController _entranceController;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;

  // Result state
  late AnimationController _resultController;
  late Animation<double> _resultScale;
  late Animation<double> _resultFade;

  // Particle burst (success)
  late AnimationController _particleController;
  final List<_Particle> _particles = [];

  // Shake (failure)
  late AnimationController _shakeController;
  late Animation<double> _shakeAnim;

  // Check-mark draw (success)
  late AnimationController _checkController;
  late Animation<double> _checkAnim;

  // X draw (failure)
  late AnimationController _xController;
  late Animation<double> _xAnim;

  // ── Operator colors ────────────────────────────────────────────────────────
  bool get _isMtn =>
      widget.operator.toUpperCase().contains('MTN');

  Color get _operatorPrimary =>
      _isMtn ? const Color(0xFFFFCC00) : const Color(0xFFFF6B00);

  Color get _operatorSecondary =>
      _isMtn ? const Color(0xFFFFE566) : const Color(0xFFFFAA44);

  String get _operatorLabel => _isMtn ? 'MTN MoMo' : 'Orange Money';

  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _buildParticles();
    _initAnimations();
    _startEntrance();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  void _buildParticles() {
    final rng = math.Random(42);
    for (int i = 0; i < 28; i++) {
      _particles.add(_Particle(
        angle: rng.nextDouble() * math.pi * 2,
        speed: 120 + rng.nextDouble() * 180,
        size: 4 + rng.nextDouble() * 7,
        color: i % 3 == 0
            ? _operatorPrimary
            : i % 3 == 1
            ? Colors.white
            : _operatorSecondary,
      ));
    }
  }

  void _initAnimations() {
    // Orbit — continuous 360°
    _orbitController = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat();

    // Glow pulse
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );

    // Dots
    _dotsController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat();

    // Entrance
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _entranceFade = CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _entranceController, curve: Curves.easeOutCubic));

    // Result reveal
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _resultScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    _resultFade = CurvedAnimation(
        parent: _resultController, curve: Curves.easeOut);

    // Particles
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    // Shake
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    // Check draw
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _checkAnim = CurvedAnimation(
        parent: _checkController, curve: Curves.easeOutCubic);

    // X draw
    _xController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _xAnim =
        CurvedAnimation(parent: _xController, curve: Curves.easeOutCubic);
  }

  void _startEntrance() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entranceController.forward();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _orbitController.dispose();
    _glowController.dispose();
    _dotsController.dispose();
    _entranceController.dispose();
    _resultController.dispose();
    _particleController.dispose();
    _shakeController.dispose();
    _checkController.dispose();
    _xController.dispose();
    super.dispose();
  }

  // ── Polling ────────────────────────────────────────────────────────────────

  Future<void> _poll() async {
    if (_paymentState != _PaymentState.pending) return;

    final response = await RentalApiService.checkPaymentStatus(
      accessToken: widget.accessToken,
      campayRef: widget.campayRef,
    );

    if (!mounted) return;

    // ── ADD THESE TWO LINES ───────────────────────────────────────────
    debugPrint('🔍 FULL POLL RESPONSE: $response');
    debugPrint('🔍 DATA KEY: ${response['data']}');
    // ─────────────────────────────────────────────────────────────────

    if (response['success'] == true) {
      final status = (response['data']?['status'] as String? ?? 'PENDING').toUpperCase();
      debugPrint('🔍 PARSED STATUS: $status');

      if (status == 'SUCCESSFUL') {
        _resolveSuccess();
      } else if (status == 'FAILED') {
        _resolveFailure();
      }
    }
  }

  void _resolveSuccess() {
    _pollTimer?.cancel();
    _orbitController.stop();
    _glowController.stop();
    _dotsController.stop();

    setState(() => _paymentState = _PaymentState.success);

    // Sequence: result reveal → particle burst → check draw
    _resultController.forward().then((_) {
      _particleController.forward();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) _checkController.forward();
      });
    });
  }

  void _resolveFailure() {
    _pollTimer?.cancel();
    _orbitController.stop();
    _glowController.stop();
    _dotsController.stop();

    setState(() => _paymentState = _PaymentState.failed);

    // Sequence: result reveal → shake → X draw
    _resultController.forward().then((_) {
      _shakeController.forward().then((_) {
        if (mounted) _xController.forward();
      });
    });
  }

  void _checkLater() {
    _pollTimer?.cancel();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => MyRentalsScreen(
          user: widget.user,
          accessToken: widget.accessToken,
        ),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: animation.drive(
            Tween(begin: const Offset(1.0, 0.0), end: Offset.zero)
                .chain(CurveTween(curve: Curves.easeOutCubic)),
          ),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
          (route) => route.isFirst,
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _pollTimer?.cancel();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0A0F),
        body: Stack(
          children: [
            _buildBackground(),
            SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: child,
                ),
                child: _paymentState == _PaymentState.pending
                    ? _buildPendingView()
                    : _buildResultView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Background ─────────────────────────────────────────────────────────────

  Widget _buildBackground() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        final opacity = _paymentState == _PaymentState.pending
            ? 0.06 + _glowAnim.value * 0.06
            : 0.0;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.2),
              radius: 1.2,
              colors: [
                _operatorPrimary.withOpacity(opacity),
                const Color(0xFF0A0A0F),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Pending View ───────────────────────────────────────────────────────────

  Widget _buildPendingView() {
    return FadeTransition(
      key: const ValueKey('pending'),
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildTopBar(),
              const Spacer(flex: 2),
              _buildOrbitalRing(),
              const SizedBox(height: 52),
              _buildPendingText(),
              const SizedBox(height: 28),
              _buildAnimatedDots(),
              const Spacer(flex: 3),
              _buildAmountCard(),
              const SizedBox(height: 20),
              _buildCheckLaterButton(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        GestureDetector(
          onTap: _checkLater,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 1),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white54, size: 16),
          ),
        ),
        const Spacer(),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _operatorPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _operatorPrimary.withOpacity(0.6),
                        blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _operatorLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrbitalRing() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing glow keeps the premium feel behind the Lottie
          AnimatedBuilder(
            animation: _glowAnim,
            builder: (_, __) => Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _operatorPrimary
                        .withOpacity(0.12 + _glowAnim.value * 0.10),
                    blurRadius: 40 + _glowAnim.value * 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Processing / waiting Lottie (loops until CamPay resolves)
          Lottie.asset(
            kPaymentPendingLottie,
            width: 195,
            height: 195,
            repeat: true,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AnimatedBuilder(
              animation: _orbitController,
              builder: (_, child) => Transform.rotate(
                angle: _orbitController.value * math.pi * 2,
                child: child,
              ),
              child: CustomPaint(
                size: const Size(150, 150),
                painter: _OrbitRingPainter(
                  color: _operatorSecondary,
                  strokeWidth: 3,
                  dashRatio: 0.25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingText() {
    return Column(
      children: [
        Text(
          'Waiting for payment',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: -0.5,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Check your phone and enter your\n$_operatorLabel PIN to confirm.',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.45),
            height: 1.6,
            letterSpacing: 0.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAnimatedDots() {
    return AnimatedBuilder(
      animation: _dotsController,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final t = (_dotsController.value - i * 0.25).clamp(0.0, 1.0);
            final bounce = math.sin(t * math.pi);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: 8,
              height: 8 + bounce * 6,
              decoration: BoxDecoration(
                color: _operatorPrimary
                    .withOpacity(0.35 + bounce * 0.65),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildAmountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _operatorPrimary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.car_rental_rounded,
                color: _operatorPrimary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.vehicleName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Car rental payment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'XAF ${widget.totalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _operatorPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckLaterButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _checkLater,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: Colors.white.withOpacity(0.12), width: 1),
          ),
        ),
        child: Text(
          'Check Later in My Rentals',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  // ── Result View ────────────────────────────────────────────────────────────

  Widget _buildResultView() {
    final isSuccess = _paymentState == _PaymentState.success;
    return Stack(
      key: const ValueKey('result'),
      children: [
        // Particle burst (success only)
        if (isSuccess)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _particleController,
              builder: (_, __) => CustomPaint(
                painter: _ParticlePainter(
                  particles: _particles,
                  progress: _particleController.value,
                  origin: const Offset(0.5, 0.42),
                ),
              ),
            ),
          ),

        // Main content
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // Close / done top bar
                Row(
                  children: [
                    GestureDetector(
                      onTap: _checkLater,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white54, size: 18),
                      ),
                    ),
                  ],
                ),
                const Spacer(flex: 2),

                // Icon
                ScaleTransition(
                  scale: _resultScale,
                  child: FadeTransition(
                    opacity: _resultFade,
                    child: isSuccess
                        ? _buildSuccessIcon()
                        : _buildFailureIcon(),
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                FadeTransition(
                  opacity: _resultFade,
                  child: Column(
                    children: [
                      Text(
                        isSuccess ? 'Payment Confirmed!' : 'Payment Failed',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isSuccess
                            ? 'Your rental of ${widget.vehicleName} is confirmed and booked.'
                            : 'The payment was not completed.\nYou can try again or pay on pickup.',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.5),
                          height: 1.6,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 3),

                // Amount recap
                FadeTransition(
                  opacity: _resultFade,
                  child: _buildResultAmountBadge(isSuccess),
                ),

                const SizedBox(height: 28),

                // CTA button
                FadeTransition(
                  opacity: _resultFade,
                  child: _buildResultButton(isSuccess),
                ),

                if (!isSuccess) ...[
                  const SizedBox(height: 12),
                  FadeTransition(
                    opacity: _resultFade,
                    child: SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: _checkLater,
                        style: TextButton.styleFrom(
                          padding:
                          const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                                color: Colors.white.withOpacity(0.12),
                                width: 1),
                          ),
                        ),
                        child: Text(
                          'View My Rentals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessIcon() {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring — keeps the premium feel behind the Lottie
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00D084).withOpacity(0.3),
                  blurRadius: 48,
                  spreadRadius: 8,
                ),
              ],
            ),
          ),
          // Success Lottie
          Lottie.asset(
            kPaymentSuccessLottie,
            width: 180,
            height: 180,
            repeat: false,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => AnimatedBuilder(
              animation: _checkAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(44, 44),
                painter: _CheckPainter(
                    progress: _checkAnim.value, color: const Color(0xFF00D084)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailureIcon() {
    return AnimatedBuilder(
      animation: _shakeAnim,
      builder: (_, child) {
        final shake = math.sin(_shakeAnim.value * math.pi * 6) *
            10 *
            (1 - _shakeAnim.value);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: child,
        );
      },
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4560).withOpacity(0.3),
                    blurRadius: 48,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFFFF4560).withOpacity(0.25),
                    width: 1.5),
              ),
            ),
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0xFFFF4560), Color(0xFFCC2244)],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _xAnim,
              builder: (_, __) => CustomPaint(
                size: const Size(40, 40),
                painter: _XPainter(
                    progress: _xAnim.value, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultAmountBadge(bool isSuccess) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        children: [
          Text(
            'XAF ${widget.totalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isSuccess
                  ? const Color(0xFF00D084)
                  : const Color(0xFFFF4560),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.vehicleName,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.4),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultButton(bool isSuccess) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _checkLater,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSuccess
              ? const Color(0xFF00D084)
              : const Color(0xFFFF4560),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: Text(
          isSuccess ? 'View My Rentals' : 'Try Again',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _PaymentState { pending, success, failed }

// ─────────────────────────────────────────────────────────────────────────────
// CUSTOM PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

/// Dashed orbit ring
class _OrbitRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashRatio; // fraction of circumference that is solid

  const _OrbitRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashRatio,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const steps = 120;
    final dashLen = (math.pi * 2 * dashRatio);
    final gapLen = (math.pi * 2 * (1 - dashRatio)) / (steps ~/ 2).toDouble();
    var angle = 0.0;
    bool drawing = true;

    final path = Path();
    while (angle < math.pi * 2) {
      final segLen = drawing ? dashLen / (steps ~/ 2) : gapLen;
      if (drawing) {
        final end = angle + segLen;
        path.addArc(
          Rect.fromCircle(center: center, radius: radius),
          angle,
          segLen,
        );
      }
      angle += segLen;
      drawing = !drawing;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OrbitRingPainter old) => false;
}

/// Animated checkmark draw
class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Check path: from bottom-left, to middle-bottom, to top-right
    final p1 = Offset(size.width * 0.18, size.height * 0.52);
    final p2 = Offset(size.width * 0.42, size.height * 0.75);
    final p3 = Offset(size.width * 0.82, size.height * 0.28);

    final totalLen =
        (p2 - p1).distance + (p3 - p2).distance;
    final drawn = progress * totalLen;

    final path = Path();
    path.moveTo(p1.dx, p1.dy);

    final seg1 = (p2 - p1).distance;
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final rem = drawn - seg1;
      final seg2 = (p3 - p2).distance;
      final t = (rem / seg2).clamp(0.0, 1.0);
      path.lineTo(p2.dx + (p3.dx - p2.dx) * t,
          p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Animated X draw
class _XPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _XPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final pad = size.width * 0.22;

    // First arm
    final arm1Progress = (progress * 2).clamp(0.0, 1.0);
    if (arm1Progress > 0) {
      canvas.drawLine(
        Offset(pad, pad),
        Offset(pad + (size.width - 2 * pad) * arm1Progress,
            pad + (size.height - 2 * pad) * arm1Progress),
        paint,
      );
    }

    // Second arm
    final arm2Progress = ((progress - 0.5) * 2).clamp(0.0, 1.0);
    if (arm2Progress > 0) {
      canvas.drawLine(
        Offset(size.width - pad, pad),
        Offset(size.width - pad - (size.width - 2 * pad) * arm2Progress,
            pad + (size.height - 2 * pad) * arm2Progress),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_XPainter old) => old.progress != progress;
}

/// Particle burst
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final Color color;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress; // 0 → 1
  final Offset origin; // fractional

  const _ParticlePainter({
    required this.particles,
    required this.progress,
    required this.origin,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final originPx =
    Offset(origin.dx * size.width, origin.dy * size.height);
    final eased =
    Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
    final fade = 1.0 - Curves.easeIn.transform(progress.clamp(0.0, 1.0));

    for (final p in particles) {
      final dist = p.speed * eased;
      final pos = originPx +
          Offset(
            dist * math.cos(p.angle),
            dist * math.sin(p.angle),
          );
      final paint = Paint()
        ..color = p.color.withOpacity(fade.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, p.size * (1 - eased * 0.5), paint);
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.progress != progress;
}