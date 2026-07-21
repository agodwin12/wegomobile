// lib/screens/signup/passenger_sign_up/signup_passenger_screen.dart

import 'package:flutter/material.dart';
import '../../../l10n/tr.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../authentication service/api_services.dart';
import '../../../service/api_services.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

class SignupPassengerScreen extends StatefulWidget {
  const SignupPassengerScreen({super.key});

  @override
  State<SignupPassengerScreen> createState() => _SignupPassengerScreenState();
}

class _SignupPassengerScreenState extends State<SignupPassengerScreen>
    with TickerProviderStateMixin {
  int current = 0;

  // Step 1 inputs
  final emailCtrl       = TextEditingController();
  final phoneCtrl       = TextEditingController();
  final firstCtrl       = TextEditingController();
  final lastCtrl        = TextEditingController();
  final pwCtrl          = TextEditingController();
  final confirmPwCtrl   = TextEditingController();

  // Step 3 (OTP)
  final otpCtrl = TextEditingController();

  // ─── OTP state ────────────────────────────────────────────────
  // channel / purpose / identifier are set by the backend response.
  // Backend priority: SMS first, EMAIL fallback.
  // Flutter must mirror this — check phone first, email second.
  String  channel    = 'SMS';
  String  purpose    = 'PHONE_VERIFY';
  String? identifier;
  String? signupId;

  // Profile photo
  File?              _profileImage;
  final ImagePicker  _picker = ImagePicker();

  // Phone country picker
  String selectedCountryCode = '+237';
  String selectedCountryFlag = '🇨🇲';

  // Password visibility
  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;

  // Message / error display
  String? msg;

  // Loading state for step 2 submit
  bool _isLoading = false;

  // Animation controllers
  late AnimationController  _stepAnimationController;
  late Animation<double>    _fadeAnimation;
  late Animation<Offset>    _slideAnimation;

  // Country list
  final List<Map<String, String>> countries = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroon'},
    {'code': '+1',   'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44',  'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+33',  'flag': '🇫🇷', 'name': 'France'},
    {'code': '+49',  'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+39',  'flag': '🇮🇹', 'name': 'Italy'},
    {'code': '+34',  'flag': '🇪🇸', 'name': 'Spain'},
    {'code': '+31',  'flag': '🇳🇱', 'name': 'Netherlands'},
    {'code': '+91',  'flag': '🇮🇳', 'name': 'India'},
    {'code': '+86',  'flag': '🇨🇳', 'name': 'China'},
    {'code': '+81',  'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+27',  'flag': '🇿🇦', 'name': 'South Africa'},
  ];

  // ═══════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  @override
  void initState() {
    super.initState();
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _stepAnimationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _stepAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _stepAnimationController.forward();
  }

  @override
  void dispose() {
    _stepAnimationController.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    firstCtrl.dispose();
    lastCtrl.dispose();
    pwCtrl.dispose();
    confirmPwCtrl.dispose();
    otpCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════

  void _animateToNextStep() {
    _stepAnimationController.reset();
    setState(() => current += 1);
    _stepAnimationController.forward();
  }

  void _animateToPreviousStep() {
    _stepAnimationController.reset();
    setState(() => current -= 1);
    _stepAnimationController.forward();
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGE PICKER
  // ═══════════════════════════════════════════════════════════════

  Future<void> _pickProfileImage() async {
    try {
      setState(() => msg = null);

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image == null) return;

      final fileSize = await image.length();
      if (fileSize > 5 * 1024 * 1024) {
        setState(() => msg = 'Image is too large. Please select a smaller image.');
        return;
      }

      setState(() {
        _profileImage = File(image.path);
        msg = 'Profile photo selected successfully';
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && msg == 'Profile photo selected successfully') {
          setState(() => msg = null);
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        msg = (e.code == 'photo_access_denied' || e.code == 'camera_access_denied')
            ? 'Permission denied. Please enable photo access in settings.'
            : 'Error accessing photos: ${e.message ?? "Unknown error"}';
      });
    } catch (e) {
      setState(() => msg = 'Error selecting image. Please try again.');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1 — Personal info (no API call, just validation)
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitStep1() async {
    setState(() => msg = null);

    if (firstCtrl.text.trim().isEmpty) {
      setState(() => msg = 'First name is required');
      return;
    }
    if (lastCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Last name is required');
      return;
    }
    if (emailCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Email is required');
      return;
    }

    if (phoneCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Phone number is required');
      return;
    }
    if (emailCtrl.text.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(emailCtrl.text.trim())) {
        setState(() => msg = 'Please enter a valid email address');
        return;
      }
    }

    _animateToNextStep();
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2 — Password + API call to create pending signup
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitStep2() async {
    setState(() => msg = null);

    if (pwCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Password is required');
      return;
    }
    if (confirmPwCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Please confirm your password');
      return;
    }
    if (pwCtrl.text != confirmPwCtrl.text) {
      setState(() => msg = 'Passwords do not match');
      return;
    }
    if (pwCtrl.text.length < 8) {
      setState(() => msg = 'Password must be at least 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      msg = 'Creating your account...';
    });

    try {
      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final fullPhone = phone.isNotEmpty ? '$selectedCountryCode$phone' : '';

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🚖 [PASSENGER SIGNUP] Starting registration...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('📧 Email: ${email.isNotEmpty ? email : "N/A"}');
      debugPrint('📱 Phone: ${fullPhone.isNotEmpty ? fullPhone : "N/A"}');

      // Build payload
      final payload = <String, dynamic>{
        'first_name': firstCtrl.text.trim(),
        'last_name':  lastCtrl.text.trim(),
        'password':   pwCtrl.text,
      };
      if (email.isNotEmpty)     payload['email']      = email;
      if (fullPhone.isNotEmpty) payload['phone_e164'] = fullPhone;

      final resp = await ApiService.signupPassenger(
        payload,
        avatar: _profileImage,
      );

      debugPrint('📥 Response: success=${resp['success']} msg=${resp['message']}');

      if (resp['success'] == true) {
        final data       = resp['data'];
        final otpDelivery = data['otp_delivery'] as Map<String, dynamic>?;

        signupId = data['signup_id'];

        debugPrint('✅ Pending signup created — ID: $signupId');
        debugPrint('📨 OTP delivery: $otpDelivery');

        // ─────────────────────────────────────────────────────────
        // MIRROR BACKEND PRIORITY:
        //   Backend sends SMS first (if phone provided).
        //   Flutter must check phone first, email as fallback.
        //   This ensures identifier + channel match the OTP that
        //   was actually sent.
        // ─────────────────────────────────────────────────────────
        if (otpDelivery != null && otpDelivery['phone'] != null) {
          // Backend sent SMS OTP
          channel    = 'SMS';
          purpose    = 'PHONE_VERIFY';
          identifier = fullPhone;
          debugPrint('📱 [OTP] Will verify via SMS: $identifier');
        } else if (otpDelivery != null && otpDelivery['email'] != null) {
          // Backend sent EMAIL OTP (no phone was provided)
          channel    = 'EMAIL';
          purpose    = 'EMAIL_VERIFY';
          identifier = email;
          debugPrint('📧 [OTP] Will verify via EMAIL: $identifier');
        }

        setState(() => msg = 'Verification code sent! Please check your '
            '${channel == 'SMS' ? 'phone' : 'email'}.');

        await Future.delayed(const Duration(milliseconds: 500));
        _animateToNextStep();
      } else {
        String errorMessage = resp['message'] ?? 'Registration failed';
        final errorCode     = resp['code'];
        if (errorCode == 'EMAIL_ALREADY_EXISTS') {
          errorMessage = 'This email is already registered';
        } else if (errorCode == 'PHONE_ALREADY_EXISTS') {
          errorMessage = 'This phone number is already registered';
        }
        setState(() => msg = errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [PASSENGER SIGNUP] Error: $e');
      setState(() => msg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3 — OTP verification
  // ═══════════════════════════════════════════════════════════════

  Future<void> _verifyOtp() async {
    setState(() => msg = null);

    if (otpCtrl.text.trim().length != 6) {
      setState(() => msg = 'Please enter a valid 6-digit OTP code');
      return;
    }

    if (identifier == null || identifier!.isEmpty) {
      setState(() => msg = 'Something went wrong. Please go back and try again.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔐 [OTP] Verifying...');
      debugPrint('   Signup ID  : $signupId');
      debugPrint('   Identifier : $identifier');
      debugPrint('   Channel    : $channel');
      debugPrint('   Purpose    : $purpose');
      debugPrint('   Code       : ${otpCtrl.text}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final resp = await ApiService.verifyOtp(
        identifier: identifier!,
        purpose:    purpose,
        code:       otpCtrl.text.trim(),
      );

      debugPrint('📥 OTP response: success=${resp['success']}');

      if (resp['success'] == true) {
        setState(() => msg = 'Account created successfully! You can now login.');

        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      } else {
        String errorMessage = resp['message'] ?? 'Invalid OTP code';
        final errorCode     = resp['code'];
        if (errorCode == 'OTP_EXPIRED') {
          errorMessage = 'OTP code has expired. Please request a new one.';
        } else if (errorCode == 'TOO_MANY_ATTEMPTS') {
          errorMessage = 'Too many failed attempts. Please request a new code.';
        } else if (errorCode == 'SIGNUP_EXPIRED') {
          errorMessage = 'Signup session expired. Please start registration again.';
        } else if (errorCode == 'INVALID_OTP') {
          errorMessage = 'Invalid OTP code. Please try again.';
        }
        setState(() => msg = errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [OTP] Exception: $e');
      setState(() => msg = e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // RESEND OTP
  // ═══════════════════════════════════════════════════════════════

  Future<void> _resendOtp() async {
    setState(() => msg = null);

    if (identifier == null || identifier!.isEmpty) {
      setState(() => msg = 'Cannot resend — no identifier found.');
      return;
    }

    try {
      debugPrint('🔄 [OTP] Resending to $identifier via $channel...');

      await ApiService.sendOtp(
        identifier: identifier!,
        channel:    channel,
        purpose:    purpose,
      );

      setState(() => msg = 'Verification code resent successfully');
      debugPrint('✅ [OTP] Resent successfully');
    } catch (e) {
      debugPrint('❌ [OTP] Resend failed: $e');
      setState(() => msg = e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // COUNTRY PICKER
  // ═══════════════════════════════════════════════════════════════

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.65,
        padding: const EdgeInsets.all(24),
        child: Column(
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
                Text(tr('auth.selectCountry'), style: AppTypography.headlineSmall),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.close,
                        color: AppColors.textSecondary, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country    = countries[index];
                  final isSelected = selectedCountryCode == country['code'];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGold.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryGold
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Text(country['flag']!,
                          style: const TextStyle(fontSize: 28)),
                      title: Text(
                        country['name']!,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      trailing: Text(
                        country['code']!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          selectedCountryCode = country['code']!;
                          selectedCountryFlag = country['flag']!;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressIndicator(),
            Expanded(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildCurrentStep(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (current > 0) {
                _animateToPreviousStep();
              } else {
                Navigator.pop(context);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadowLight,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.arrow_back_ios_new,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
          Expanded(
            child: Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: AppTypography.headlineSmall,
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Row(
        children: [
          _buildStepCircle(0, '1'),
          _buildProgressLine(0),
          _buildStepCircle(1, '2'),
          _buildProgressLine(1),
          _buildStepCircle(2, '3'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive    = current == step;
    final isCompleted = current > step;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        gradient: isCompleted || isActive ? AppColors.primaryGradient : null,
        color: isCompleted || isActive ? null : AppColors.secondaryLightGrey,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? Icon(Icons.check, color: AppColors.textPrimary, size: 18)
            : Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: isActive
                ? AppColors.textPrimary
                : AppColors.textLight,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressLine(int step) {
    final isCompleted = current > step;
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          gradient: isCompleted ? AppColors.primaryGradient : null,
          color: isCompleted ? null : AppColors.secondaryLightGrey,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (current) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildSecurityStep();
      case 2:
        return _buildOtpStep();
      default:
        return _buildPersonalInfoStep();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1: PERSONAL INFO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('signup.personalInfo'), style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Please provide your details to get started',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // Profile photo
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _pickProfileImage,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _profileImage == null
                            ? AppColors.primaryGradient
                            : null,
                        color: _profileImage != null
                            ? AppColors.backgroundLight
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryGold.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _profileImage != null
                          ? ClipOval(
                        child: Image.file(
                          _profileImage!,
                          fit: BoxFit.cover,
                          width: 110,
                          height: 110,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.error_outline,
                                color: AppColors.textPrimary, size: 40),
                          ),
                          frameBuilder: (_, child, frame,
                              wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration:
                              const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: child,
                            );
                          },
                        ),
                      )
                          : Icon(Icons.person_outline,
                          color: AppColors.textPrimary, size: 50),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _pickProfileImage,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: AppColors.backgroundWhite, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(Icons.camera_alt,
                            color: AppColors.textPrimary, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(tr('signup.addPhoto'),
                  style: AppTypography.caption),
            ),
            const SizedBox(height: 32),

            _buildTextField(
              controller: firstCtrl,
              label: tr('form.firstName'),
              hint: 'Enter your first name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: lastCtrl,
              label: tr('form.lastName'),
              hint: 'Enter your last name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: emailCtrl,
              label: tr('auth.email'),
              hint: 'example@email.com',
              keyboardType: TextInputType.emailAddress,
              prefixIcon: Icons.email_outlined,
            ),
            const SizedBox(height: 20),
            _buildPhoneField(),
            const SizedBox(height: 32),

            if (msg != null) ...[
              _buildMessageBox(),
              const SizedBox(height: 20),
            ],

            _buildPrimaryButton(text: 'Next', onPressed: _submitStep1),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2: SECURITY
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSecurityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('signup.security'), style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Create a strong password to secure your account',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),

            _buildTextField(
              controller: pwCtrl,
              label: tr('auth.password'),
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            const SizedBox(height: 12),
            Text(tr('signup.min8'),
                style: AppTypography.caption),
            const SizedBox(height: 24),

            _buildTextField(
              controller: confirmPwCtrl,
              label: tr('signup.confirmPassword'),
              hint: 'Re-enter your password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () => setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            const SizedBox(height: 40),

            if (msg != null) ...[
              _buildMessageBox(),
              const SizedBox(height: 20),
            ],

            _buildPrimaryButton(
              text: _isLoading
                  ? 'Creating account...'
                  : 'Continue to Verification',
              onPressed: _isLoading ? () {} : _submitStep2,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3: OTP
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOtpStep() {
    // Show where the code was sent
    final sentTo = channel == 'SMS'
        ? (identifier ?? '$selectedCountryCode${phoneCtrl.text}')
        : (identifier ?? emailCtrl.text);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                channel == 'SMS'
                    ? Icons.sms_outlined
                    : Icons.mark_email_read_outlined,
                color: AppColors.textPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            Text(tr('signup.verificationCode'),
                style: AppTypography.displaySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              'We sent a ${channel == 'SMS' ? 'SMS' : 'email'} code to\n$sentTo',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Your account will be created after verification',
              style: AppTypography.caption.copyWith(
                color: AppColors.textLight,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // OTP input
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder, width: 1.5),
              ),
              child: TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: AppTypography.displayMedium.copyWith(
                  letterSpacing: 16,
                  fontWeight: FontWeight.w600,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  hintText: '• • • • • •',
                  hintStyle: AppTypography.displayMedium.copyWith(
                    color: AppColors.textLight,
                    letterSpacing: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 40),

            if (msg != null) ...[
              _buildMessageBox(),
              const SizedBox(height: 20),
            ],

            _buildPrimaryButton(
              text: _isLoading
                  ? 'Verifying...'
                  : 'Verify & Create Account',
              onPressed: _isLoading ? () {} : _verifyOtp,
            ),
            const SizedBox(height: 32),

            // Resend
            Column(
              children: [
                Text(
                  "Didn't receive the code?",
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _resendOtp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.primaryGold, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Resend Code',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primaryGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText       = false,
    IconData? prefixIcon,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.labelLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder, width: 1.5),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            style: AppTypography.inputText,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.inputHint,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon,
                  color: AppColors.textSecondary, size: 22)
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('auth.phone'), style: AppTypography.labelLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.inputBorder, width: 1.5),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                          color: AppColors.inputBorder, width: 1.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(selectedCountryFlag,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Icon(Icons.keyboard_arrow_down,
                          color: AppColors.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
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
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.textPrimary),
          ),
        )
            : Text(
          text,
          style: AppTypography.buttonLarge
              .copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildMessageBox() {
    final isError = msg!.contains('Error') ||
        msg!.contains('required') ||
        msg!.contains('not match') ||
        msg!.contains('valid') ||
        msg!.contains('denied') ||
        msg!.contains('large') ||
        msg!.contains('failed') ||
        msg!.contains('Invalid') ||
        msg!.contains('expired');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? AppColors.errorLight : AppColors.successLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppColors.error : AppColors.success,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: isError ? AppColors.error : AppColors.success,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg!,
              style: AppTypography.bodyMedium.copyWith(
                color: isError ? AppColors.error : AppColors.success,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: RichText(
          text: TextSpan(
            text: 'Already have an account? ',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.textSecondary),
            children: [
              TextSpan(
                text: 'Login',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.primaryGold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}