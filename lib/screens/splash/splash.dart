
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../authentication service/api_services.dart';
import '../../main.dart';
import '../../service/mode_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE (single source of truth for theming the splash)
// ─────────────────────────────────────────────────────────────────────────────
const Color _kGold = Color(0xFFFFDC71);
const Color _kBg = Color(0xFF0A0A0A);
const Color _kBadge = Color(0xFF1A1A1A);

double _lerpD(double a, double b, double t) => a + (b - a) * t;

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

  late AnimationController _introController;   // logo badge entrance (one-shot)
  late AnimationController _textController;     // wordmark + tagline (one-shot)
  late AnimationController _radarController;    // GPS ping + sweep (loop)
  late AnimationController _roadController;     // scrolling road + car (loop)
  late AnimationController _ambientController;  // map drift + glow breathe (loop)
  late AnimationController _exitController;     // exit transition (one-shot)

  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<Offset> _logoSlide;
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
    // Logo badge entrance ----------------------------------------------------
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _introController, curve: Curves.elasticOut),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _introController, curve: Curves.easeOutCubic),
    );

    // Wordmark + tagline -----------------------------------------------------
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    // Looping ambient layers -------------------------------------------------
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    _roadController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );

    // Exit -------------------------------------------------------------------
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
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
    // Start the ambient map drift immediately so the backdrop is alive.
    _ambientController.repeat();

    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    _introController.forward();
    _radarController.repeat();

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    _textController.forward();
    _roadController.repeat();

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    await _checkAuthAndNavigate();
  }

  void _setStatus(String text) {
    if (!mounted) return;
    setState(() => _statusText = text);
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTH CHECK + NAVIGATION   (unchanged logic)
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

    _radarController.stop();
    _roadController.stop();
    _ambientController.stop();

    await _exitController.forward();

    if (!mounted) return;

    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  void dispose() {
    _introController.dispose();
    _textController.dispose();
    _radarController.dispose();
    _roadController.dispose();
    _ambientController.dispose();
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
      backgroundColor: _kBg,
      body: SlideTransition(
        position: _exitSlide,
        child: FadeTransition(
          opacity: _exitFade,
          child: Stack(
            children: [
              // ── Layer 1: animated map backdrop ──────────────────────────
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _ambientController,
                  builder: (_, __) => CustomPaint(
                    painter: _MapBackdropPainter(_ambientController.value),
                  ),
                ),
              ),

              // ── Center: hero badge + wordmark + tagline ─────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Hero: radar ping + logo badge
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedBuilder(
                            animation: _radarController,
                            builder: (_, __) => CustomPaint(
                              size: const Size(200, 200),
                              painter: _RadarPainter(_radarController.value),
                            ),
                          ),
                          FadeTransition(
                            opacity: _logoFade,
                            child: SlideTransition(
                              position: _logoSlide,
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: _buildLogoBadge(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Wordmark — staggered letter reveal
                    _buildWordmark(),

                    const SizedBox(height: 16),

                    // Tagline with flanking rules
                    _buildTagline(),
                  ],
                ),
              ),

              // ── Bottom: status text + driving-car road loader ───────────
              Positioned(
                bottom: size.height * 0.1,
                left: 0,
                right: 0,
                child: AnimatedBuilder(
                  animation: _textController,
                  builder: (_, child) {
                    final op =
                    ((_textController.value - 0.4) / 0.6).clamp(0.0, 1.0);
                    return Opacity(opacity: op, child: child);
                  },
                  child: Column(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, anim) =>
                            FadeTransition(opacity: anim, child: child),
                        child: Text(
                          _statusText,
                          key: ValueKey(_statusText),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A6A6A),
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // The car-on-road loader
                      SizedBox(
                        width: 230,
                        height: 46,
                        child: AnimatedBuilder(
                          animation: _roadController,
                          builder: (_, __) => CustomPaint(
                            painter: _RoadLoaderPainter(_roadController.value),
                          ),
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

  // ── Logo badge ────────────────────────────────────────────────────────────
  Widget _buildLogoBadge() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: _kBadge,
        shape: BoxShape.circle,
        border: Border.all(color: _kGold, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _kGold.withOpacity(0.28),
            blurRadius: 34,
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
          width: 62,
          height: 62,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Text(
            'W',
            style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: _kGold,
              letterSpacing: -2,
            ),
          ),
        ),
      ),
    );
  }

  // ── Wordmark with per-letter staggered entrance ────────────────────────────
  Widget _buildWordmark() {
    const letters = ['W', 'E', 'G', 'O'];
    const stagger = 0.12;
    final span = 1 - stagger * (letters.length - 1); // remaining travel window

    return AnimatedBuilder(
      animation: _textController,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(letters.length, (i) {
            final raw =
            ((_textController.value - i * stagger) / span).clamp(0.0, 1.0);
            final e = Curves.easeOutCubic.transform(raw);
            return Opacity(
              opacity: e,
              child: Transform.translate(
                offset: Offset(0, (1 - e) * 20),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Text(
                    letters[i],
                    style: TextStyle(
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: _kGold,
                      shadows: [
                        Shadow(
                          color: _kGold.withOpacity(0.45),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  // ── Tagline ────────────────────────────────────────────────────────────────
  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (_, child) {
        final op = ((_textController.value - 0.45) / 0.55).clamp(0.0, 1.0);
        return Opacity(opacity: op, child: child);
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 30, height: 1, color: _kGold.withOpacity(0.45)),
          const SizedBox(width: 12),
          const Text(
            'YOUR RIDE, YOUR WAY',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9A9A9A),
              letterSpacing: 3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 30, height: 1, color: _kGold.withOpacity(0.45)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER 1 — MAP BACKDROP (breathing glow + drifting grid + vignette)
// ═══════════════════════════════════════════════════════════════════════════
class _MapBackdropPainter extends CustomPainter {
  final double t; // 0..1 looping
  _MapBackdropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = size.center(Offset.zero);

    // Breathing gold glow at the center.
    final breathe = (math.sin(t * 2 * math.pi) + 1) / 2; // 0..1
    final glowOpacity = _lerpD(0.05, 0.10, breathe);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _kGold.withOpacity(glowOpacity),
          _kGold.withOpacity(glowOpacity * 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.longestSide * 0.6),
      );
    canvas.drawRect(rect, glowPaint);

    // Drifting "street" grid — two axes at slightly different speeds (parallax).
    const gap = 58.0;
    final dxOff = (t * gap) % gap;
    final dyOff = (t * gap * 0.6) % gap;
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.035)
      ..strokeWidth = 1;

    for (double x = -gap + dxOff; x < size.width + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = -gap + dyOff; y < size.height + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // A faint gold "route" accent threading through the grid.
    final routePaint = Paint()
      ..color = _kGold.withOpacity(0.05)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final ry = size.height * 0.30;
    canvas.drawLine(Offset(0, ry), Offset(size.width * 0.55, ry), routePaint);
    canvas.drawLine(
      Offset(size.width * 0.55, ry),
      Offset(size.width * 0.55, size.height * 0.72),
      routePaint,
    );

    // Vignette: focus the center, fade the grid toward the edges.
    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [Colors.transparent, _kBg.withOpacity(0.0), _kBg],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(center: center, radius: size.longestSide * 0.72),
      );
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(covariant _MapBackdropPainter old) => old.t != t;
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER 2 — GPS RADAR (expanding ping rings + rotating sweep)
// ═══════════════════════════════════════════════════════════════════════════
class _RadarPainter extends CustomPainter {
  final double progress; // 0..1 looping
  _RadarPainter(this.progress);

  static const double _minR = 58.0; // just outside the 110px badge
  static const double _maxR = 96.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Rotating sweep wedge (drawn first, behind the rings & badge).
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(progress * 2 * math.pi);
    final sweepRect = Rect.fromCircle(center: Offset.zero, radius: _maxR);
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi / 3,
        colors: [_kGold.withOpacity(0.0), _kGold.withOpacity(0.14)],
      ).createShader(sweepRect);
    final wedge = Path()
      ..moveTo(0, 0)
      ..arcTo(sweepRect, 0, math.pi / 3, false)
      ..close();
    canvas.drawPath(wedge, sweepPaint);
    canvas.restore();

    // Three staggered ping rings expanding outward and fading.
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final r = _lerpD(_minR, _maxR, phase);
      final a = 1 - phase;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 + 1.6 * a
        ..color = _kGold.withOpacity(0.45 * a);
      canvas.drawCircle(c, r, ring);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.progress != progress;
}

// ═══════════════════════════════════════════════════════════════════════════
// PAINTER 3 — ROAD LOADER (scrolling lane dashes + a driving gold car)
// ═══════════════════════════════════════════════════════════════════════════
class _RoadLoaderPainter extends CustomPainter {
  final double progress; // 0..1 looping
  _RoadLoaderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final roadY = size.height * 0.66;

    // Road surface line.
    final base = Paint()
      ..color = _kGold.withOpacity(0.16)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, roadY), Offset(size.width, roadY), base);

    // Scrolling lane dashes (move right → left to imply forward motion).
    const dash = 16.0, gap = 14.0;
    const period = dash + gap;
    final off = (progress * period) % period;
    final dashPaint = Paint()
      ..color = _kGold.withOpacity(0.55)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (double x = -period; x < size.width + period; x += period) {
      final sx = x - off;
      canvas.drawLine(Offset(sx, roadY), Offset(sx + dash, roadY), dashPaint);
    }

    // The car bobs gently while the world scrolls beneath it.
    final bob = math.sin(progress * 2 * math.pi * 2) * 1.6;
    final cx = size.width * 0.5;
    final cy = roadY - 12 + bob;

    // Motion streaks trailing the car.
    final streak = Paint()
      ..color = _kGold.withOpacity(0.22)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      final sy = cy - 3 + i * 3.0;
      final sx = cx - 24 - i * 9.0;
      canvas.drawLine(Offset(sx, sy), Offset(sx - 9, sy), streak);
    }

    _drawCar(canvas, Offset(cx, cy));
  }

  void _drawCar(Canvas canvas, Offset c) {
    final body = Paint()..color = _kGold;

    // Soft ground shadow.
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, c.dy + 11), width: 36, height: 7),
      shadow,
    );

    // Lower body.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 32, height: 11),
        const Radius.circular(5),
      ),
      body,
    );

    // Cabin / roof.
    final roof = Path()
      ..moveTo(c.dx - 8, c.dy - 4)
      ..lineTo(c.dx - 3, c.dy - 11)
      ..lineTo(c.dx + 6, c.dy - 11)
      ..lineTo(c.dx + 10, c.dy - 4)
      ..close();
    canvas.drawPath(roof, body);

    // Window.
    final win = Paint()..color = _kBg.withOpacity(0.88);
    final winPath = Path()
      ..moveTo(c.dx - 5, c.dy - 5)
      ..lineTo(c.dx - 2, c.dy - 9.5)
      ..lineTo(c.dx + 5, c.dy - 9.5)
      ..lineTo(c.dx + 8, c.dy - 5)
      ..close();
    canvas.drawPath(winPath, win);

    // Wheels (dark tyre + gold rim).
    final tyre = Paint()..color = const Color(0xFF111111);
    final rim = Paint()
      ..color = _kGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final wx in [c.dx - 9.0, c.dx + 9.0]) {
      final wc = Offset(wx, c.dy + 6);
      canvas.drawCircle(wc, 4.2, tyre);
      canvas.drawCircle(wc, 4.2, rim);
    }

    // Headlight glint.
    canvas.drawCircle(
      Offset(c.dx + 15, c.dy),
      1.4,
      Paint()..color = Colors.white.withOpacity(0.9),
    );
  }

  @override
  bool shouldRepaint(covariant _RoadLoaderPainter old) =>
      old.progress != progress;
}