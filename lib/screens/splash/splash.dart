// lib/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication service/api_services.dart';
import '../../main.dart';
import '../../service/mode_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // ANIMATION CONTROLLERS
  // ═══════════════════════════════════════════════════════════════

  late AnimationController _logoController;
  late AnimationController _pulseController;
  late AnimationController _textController;
  late AnimationController _ringController;
  late AnimationController _exitController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;
  late Animation<double> _titleOpacity;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _dot1;
  late Animation<double> _dot2;
  late Animation<double> _dot3;
  late Animation<Offset> _exitSlide;
  late Animation<double> _exitFade;

  // ═══════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════

  final AuthService _authService = AuthService();

  String _statusText = 'Starting up...';
  bool _exitTriggered = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startSequence();
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIMATION SETUP
  // ═══════════════════════════════════════════════════════════════

  void _setupAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _ringScale = Tween<double>(begin: 0.85, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _ringOpacity = Tween<double>(begin: 0.35, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.35, 1.0, curve: Curves.easeOut),
      ),
    );

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _dot1 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _dot2 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeInOut),
      ),
    );

    _dot3 = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeInOut),
      ),
    );

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _exitSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -1.0),
    ).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _exitController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIMATION SEQUENCE
  // ═══════════════════════════════════════════════════════════════

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    _logoController.forward();
    _pulseController.repeat();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _textController.forward();
    _ringController.repeat(reverse: true);

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _checkAuthAndNavigate();
  }

  void _setStatus(String text) {
    if (!mounted) return;
    setState(() => _statusText = text);
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTH CHECK + NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _checkAuthAndNavigate() async {
    if (_exitTriggered) return;

    try {
      _setStatus('Checking session...');
      await Future.delayed(const Duration(milliseconds: 300));

      final prefs = await SharedPreferences.getInstance();

      final savedRefreshToken = prefs.getString(AuthService.kRefreshToken);
      final savedAccessToken = prefs.getString(AuthService.kAccessToken);
      final savedUserType = prefs.getString(AuthService.kUserType) ?? '';
      final savedUserId = prefs.getString(AuthService.kUserUuid) ?? '';
      final savedActiveMode = prefs.getString(AuthService.kActiveMode) ?? '';

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔍 [SPLASH] Checking persisted session...');
      debugPrint('   Access Token  : ${savedAccessToken != null && savedAccessToken.isNotEmpty ? "✅ Found" : "❌ None"}');
      debugPrint('   Refresh Token : ${savedRefreshToken != null && savedRefreshToken.isNotEmpty ? "✅ Found" : "❌ None"}');
      debugPrint('   User Type     : ${savedUserType.isNotEmpty ? savedUserType : "N/A"}');
      debugPrint('   User ID       : ${savedUserId.isNotEmpty ? savedUserId : "N/A"}');
      debugPrint('   Active Mode   : ${savedActiveMode.isNotEmpty ? savedActiveMode : "N/A"}');

      // Persistent login must be based on refresh_token, not access_token.
      if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
        debugPrint('   → No refresh token — clearing session and sending to /login');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        await _authService.clearSession();

        _setStatus('Welcome to WEGO');
        await Future.delayed(const Duration(milliseconds: 400));
        await _navigateTo('/login');
        return;
      }

      // Validate session with backend and rotate refresh token.
      _setStatus('Restoring session...');

      final restored = await _authService.restoreSession();

      if (!restored) {
        debugPrint('❌ [SPLASH] Session restore failed — sending to /login');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        await _authService.clearSession();

        _setStatus('Welcome to WEGO');
        await Future.delayed(const Duration(milliseconds: 400));
        await _navigateTo('/login');
        return;
      }

      // Reload fresh values saved by AuthService.restoreSession().
      final freshAccessToken = prefs.getString(AuthService.kAccessToken);
      final freshUserType = prefs.getString(AuthService.kUserType) ?? '';
      final freshUserId = prefs.getString(AuthService.kUserUuid) ?? '';

      final activeMode =
          await _authService.getActiveMode() ??
              await ModeService.getCurrentMode();

      final route = ModeService.routeForMode(activeMode);

      debugPrint('✅ [SPLASH] Session restored successfully');
      debugPrint('   Fresh Access : ${freshAccessToken != null && freshAccessToken.isNotEmpty ? "✅ Found" : "❌ None"}');
      debugPrint('   User Type    : ${freshUserType.isNotEmpty ? freshUserType : "N/A"}');
      debugPrint('   User ID      : ${freshUserId.isNotEmpty ? freshUserId : "N/A"}');
      debugPrint('   Active Mode  : $activeMode');
      debugPrint('   Route        : $route');

      // Connect socket only after token refresh succeeded.
      if (
      freshAccessToken != null &&
          freshAccessToken.isNotEmpty &&
          freshUserId.isNotEmpty &&
          freshUserType.isNotEmpty
      ) {
        _setStatus('Connecting...');

        try {
          await SocketHelper.connect(
            accessToken: freshAccessToken,
            userId: freshUserId,
            userType: freshUserType,
            onTokenExpired: () async {
              final refreshed = await _authService.refreshAccessToken();

              if (refreshed) {
                final newToken = await _authService.getAccessToken();
                return newToken;
              }

              return null;
            },
          );

          debugPrint('✅ [SPLASH] Socket reconnected');

        } catch (e) {
          debugPrint('⚠️ [SPLASH] Socket reconnect failed, continuing anyway: $e');
        }
      } else {
        debugPrint('⚠️ [SPLASH] Missing socket session data, skipping socket connect');
      }

      await Future.delayed(const Duration(milliseconds: 300));

      final statusLabels = {
        'PASSENGER': 'Loading your dashboard...',
        'DRIVER': 'Loading driver mode...',
        'DELIVERY_AGENT': 'Loading delivery dashboard...',
      };

      _setStatus(statusLabels[activeMode] ?? 'Loading...');

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      await Future.delayed(const Duration(milliseconds: 400));
      await _navigateTo(route);

    } catch (e) {
      debugPrint('❌ [SPLASH] Auth check error: $e → /login');

      try {
        await _authService.clearSession();
      } catch (_) {}

      _setStatus('Welcome to WEGO');
      await Future.delayed(const Duration(milliseconds: 400));
      await _navigateTo('/login');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // EXIT ANIMATION + NAVIGATE
  // ═══════════════════════════════════════════════════════════════

  Future<void> _navigateTo(String route) async {
    if (!mounted || _exitTriggered) return;

    _exitTriggered = true;

    _pulseController.stop();
    _ringController.stop();

    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _logoController.dispose();
    _pulseController.dispose();
    _textController.dispose();
    _ringController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SlideTransition(
        position: _exitSlide,
        child: FadeTransition(
          opacity: _exitFade,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BackgroundPainter(),
                ),
              ),

              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (_, __) => Transform.scale(
                              scale: _ringScale.value,
                              child: Opacity(
                                opacity: _ringOpacity.value,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFFFDC71),
                                      width: 2.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          AnimatedBuilder(
                            animation: _logoController,
                            builder: (_, child) => FadeTransition(
                              opacity: _logoOpacity,
                              child: SlideTransition(
                                position: _logoSlide,
                                child: Transform.scale(
                                  scale: _logoScale.value,
                                  child: child,
                                ),
                              ),
                            ),
                            child: Container(
                              width: 108,
                              height: 108,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A1A1A),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFFFDC71),
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFDC71).withOpacity(0.25),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.6),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Text(
                                    'W',
                                    style: TextStyle(
                                      fontSize: 52,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFFDC71),
                                      letterSpacing: -2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 36),

                    AnimatedBuilder(
                      animation: _textController,
                      builder: (_, child) => FadeTransition(
                        opacity: _titleOpacity,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: child,
                        ),
                      ),
                      child: const Text(
                        'WEGO',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFDC71),
                          letterSpacing: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    AnimatedBuilder(
                      animation: _textController,
                      builder: (_, child) => FadeTransition(
                        opacity: _subtitleOpacity,
                        child: child!,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 1,
                            color: const Color(0xFFFFDC71).withOpacity(0.5),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Your ride, your way',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF888888),
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 28,
                            height: 1,
                            color: const Color(0xFFFFDC71).withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Positioned(
                bottom: size.height * 0.1,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) => FadeTransition(
                    opacity: _subtitleOpacity,
                    child: child!,
                  ),
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) {
                          return FadeTransition(
                            opacity: anim,
                            child: child,
                          );
                        },
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      AnimatedBuilder(
                        animation: _ringController,
                        builder: (_, __) => Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildDot(_dot1.value),
                            const SizedBox(width: 8),
                            _buildDot(_dot2.value),
                            const SizedBox(width: 8),
                            _buildDot(_dot3.value),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(double opacity) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFFFFDC71),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BACKGROUND PAINTER
// ═══════════════════════════════════════════════════════════════

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.65,
        colors: [
          const Color(0xFFFFDC71).withOpacity(0.06),
          const Color(0xFFFFDC71).withOpacity(0.02),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      glowPaint,
    );

    final topPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 0.5,
        colors: [
          const Color(0xFFFFDC71).withOpacity(0.04),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      topPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}