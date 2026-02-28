// lib/screens/login/login_screen.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ Import utilities and config
import '../../authentication service/api_services.dart';
import '../../core/config.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';


// ✅ Import main for socket helper
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════════
  // CONTROLLERS & STATE
  // ═══════════════════════════════════════════════════════════════
  final _authService = AuthService();
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final pwCtrl = TextEditingController();

  bool loading = false;
  bool rememberMe = false;
  bool isPhoneMode = false;
  bool _obscurePassword = true;
  String selectedCountryCode = '+237';
  String selectedCountryFlag = '🇨🇲';

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _toastController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _toastSlideAnimation;
  late Animation<double> _toastOpacityAnimation;

  // Toast state
  bool _showToast = false;
  bool _isToastSuccess = false;
  String _toastMessage = '';

  // Country codes
  final List<Map<String, String>> countries = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroon'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
    {'code': '+254', 'flag': '🇰🇪', 'name': 'Kenya'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _toastController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _toastSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _toastController, curve: Curves.easeOut));

    _toastOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _toastController, curve: Curves.easeOut),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _toastController.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    pwCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // TOAST METHODS
  // ═══════════════════════════════════════════════════════════════
  void _showToastMessage(String message, bool isSuccess) {
    if (!mounted) return;

    setState(() {
      _toastMessage = message;
      _isToastSuccess = isSuccess;
      _showToast = true;
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

  void _toggleMode() {
    setState(() => isPhoneMode = !isPhoneMode);
  }

  // ═══════════════════════════════════════════════════════════════
  // LOGIN METHOD
  // ═══════════════════════════════════════════════════════════════
  Future<void> _login() async {
    if (loading) return;

    // ✅ Build identifier - automatically concatenate country code for phone
    final identifier = isPhoneMode
        ? '$selectedCountryCode${phoneCtrl.text.trim()}'
        : emailCtrl.text.trim();

    if (identifier.isEmpty || pwCtrl.text.isEmpty) {
      _showToastMessage('Please enter your credentials', false);
      return;
    }

    setState(() => loading = true);

    try {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔐 [LOGIN SCREEN] Starting login...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📧 Identifier: $identifier');
      debugPrint('🔑 Login Mode: ${isPhoneMode ? "PHONE" : "EMAIL"}');
      debugPrint('🌐 API URL: ${AppConfig.apiBaseUrl}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // ═══════════════════════════════════════════════════════════
      // CALL AUTH SERVICE
      // ═══════════════════════════════════════════════════════════
      final resp = await _authService.login(identifier, pwCtrl.text);

      debugPrint('✅ [LOGIN SCREEN] Response received from backend');

      // ═══════════════════════════════════════════════════════════
      // EXTRACT DATA FROM RESPONSE
      // ═══════════════════════════════════════════════════════════
      final data = (resp['data'] ?? {}) as Map;
      final String? accessToken = data['access_token'] as String?;
      final String? refreshToken = data['refresh_token'] as String?;
      final Map<String, dynamic> user =
      (data['user'] is Map) ? Map<String, dynamic>.from(data['user']) : {};

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception('No access token received from server');
      }

      debugPrint('🎫 [LOGIN SCREEN] Tokens received successfully');
      debugPrint('   Access Token: ${accessToken.substring(0, 20)}...');
      if (refreshToken != null) {
        debugPrint('   Refresh Token: ${refreshToken.substring(0, 20)}...');
      }

      // ═══════════════════════════════════════════════════════════
      // SAVE TO SHARED PREFERENCES
      // ═══════════════════════════════════════════════════════════
      debugPrint('\n💾 [LOGIN SCREEN] Saving data to SharedPreferences...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final prefs = await SharedPreferences.getInstance();

      // ─────────────────────────────────────────────────────────────
      // SAVE TOKENS
      // ─────────────────────────────────────────────────────────────
      await prefs.setString('access_token', accessToken);
      debugPrint('✅ [SAVE] Access token saved');

      if (refreshToken != null && refreshToken.isNotEmpty) {
        await prefs.setString('refresh_token', refreshToken);
        debugPrint('✅ [SAVE] Refresh token saved');
      }

      // ─────────────────────────────────────────────────────────────
      // SAVE COMPLETE USER DATA AS JSON
      // ─────────────────────────────────────────────────────────────
      final userJson = jsonEncode(user);
      await prefs.setString('user_data', userJson);
      debugPrint('✅ [SAVE] Complete user data saved as JSON');
      debugPrint('   User Data Size: ${userJson.length} characters');

      // ─────────────────────────────────────────────────────────────
      // SAVE INDIVIDUAL FIELDS FOR QUICK ACCESS
      // ─────────────────────────────────────────────────────────────
      await prefs.setString('user_uuid', user['uuid'] ?? '');
      await prefs.setString('user_type', user['user_type'] ?? '');
      await prefs.setString('user_email', user['email'] ?? '');
      await prefs.setString('user_phone', user['phone_e164'] ?? '');
      await prefs.setString('first_name', user['first_name'] ?? '');
      await prefs.setString('last_name', user['last_name'] ?? '');
      await prefs.setString('civility', user['civility'] ?? '');
      await prefs.setString('birth_date', user['birth_date'] ?? '');

      // Save avatar URL
      if (user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty) {
        await prefs.setString('avatar_url', user['avatar_url']);
        debugPrint('✅ [SAVE] Avatar URL: ${user['avatar_url']}');
      }

      // Save verification status
      await prefs.setBool('email_verified', user['email_verified'] ?? false);
      await prefs.setBool('phone_verified', user['phone_verified'] ?? false);
      await prefs.setString('status', user['status'] ?? '');

      debugPrint('✅ [SAVE] Individual fields saved');

      // ─────────────────────────────────────────────────────────────
      // SAVE PROFILE DATA (PASSENGER OR DRIVER)
      // ─────────────────────────────────────────────────────────────
      if (user['profile'] != null && user['profile'] is Map) {
        final profile = user['profile'] as Map<String, dynamic>;
        final profileJson = jsonEncode(profile);
        await prefs.setString('profile_data', profileJson);
        debugPrint('✅ [SAVE] Profile data saved');
        debugPrint('   Profile Data Size: ${profileJson.length} characters');

        // ─────────────────────────────────────────────────────────
        // SAVE DRIVER-SPECIFIC DATA
        // ─────────────────────────────────────────────────────────
        if (user['user_type'] == 'DRIVER') {
          debugPrint('\n🚗 [SAVE] Saving driver-specific data...');

          // Identity documents
          await prefs.setString('cni_number', profile['cni_number'] ?? '');
          await prefs.setString('license_number', profile['license_number'] ?? '');
          await prefs.setString('license_expiry', profile['license_expiry'] ?? '');
          await prefs.setString('insurance_number', profile['insurance_number'] ?? '');
          await prefs.setString('insurance_expiry', profile['insurance_expiry'] ?? '');

          // Document URLs
          if (profile['license_document_url'] != null) {
            await prefs.setString('license_document_url', profile['license_document_url']);
            debugPrint('   ✅ License Document: ${profile['license_document_url']}');
          }
          if (profile['insurance_document_url'] != null) {
            await prefs.setString('insurance_document_url', profile['insurance_document_url']);
            debugPrint('   ✅ Insurance Document: ${profile['insurance_document_url']}');
          }

          // Vehicle information
          await prefs.setString('vehicle_type', profile['vehicle_type'] ?? '');
          await prefs.setString('vehicle_make_model', profile['vehicle_make_model'] ?? '');
          await prefs.setString('vehicle_color', profile['vehicle_color'] ?? '');
          await prefs.setString('vehicle_year', profile['vehicle_year']?.toString() ?? '');
          await prefs.setString('vehicle_plate', profile['vehicle_plate'] ?? '');

          // Vehicle photo
          if (profile['vehicle_photo_url'] != null) {
            await prefs.setString('vehicle_photo_url', profile['vehicle_photo_url']);
            debugPrint('   ✅ Vehicle Photo: ${profile['vehicle_photo_url']}');
          }

          // Driver status
          await prefs.setString('verification_state', profile['verification_state'] ?? '');
          await prefs.setBool('is_online', profile['is_online'] ?? false);
          await prefs.setBool('is_available', profile['is_available'] ?? false);

          debugPrint('✅ [SAVE] Driver profile saved');
        }

        // ─────────────────────────────────────────────────────────
        // SAVE PASSENGER-SPECIFIC DATA
        // ─────────────────────────────────────────────────────────
        if (user['user_type'] == 'PASSENGER') {
          debugPrint('\n👤 [SAVE] Saving passenger-specific data...');

          await prefs.setString('address_text', profile['address_text'] ?? '');
          await prefs.setString('notes', profile['notes'] ?? '');

          debugPrint('✅ [SAVE] Passenger profile saved');
        }
      }

      // ═══════════════════════════════════════════════════════════
      // PRINT SUMMARY
      // ═══════════════════════════════════════════════════════════
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📦 [SAVE] Data Summary:');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ Access Token: Saved');
      debugPrint('✅ Refresh Token: ${refreshToken != null ? "Saved" : "N/A"}');
      debugPrint('✅ Complete User Data: Saved');
      debugPrint('');
      debugPrint('👤 User Information:');
      debugPrint('   • UUID: ${user['uuid']}');
      debugPrint('   • Type: ${user['user_type']}');
      debugPrint('   • Name: ${user['first_name']} ${user['last_name']}');
      debugPrint('   • Email: ${user['email'] ?? "N/A"}');
      debugPrint('   • Phone: ${user['phone_e164'] ?? "N/A"}');
      debugPrint('   • Status: ${user['status']}');
      debugPrint('   • Email Verified: ${user['email_verified']}');
      debugPrint('   • Phone Verified: ${user['phone_verified']}');

      if (user['avatar_url'] != null) {
        debugPrint('   • Avatar: ✓ ${user['avatar_url']}');
      }

      if (user['profile'] != null) {
        final profile = user['profile'] as Map<String, dynamic>;
        debugPrint('');
        debugPrint('📋 Profile Information:');

        if (user['user_type'] == 'DRIVER') {
          debugPrint('   🚗 Driver Profile:');
          debugPrint('      • License: ${profile['license_number']}');
          debugPrint('      • Vehicle: ${profile['vehicle_make_model'] ?? "N/A"}');
          debugPrint('      • Plate: ${profile['vehicle_plate'] ?? "N/A"}');
          debugPrint('      • License Doc: ${profile['license_document_url'] != null ? "✓" : "✗"}');
          debugPrint('      • Vehicle Photo: ${profile['vehicle_photo_url'] != null ? "✓" : "✗"}');
          debugPrint('      • Verification: ${profile['verification_state']}');
        } else if (user['user_type'] == 'PASSENGER') {
          debugPrint('   👤 Passenger Profile:');
          debugPrint('      • Address: ${profile['address_text'] ?? "N/A"}');
        }
      }

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // ═══════════════════════════════════════════════════════════
      // CONNECT TO SOCKET
      // ═══════════════════════════════════════════════════════════
      final String userId = user['uuid'] ?? '';
      final String userType = user['user_type'] ?? '';

      if (userId.isNotEmpty && userType.isNotEmpty) {
        debugPrint('🔌 [LOGIN SCREEN] Connecting to Socket.IO...');
        try {
          await SocketHelper.connect(
            accessToken: accessToken,
            userId: userId,
            userType: userType,
            onTokenExpired: () async {
              debugPrint('🔄 [SOCKET] Token expired, refreshing...');
              final refreshed = await _authService.refreshAccessToken();
              if (refreshed) {
                final prefs = await SharedPreferences.getInstance();
                return prefs.getString('access_token');
              }
              return null;
            },
          );
          debugPrint('✅ [LOGIN SCREEN] Socket connected successfully');
        } catch (e) {
          debugPrint('⚠️  [LOGIN SCREEN] Socket connection failed: $e');
          debugPrint('   Note: Login will proceed without real-time features');
        }
      }

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('✅ [LOGIN COMPLETE] All data saved successfully!');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      // ═══════════════════════════════════════════════════════════
      // SHOW SUCCESS MESSAGE
      // ═══════════════════════════════════════════════════════════
      final firstName = user['first_name'] ?? 'User';
      _showToastMessage('Welcome back, $firstName!', true);

      await Future.delayed(const Duration(milliseconds: 800));

      if (!mounted) return;

      // ═══════════════════════════════════════════════════════════
      // NAVIGATE BASED ON USER TYPE
      // ═══════════════════════════════════════════════════════════
      final String userTypeUpper = userType.toUpperCase();

      debugPrint('🚀 [LOGIN SCREEN] Navigating to $userTypeUpper dashboard...\n');

      if (userTypeUpper == 'PASSENGER') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard/passenger',
              (route) => false,
        );
      } else if (userTypeUpper == 'DRIVER') {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/dashboard/driver',
              (route) => false,
        );
      } else {
        _showToastMessage('Unknown user type: $userTypeUpper', false);
        debugPrint('❌ [LOGIN SCREEN] Unknown user type: $userTypeUpper');
      }
    } on AuthException catch (e) {
      // ✅ Handle custom API exceptions from AuthService
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ [LOGIN SCREEN] AuthException caught');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Message: ${e.message}');
      debugPrint('Status Code: ${e.statusCode}');
      debugPrint('Error Code: ${e.errorCode}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      _showToastMessage(e.message, false);
    } on SocketException {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ [LOGIN SCREEN] Network error - No internet');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
      _showToastMessage('No internet connection', false);
    } catch (e) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ [LOGIN SCREEN] Unexpected error');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Error: $e');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      String errorMessage = 'Login failed. Please try again.';

      if (e.toString().contains('timeout')) {
        errorMessage = 'Request timeout. Check your connection.';
      } else if (e.toString().contains('No access token')) {
        errorMessage = 'Server error. Please try again.';
      } else if (e.toString().contains('FormatException')) {
        errorMessage = 'Invalid response from server.';
      }

      _showToastMessage(errorMessage, false);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    _showToastMessage('Google Sign-In coming soon!', false);
    // TODO: Implement Google OAuth
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.secondaryLightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Text(
                  'Select Country',
                  style: AppTypography.headlineMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final isSelected = selectedCountryCode == country['code'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    leading: Text(country['flag']!, style: const TextStyle(fontSize: 28)),
                    title: Text(
                      country['name']!,
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                    ),
                    trailing: Text(
                      country['code']!,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? AppColors.primaryGold : AppColors.textSecondary,
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        selectedCountryCode = country['code']!;
                        selectedCountryFlag = country['flag']!;
                      });
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildLogo(),
                      const SizedBox(height: 48),
                      _buildTitle(),
                      const SizedBox(height: 32),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.2, 0),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: isPhoneMode ? _buildPhoneField() : _buildEmailField(),
                      ),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      if (!isPhoneMode) ...[
                        const SizedBox(height: 16),
                        _buildRememberAndForgot(),
                      ],
                      const SizedBox(height: 32),
                      _buildLoginButton(),
                      const SizedBox(height: 24),
                      _buildDivider(),
                      const SizedBox(height: 24),
                      _buildToggleButton(),
                      const SizedBox(height: 16),
                      _buildGoogleLoginButton(),
                      const SizedBox(height: 32),
                      _buildSignUpLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_showToast) _buildToast(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowMedium,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/logo.png',
              width: 40,
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  'W',
                  style: AppTypography.displayMedium.copyWith(
                    color: AppColors.primaryGold,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppConfig.appName, style: AppTypography.displayMedium),
            Text(
              'Your ride, your way',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Welcome Back', style: AppTypography.displayLarge),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isPhoneMode
                ? 'Enter your phone number to continue'
                : 'Sign in to access your account',
            key: ValueKey(isPhoneMode),
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      key: const ValueKey('email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Email', style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [BoxShadow(color: AppColors.shadowLight, blurRadius: 8)],
          ),
          child: TextField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: AppTypography.inputText,
            decoration: InputDecoration(
              hintText: 'example@email.com',
              hintStyle: AppTypography.inputHint,
              prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      key: const ValueKey('phone'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Phone Number', style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [BoxShadow(color: AppColors.shadowLight, blurRadius: 8)],
          ),
          child: Row(
            children: [
              InkWell(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  child: Row(
                    children: [
                      Text(selectedCountryFlag, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 6),
                      Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              ),
              Container(width: 1, height: 24, color: AppColors.borderLight),
              Expanded(
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: AppTypography.inputText,
                  decoration: InputDecoration(
                    hintText: '6 77 77 77 77',
                    hintStyle: AppTypography.inputHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ✅ Show full phone number that will be sent
        if (phoneCtrl.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Full number: $selectedCountryCode${phoneCtrl.text}',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Password', style: AppTypography.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
            boxShadow: [BoxShadow(color: AppColors.shadowLight, blurRadius: 8)],
          ),
          child: TextField(
            controller: pwCtrl,
            obscureText: _obscurePassword,
            style: AppTypography.inputText,
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: AppTypography.inputHint,
              prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        InkWell(
          onTap: () => setState(() => rememberMe = !rememberMe),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: rememberMe ? AppColors.primaryDark : AppColors.backgroundWhite,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: rememberMe ? AppColors.primaryDark : AppColors.borderMedium,
                    width: 2,
                  ),
                ),
                child: rememberMe
                    ? Icon(Icons.check, color: AppColors.primaryGold, size: 14)
                    : null,
              ),
              const SizedBox(width: 10),
              Text('Remember me', style: AppTypography.bodySmall),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/forgot-password'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: Text(
              'Forgot Password?',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          disabledBackgroundColor: AppColors.buttonDisabled,
          foregroundColor: AppColors.backgroundWhite,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: loading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.backgroundWhite),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sign In', style: AppTypography.buttonLarge),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderLight)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('OR', style: AppTypography.caption),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderLight)),
      ],
    );
  }

  Widget _buildToggleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _toggleMode,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundWhite,
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.borderMedium, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPhoneMode ? Icons.email_outlined : Icons.phone_outlined,
              size: 20,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              isPhoneMode ? 'Continue with Email' : 'Continue with Phone',
              style: AppTypography.buttonMedium.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: _loginWithGoogle,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.backgroundWhite,
          side: BorderSide(color: AppColors.borderMedium, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.g_mobiledata, size: 28),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: AppTypography.buttonMedium.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Center(
      child: InkWell(
        onTap: () => _showSignupOptions(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: RichText(
            text: TextSpan(
              text: "Don't have an account? ",
              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              children: [
                TextSpan(
                  text: 'Sign Up',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.primaryGold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToast() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _toastSlideAnimation,
          child: FadeTransition(
            opacity: _toastOpacityAnimation,
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isToastSuccess ? AppColors.success : AppColors.error,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.shadowMedium, blurRadius: 10)],
              ),
              child: Row(
                children: [
                  Icon(
                    _isToastSuccess ? Icons.check_circle : Icons.error,
                    color: AppColors.backgroundWhite,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _toastMessage,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.backgroundWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _hideToast,
                    icon: Icon(Icons.close, color: AppColors.backgroundWhite, size: 20),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSignupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.secondaryLightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text('Choose Account Type', style: AppTypography.headlineMedium),
            const SizedBox(height: 24),
            _buildSignupOption(
              icon: Icons.person_outline,
              title: 'Passenger',
              subtitle: 'Book rides and travel',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/signup/passenger');
              },
            ),
            const SizedBox(height: 12),
            _buildSignupOption(
              icon: Icons.local_taxi_outlined,
              title: 'Driver',
              subtitle: 'Drive and earn money',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/signup/driver');
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSignupOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryDark, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMedium),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}
