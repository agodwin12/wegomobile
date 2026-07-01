// lib/screens/login/login_screen.dart

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../authentication service/api_services.dart';
import '../../authentication service/google_auth_service.dart';
import '../../core/config.dart';
import '../../main.dart';
import '../../service/api/service_socket_listener.dart';
import '../../service/mode_service.dart';
import '../../service/notification_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

double _lerpD(double a, double b, double t) => a + (b - a) * t;

// ═══════════════════════════════════════════════════════════════════════════════
// WAVE PAINTER  (fill + premium gold seam along the top curve)
// ═══════════════════════════════════════════════════════════════════════════════

class _WavePainter extends CustomPainter {
  final Color waveColor;

  const _WavePainter({required this.waveColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = waveColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.35);
    path.cubicTo(
      size.width * 0.25, size.height * -0.1,
      size.width * 0.55, size.height * 0.9,
      size.width, size.height * 0.2,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // Subtle gold hairline tracing the seam between hero and form.
    final edge = Path()
      ..moveTo(0, size.height * 0.35)
      ..cubicTo(
        size.width * 0.25, size.height * -0.1,
        size.width * 0.55, size.height * 0.9,
        size.width, size.height * 0.2,
      );
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = LinearGradient(
        colors: [
          AppColors.primaryGold.withOpacity(0.0),
          AppColors.primaryGold.withOpacity(0.55),
          AppColors.primaryGold.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(edge, edgePaint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.waveColor != waveColor;
}

// ═══════════════════════════════════════════════════════════════════════════════
// HERO SCENE PAINTER
//   Animated ride-hailing backdrop: drifting map grid, a route flowing toward a
//   pulsing destination beacon, breathing glow, and floating ambient particles.
// ═══════════════════════════════════════════════════════════════════════════════

class _HeroScenePainter extends CustomPainter {
  final double ambient; // 0..1 slow loop  (grid drift, glow, particles)
  final double pulse;   // 0..1 fast loop  (beacon rings, flowing route dots)

  const _HeroScenePainter({required this.ambient, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final gold = AppColors.primaryGold;
    final rect = Offset.zero & size;

    // Destination beacon — upper right (where the old rings sat).
    final beacon = Offset(w * 0.82, h * 0.30);

    // ── Breathing radial glow around the beacon ──────────────────────────────
    final breathe = (math.sin(ambient * 2 * math.pi) + 1) / 2; // 0..1
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          gold.withOpacity(_lerpD(0.10, 0.18, breathe)),
          gold.withOpacity(0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: beacon, radius: w * 0.5));
    canvas.drawRect(rect, glow);

    // ── Drifting map grid (subtle) ───────────────────────────────────────────
    const gap = 46.0;
    final dx = (ambient * gap) % gap;
    final dy = (ambient * gap * 0.5) % gap;
    final grid = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = -gap + dx; x < w + gap; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = -gap + dy; y < h + gap; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // ── Route path: pickup → beacon (kept on the right, clear of the text) ───
    final start = Offset(w * 0.52, h * 0.66);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        w * 0.66, h * 0.86,
        w * 0.62, h * 0.34,
        beacon.dx, beacon.dy,
      );
    canvas.drawPath(
      route,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = gold.withOpacity(0.22),
    );

    // Flowing glowing dots travelling toward the beacon.
    final metric = route.computeMetrics().first;
    final len = metric.length;
    for (int i = 0; i < 3; i++) {
      final frac = (pulse + i / 3) % 1.0;
      final tan = metric.getTangentForOffset(len * frac);
      if (tan == null) continue;
      final fade = math.sin(frac * math.pi); // 0 at ends, 1 mid → hides reset
      canvas.drawCircle(
        tan.position,
        7,
        Paint()
          ..color = gold.withOpacity(0.22 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        tan.position,
        3.0,
        Paint()..color = gold.withOpacity(0.9 * fade),
      );
    }

    // ── Pulsing beacon rings ─────────────────────────────────────────────────
    for (int i = 0; i < 3; i++) {
      final phase = (pulse + i / 3) % 1.0;
      final r = _lerpD(10, 60, phase);
      final a = 1 - phase;
      canvas.drawCircle(
        beacon,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * a + 0.4
          ..color = gold.withOpacity(0.5 * a),
      );
    }

    // Pickup pin at the route start.
    _drawPin(canvas, start, gold);

    // Destination dot at the beacon.
    canvas.drawCircle(beacon, 5, Paint()..color = gold);
    canvas.drawCircle(
      beacon,
      5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = AppColors.primaryDark,
    );

    // ── Floating ambient particles ───────────────────────────────────────────
    final rnd = math.Random(7);
    for (int i = 0; i < 14; i++) {
      final bx = rnd.nextDouble();
      final speed = 0.4 + rnd.nextDouble() * 0.8;
      final dot = 0.8 + rnd.nextDouble() * 1.8;
      final off = rnd.nextDouble();
      final phase = (ambient * speed + off) % 1.0;
      final px = bx * w + math.sin((phase + bx) * 2 * math.pi) * 6;
      final py = h - phase * h; // drift upward
      final pa = math.sin(phase * math.pi) * 0.55;
      canvas.drawCircle(Offset(px, py), dot, Paint()..color = gold.withOpacity(pa * 0.6));
    }
  }

  void _drawPin(Canvas canvas, Offset base, Color gold) {
    final p = Paint()..color = gold;
    // Head.
    canvas.drawCircle(Offset(base.dx, base.dy - 9), 5.5, p);
    canvas.drawCircle(
      Offset(base.dx, base.dy - 9),
      2.2,
      Paint()..color = AppColors.primaryDark,
    );
    // Pointer.
    final ptr = Path()
      ..moveTo(base.dx - 4, base.dy - 7)
      ..lineTo(base.dx, base.dy)
      ..lineTo(base.dx + 4, base.dy - 7)
      ..close();
    canvas.drawPath(ptr, p);
  }

  @override
  bool shouldRepaint(covariant _HeroScenePainter old) =>
      old.ambient != ambient || old.pulse != pulse;
}

// ═══════════════════════════════════════════════════════════════════════════════
// GOOGLE ICON PAINTER
// ═══════════════════════════════════════════════════════════════════════════════

class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    void arc(Paint p, double start, double sweep) =>
        canvas.drawArc(rect, start, sweep, false, p);

    Paint p(Color c) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round;

    arc(p(const Color(0xFF4285F4)), -0.5, 1.5);
    arc(p(const Color(0xFF34A853)), 1.0, 1.05);
    arc(p(const Color(0xFFFBBC05)), 2.05, 1.05);
    arc(p(const Color(0xFFEA4335)), 3.1, 1.0);

    canvas.drawLine(
      center,
      Offset(center.dx + radius, center.dy),
      p(const Color(0xFF4285F4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// LOGIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {

  // ─── Controllers & State ────────────────────────────────────────────────────

  final _authService = AuthService();

  final emailCtrl    = TextEditingController();
  final phoneCtrl    = TextEditingController();
  final pwCtrl       = TextEditingController();
  final fullNameCtrl = TextEditingController();

  bool loading          = false;
  bool rememberMe       = false;
  bool isPhoneMode      = false;
  bool _obscurePassword = true;
  bool _signupExpanded  = false;

  String selectedCountryCode = '+237';
  String selectedCountryFlag = '🇨🇲';

  final FocusNode _emailFocus    = FocusNode();
  final FocusNode _phoneFocus    = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  // ─── Animation Controllers ──────────────────────────────────────────────────

  late AnimationController _entryController;
  late AnimationController _toastController;
  late AnimationController _buttonController;
  late AnimationController _signupExpandController;
  late AnimationController _ambientController; // slow ambient loop (hero)
  late AnimationController _beaconController;  // fast pulse loop (hero)

  late Animation<double>  _heroFade;
  late Animation<Offset>  _heroSlide;
  late Animation<double>  _formFade;
  late Animation<Offset>  _formSlide;
  late Animation<double>  _toastOpacity;
  late Animation<Offset>  _toastSlide;
  late Animation<double>  _buttonScale;
  late Animation<double>  _signupHeight;

  bool   _showToast      = false;
  bool   _isToastSuccess = false;
  String _toastMessage   = '';

  final List<Map<String, String>> countries = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroon'},
    {'code': '+1',   'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44',  'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+33',  'flag': '🇫🇷', 'name': 'France'},
    {'code': '+49',  'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+27',  'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'Kenya'},
  ];

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _playEntryAnimation();

    _emailFocus.addListener(_onFocusChange);
    _phoneFocus.addListener(_onFocusChange);
    _passwordFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  void _initAnimations() {
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 1100),
      vsync: this,
    );

    _toastController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 140),
      vsync: this,
    );

    _signupExpandController = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );

    _ambientController = AnimationController(
      duration: const Duration(milliseconds: 7000),
      vsync: this,
    );

    _beaconController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    );

    _heroSlide = Tween<Offset>(
      begin: const Offset(0, -0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic),
    ));

    _heroFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic),
    ));

    _formFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _toastSlide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _toastController, curve: Curves.easeOutBack));

    _toastOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastController, curve: Curves.easeOut),
    );

    _buttonScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _signupHeight = CurvedAnimation(
      parent: _signupExpandController,
      curve: Curves.easeInOutCubic,
    );
  }

  void _playEntryAnimation() {
    // Keep the hero alive continuously.
    _ambientController.repeat();
    _beaconController.repeat();

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _entryController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _toastController.dispose();
    _buttonController.dispose();
    _signupExpandController.dispose();
    _ambientController.dispose();
    _beaconController.dispose();

    _emailFocus
      ..removeListener(_onFocusChange)
      ..dispose();
    _phoneFocus
      ..removeListener(_onFocusChange)
      ..dispose();
    _passwordFocus
      ..removeListener(_onFocusChange)
      ..dispose();

    emailCtrl.dispose();
    phoneCtrl.dispose();
    pwCtrl.dispose();
    fullNameCtrl.dispose();

    super.dispose();
  }

  // ─── Toast ───────────────────────────────────────────────────────────────────

  void _showToastMessage(String message, bool isSuccess) {
    if (!mounted) return;
    setState(() {
      _toastMessage   = message;
      _isToastSuccess = isSuccess;
      _showToast      = true;
    });
    _toastController.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _hideToast();
    });
  }

  void _hideToast() {
    if (!mounted) return;
    _toastController.reverse().then((_) {
      if (mounted) setState(() => _showToast = false);
    });
  }

  // ─── Login ───────────────────────────────────────────────────────────────────

  Future<void> _login() async {
    if (loading) return;
    HapticFeedback.lightImpact();
    await _buttonController.forward();
    await _buttonController.reverse();

    final identifier = isPhoneMode
        ? '$selectedCountryCode${phoneCtrl.text.trim()}'
        : emailCtrl.text.trim();

    if (identifier.isEmpty || pwCtrl.text.isEmpty) {
      _showToastMessage('Please enter your credentials', false);
      return;
    }

    setState(() => loading = true);

    try {
      final resp = await _authService.login(identifier, pwCtrl.text);
      final data = (resp['data'] is Map)
          ? Map<String, dynamic>.from(resp['data'] as Map)
          : <String, dynamic>{};
      await _handleAuthSuccess(data);
    } on AuthException catch (e) {
      _showToastMessage(e.message, false);
    } on SocketException {
      _showToastMessage('No internet connection', false);
    } catch (e) {
      String msg = 'Login failed. Please try again.';
      final err  = e.toString();
      if (err.contains('timeout'))         msg = 'Request timeout. Check your connection.';
      else if (err.contains('NO_ACCESS_TOKEN') || err.contains('No access token'))
        msg = 'Server error. Please try again.';
      else if (err.contains('FormatException')) msg = 'Invalid response from server.';
      _showToastMessage(msg, false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ─── Google Auth ─────────────────────────────────────────────────────────────

  Future<void> _loginWithGoogle() async {
    if (loading) return;
    HapticFeedback.lightImpact();
    setState(() => loading = true);

    try {
      final resp = await GoogleAuthService.instance.loginWithGoogle();
      if (!resp.success || resp.data == null) {
        _showToastMessage(resp.message ?? 'Google login failed.', false);
        return;
      }
      await _handleAuthSuccess(resp.data!);
    } on SocketException {
      _showToastMessage('No internet connection', false);
    } catch (e) {
      debugPrint('❌ [GOOGLE LOGIN] $e');
      _showToastMessage('Google login failed. Please try again.', false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _registerPassengerWithGoogle() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      final resp = await GoogleAuthService.instance.registerPassengerWithGoogle();
      if (!resp.success || resp.data == null) {
        _showToastMessage(resp.message ?? 'Google passenger registration failed.', false);
        return;
      }
      await _handleAuthSuccess(resp.data!);
    } on SocketException {
      _showToastMessage('No internet connection', false);
    } catch (e) {
      debugPrint('❌ [GOOGLE PASSENGER REGISTER] $e');
      _showToastMessage('Google registration failed. Please try again.', false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _startDriverSignupWithGoogle() async {
    if (loading) return;
    setState(() => loading = true);

    try {
      // Two-step driver onboarding (the backend's clean path): create the DRIVER
      // account with Google now and sign in. The driver then completes their
      // vehicle + documents in-app (authenticated: POST /api/profile/driver/...)
      // and waits for admin approval before they can go online. This avoids the
      // password/OTP signup flow, which doesn't apply to Google accounts.
      final resp = await GoogleAuthService.instance.registerDriverWithGoogle();
      if (!resp.success || resp.data == null) {
        _showToastMessage(resp.message ?? 'Google driver sign-up failed.', false);
        return;
      }
      await _handleAuthSuccess(resp.data!);
    } on SocketException {
      _showToastMessage('No internet connection', false);
    } catch (e) {
      debugPrint('❌ [GOOGLE DRIVER START] $e');
      _showToastMessage('Google sign-up failed. Please try again.', false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ─── Auth Success ─────────────────────────────────────────────────────────────

  Future<void> _handleAuthSuccess(Map<String, dynamic> data) async {
    final user = (data['user'] is Map)
        ? Map<String, dynamic>.from(data['user'] as Map)
        : <String, dynamic>{};

    final accessToken = data['access_token']?.toString() ?? '';
    final userId      = user['uuid']?.toString() ?? '';
    final userType    = user['user_type']?.toString().trim() ?? '';

    if (accessToken.isEmpty) {
      throw AuthException(
        message:    'No access token received from server',
        statusCode: 500,
        errorCode:  'NO_ACCESS_TOKEN',
      );
    }
    if (userId.isEmpty || userType.isEmpty) {
      throw AuthException(
        message:    'Invalid user data received from server',
        statusCode: 500,
        errorCode:  'INVALID_USER_DATA',
      );
    }

    await _authService.saveSessionFromAuthData(data);

    NotificationService.instance.registerTokenOnLogin().catchError(
          (e) => debugPrint('⚠️ [LOGIN] FCM token registration failed: $e'),
    );

    final activeMode   = user['active_mode']?.toString();
    final resolvedMode = (activeMode != null && activeMode.isNotEmpty)
        ? activeMode
        : ModeService.modeFromUserType(userType);

    await ModeService.saveActiveMode(resolvedMode, userType);

    // Connect realtime in the BACKGROUND — never gate navigation on the socket
    // handshake. The home screens attach their listeners once it's up.
    SocketHelper.connect(
      accessToken:  accessToken,
      userId:       userId,
      userType:     userType,
      onTokenExpired: () async {
        final refreshed = await _authService.refreshAccessToken();
        if (refreshed) return await _authService.getAccessToken();
        return null;
      },
    ).then((_) => ServiceSocketListener.instance.connect())
     .catchError((e) =>
        debugPrint('⚠️ [LOGIN] Socket failed after auth, continuing anyway: $e'));

    final route      = ModeService.routeForMode(resolvedMode);
    final firstName  = user['first_name']?.toString();
    final welcomeName = (firstName != null && firstName.isNotEmpty) ? firstName : 'User';

    _showToastMessage('Welcome back, $welcomeName! 👋', true);
    // Brief flash of the welcome toast, then straight to home (was 900ms).
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  // ─── UI Actions ───────────────────────────────────────────────────────────────

  void _togglePhoneMode() => setState(() => isPhoneMode = !isPhoneMode);

  void _toggleSignupExpanded() {
    setState(() => _signupExpanded = !_signupExpanded);
    if (_signupExpanded) {
      _signupExpandController.forward();
    } else {
      _signupExpandController.reverse();
    }
    HapticFeedback.selectionClick();
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context:             context,
      backgroundColor:     Colors.transparent,
      isScrollControlled:  true,
      builder: (_) => _CountryPickerSheet(
        countries:    countries,
        selectedCode: selectedCountryCode,
        onSelected:   (code, flag) => setState(() {
          selectedCountryCode = code;
          selectedCountryFlag = flag;
        }),
      ),
    );
  }

  void _navigateToPassengerSignup() => Navigator.pushNamed(context, '/signup/passenger');
  void _navigateToDriverSignup()    => Navigator.pushNamed(context, '/signup/driver');

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _heroFade,
                    child: SlideTransition(
                      position: _heroSlide,
                      child: _buildHero(),
                    ),
                  ),
                  FadeTransition(
                    opacity: _formFade,
                    child: SlideTransition(
                      position: _formSlide,
                      child: _buildFormArea(),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          if (_showToast) _buildToast(),
        ],
      ),
    );
  }

  // ─── Hero Panel ──────────────────────────────────────────────────────────────

  Widget _buildHero() {
    return SizedBox(
      height: 256,
      child: Stack(
        children: [
          // Dark base with a subtle depth gradient.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryDark,
                    Color.lerp(AppColors.primaryDark, Colors.black, 0.45)!,
                  ],
                ),
              ),
            ),
          ),

          // Animated ride-hailing scene (grid, route, beacon, particles).
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([_ambientController, _beaconController]),
              builder: (_, __) => CustomPaint(
                painter: _HeroScenePainter(
                  ambient: _ambientController.value,
                  pulse: _beaconController.value,
                ),
              ),
            ),
          ),

          // Left scrim keeps the welcome text crisp over the animated grid.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      AppColors.primaryDark.withOpacity(0.92),
                      AppColors.primaryDark.withOpacity(0.0),
                    ],
                    stops: const [0.0, 0.58],
                  ),
                ),
              ),
            ),
          ),

          // Wave cut-out at the bottom (with gold seam).
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: SizedBox(
              height: 56,
              child: CustomPaint(
                painter: _WavePainter(waveColor: const Color(0xFFF5F4F0)),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 52, 28, 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Logo (gentle float) ──
                AnimatedBuilder(
                  animation: _ambientController,
                  builder: (_, child) {
                    final f = math.sin(_ambientController.value * 2 * math.pi);
                    return Transform.translate(
                      offset: Offset(0, f * 2.5),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Text(
                      AppConfig.appName.isNotEmpty ? AppConfig.appName[0] : 'W',
                      style: TextStyle(
                        fontFamily: AppTypography.primaryFont,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGold,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // ── Welcome text ──
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFont,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -1.0,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                // ── Slogan with a small gold accent dash ──
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 2,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Your ride, your way',
                      style: TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.55),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Area ────────────────────────────────────────────────────────────────

  Widget _buildFormArea() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          _buildModePill(),
          const SizedBox(height: 20),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: isPhoneMode
                ? _buildPhoneField()
                : _buildEmailField(),
          ),

          const SizedBox(height: 14),

          _buildLabel('Password'),
          const SizedBox(height: 8),
          _buildPasswordField(),

          const SizedBox(height: 14),
          _buildRememberAndForgot(),

          const SizedBox(height: 26),

          _buildSignInButton(),
          const SizedBox(height: 18),

          _buildDivider(),
          const SizedBox(height: 18),

          _buildGoogleButton(),
          const SizedBox(height: 12),

          _buildSignupStrip(),
        ],
      ),
    );
  }

  // ─── Mode Pill ────────────────────────────────────────────────────────────────

  Widget _buildModePill() {
    return GestureDetector(
      onTap: _togglePhoneMode,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFEDECEA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPhoneMode ? Icons.email_outlined : Icons.phone_outlined,
              size: 15,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              isPhoneMode ? 'Use email instead' : 'Use phone instead',
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Shared Input Decoration ──────────────────────────────────────────────────

  BoxDecoration _inputDecoration(bool isFocused) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: isFocused ? AppColors.primaryGold : const Color(0xFFE8E6E0),
      width: isFocused ? 1.8 : 1.0,
    ),
    boxShadow: isFocused
        ? [BoxShadow(color: AppColors.primaryGold.withOpacity(0.10), blurRadius: 10, offset: const Offset(0, 3))]
        : [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 6, offset: const Offset(0, 2))],
  );

  TextStyle get _inputTextStyle => const TextStyle(
    fontFamily: AppTypography.secondaryFont,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  TextStyle get _hintStyle => TextStyle(
    fontFamily: AppTypography.secondaryFont,
    fontSize: 15,
    color: AppColors.textLight,
  );

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: AppTypography.secondaryFont,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: AppColors.textSecondary,
      ),
    ),
  );

  // ─── Email Field ──────────────────────────────────────────────────────────────

  Widget _buildEmailField() {
    final focused = _emailFocus.hasFocus;
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Email Address'),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: _inputDecoration(focused),
          child: TextField(
            controller: emailCtrl,
            focusNode: _emailFocus,
            keyboardType: TextInputType.emailAddress,
            style: _inputTextStyle,
            decoration: InputDecoration(
              hintText: 'example@email.com',
              hintStyle: _hintStyle,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(Icons.email_outlined, size: 19,
                    color: focused ? AppColors.primaryGold : AppColors.textSecondary),
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Phone Field ──────────────────────────────────────────────────────────────

  Widget _buildPhoneField() {
    final focused = _phoneFocus.hasFocus;
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Phone Number'),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: _inputDecoration(focused),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showCountryPicker,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedCountryFlag, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 5),
                      Text(
                        selectedCountryCode,
                        style: const TextStyle(
                          fontFamily: AppTypography.secondaryFont,
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 26, color: const Color(0xFFE8E6E0)),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: _inputTextStyle,
                  decoration: InputDecoration(
                    hintText: '6 77 77 77 77',
                    hintStyle: _hintStyle,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Password Field ───────────────────────────────────────────────────────────

  Widget _buildPasswordField() {
    final focused = _passwordFocus.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _inputDecoration(focused),
      child: TextField(
        controller: pwCtrl,
        focusNode: _passwordFocus,
        obscureText: _obscurePassword,
        style: _inputTextStyle,
        decoration: InputDecoration(
          hintText: 'Enter your password',
          hintStyle: _hintStyle,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(Icons.lock_outline_rounded, size: 19,
                color: focused ? AppColors.primaryGold : AppColors.textSecondary),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 19, color: AppColors.textSecondary,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            padding: const EdgeInsets.only(right: 14),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ─── Remember & Forgot ────────────────────────────────────────────────────────

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => rememberMe = !rememberMe);
          },
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 19, height: 19,
                decoration: BoxDecoration(
                  color: rememberMe ? AppColors.primaryDark : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: rememberMe ? AppColors.primaryDark : AppColors.borderMedium,
                    width: 1.5,
                  ),
                ),
                child: rememberMe
                    ? const Icon(Icons.check_rounded, color: AppColors.primaryGold, size: 12)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Remember me',
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 12, color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/forgot-password'),
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 12, fontWeight: FontWeight.w600,
              color: AppColors.primaryGold,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Sign In Button ───────────────────────────────────────────────────────────

  Widget _buildSignInButton() {
    return ScaleTransition(
      scale: _buttonScale,
      child: GestureDetector(
        onTap: loading ? null : _login,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 54,
          width: double.infinity,
          decoration: BoxDecoration(
            color: loading ? AppColors.primaryGold.withOpacity(0.6) : AppColors.primaryGold,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGold.withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: loading
                ? SizedBox(
              width: 22, height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Sign In',
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFont,
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 17, color: AppColors.primaryDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Divider ──────────────────────────────────────────────────────────────────

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: const Color(0xFFE0DED8))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 11, fontWeight: FontWeight.w600,
              color: AppColors.textSecondary, letterSpacing: 1,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: const Color(0xFFE0DED8))),
      ],
    );
  }

  // ─── Google Button ────────────────────────────────────────────────────────────

  Widget _buildGoogleButton() {
    return _OutlinedActionButton(
      onTap: _loginWithGoogle,
      customIcon: const _GoogleIcon(),
      label: 'Continue with Google',
    );
  }

  // ─── Signup Strip (expandable) ────────────────────────────────────────────────

  Widget _buildSignupStrip() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E6E0), width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleSignupExpanded,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDECEA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.person_add_outlined, size: 17, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        text: 'New here? ',
                        style: TextStyle(
                          fontFamily: AppTypography.secondaryFont,
                          fontSize: 13, color: AppColors.textSecondary,
                        ),
                        children: [
                          const TextSpan(
                            text: 'Create an account',
                            style: TextStyle(
                              fontFamily: AppTypography.secondaryFont,
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: AppColors.primaryGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _signupExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeInOutCubic,
                    child: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),

          SizeTransition(
            sizeFactor: _signupHeight,
            axisAlignment: -1,
            child: Column(
              children: [
                const Divider(height: 1, color: Color(0xFFF0EEE8)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    children: [
                      _buildRoleOption(
                        icon: Icons.person_outline_rounded,
                        title: 'Passenger',
                        subtitle: 'Book rides and travel comfortably',
                        accentColor: AppColors.primaryGold,
                        onTap: _navigateToPassengerSignup,
                      ),
                      const SizedBox(height: 10),
                      _buildRoleOption(
                        icon: Icons.local_taxi_outlined,
                        title: 'Driver',
                        subtitle: 'Drive, deliver and earn money',
                        accentColor: AppColors.primaryDark,
                        onTap: _navigateToDriverSignup,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return _SignupOption(
      icon: icon,
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
      onTap: onTap,
    );
  }

  // ─── Toast ────────────────────────────────────────────────────────────────────

  Widget _buildToast() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _toastSlide,
          child: FadeTransition(
            opacity: _toastOpacity,
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: _isToastSuccess ? const Color(0xFF1A1A1A) : const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 18, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isToastSuccess ? Icons.check_rounded : Icons.error_outline_rounded,
                      color: _isToastSuccess ? AppColors.primaryGold : Colors.white,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _toastMessage,
                      style: const TextStyle(
                        fontFamily: AppTypography.secondaryFont,
                        fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _hideToast,
                    child: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.6), size: 17),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════

class _OutlinedActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final IconData?  icon;
  final Widget?    customIcon;
  final String     label;

  const _OutlinedActionButton({
    required this.onTap,
    this.icon,
    this.customIcon,
    required this.label,
  });

  @override
  State<_OutlinedActionButton> createState() => _OutlinedActionButtonState();
}

class _OutlinedActionButtonState extends State<_OutlinedActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 50,
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF0EEE8) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0DED8), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.customIcon != null) widget.customIcon!
            else if (widget.icon != null) Icon(widget.icon, size: 19, color: AppColors.textPrimary),
            const SizedBox(width: 10),
            Text(
              widget.label,
              style: const TextStyle(
                fontFamily: AppTypography.primaryFont,
                fontSize: 14, fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIGNUP OPTION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SignupOption extends StatefulWidget {
  final IconData  icon;
  final String    title;
  final String    subtitle;
  final Color     accentColor;
  final VoidCallback onTap;

  const _SignupOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_SignupOption> createState() => _SignupOptionState();
}

class _SignupOptionState extends State<_SignupOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:  (_) => setState(() => _pressed = true),
      onTapUp:    (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        transform: Matrix4.identity()..scale(_pressed ? 0.97 : 1.0),
        transformAlignment: Alignment.center,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _pressed ? const Color(0xFFF7F5F0) : const Color(0xFFFAF9F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E6E0), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(widget.icon, color: widget.accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title,
                    style: const TextStyle(
                      fontFamily: AppTypography.primaryFont,
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(widget.subtitle,
                    style: TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 12, color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: widget.accentColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: widget.accentColor),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// COUNTRY PICKER SHEET
// ═══════════════════════════════════════════════════════════════════════════════

class _CountryPickerSheet extends StatelessWidget {
  final List<Map<String, String>> countries;
  final String selectedCode;
  final void Function(String code, String flag) onSelected;

  const _CountryPickerSheet({
    required this.countries,
    required this.selectedCode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                const Text(
                  'Select Country',
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFont,
                    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryDark,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.close_rounded, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 320,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: countries.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (_, i) {
                final c          = countries[i];
                final isSelected = selectedCode == c['code'];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                  leading: Text(c['flag']!, style: const TextStyle(fontSize: 26)),
                  title: Text(
                    c['name']!,
                    style: TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                    ),
                  ),
                  trailing: Text(
                    c['code']!,
                    style: TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                    ),
                  ),
                  onTap: () {
                    onSelected(c['code']!, c['flag']!);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}