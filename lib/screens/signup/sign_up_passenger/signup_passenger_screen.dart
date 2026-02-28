// lib/screens/signup/passenger_sign_up/signup_passenger_screen.dart

import 'package:flutter/material.dart';
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

class _SignupPassengerScreenState extends State<SignupPassengerScreen> with TickerProviderStateMixin {
  int current = 0;

  // Step 1 inputs
  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final firstCtrl = TextEditingController();
  final lastCtrl = TextEditingController();
  final pwCtrl = TextEditingController();
  final confirmPwCtrl = TextEditingController();

  // Step 3 (OTP)
  final otpCtrl = TextEditingController();
  String channel = 'EMAIL';
  String purpose = 'EMAIL_VERIFY';
  String? identifier;
  String? msg;
  String? signupId; // ✅ NEW: Track pending signup UUID

  // Profile photo
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String selectedCountryCode = '+237';
  String selectedCountryFlag = '🇨🇲';

  // Password visibility
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Animation controllers
  late AnimationController _stepAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Country codes with flags
  final List<Map<String, String>> countries = [
    {'code': '+237', 'flag': '🇨🇲', 'name': 'Cameroon'},
    {'code': '+1', 'flag': '🇺🇸', 'name': 'United States'},
    {'code': '+44', 'flag': '🇬🇧', 'name': 'United Kingdom'},
    {'code': '+33', 'flag': '🇫🇷', 'name': 'France'},
    {'code': '+49', 'flag': '🇩🇪', 'name': 'Germany'},
    {'code': '+39', 'flag': '🇮🇹', 'name': 'Italy'},
    {'code': '+34', 'flag': '🇪🇸', 'name': 'Spain'},
    {'code': '+31', 'flag': '🇳🇱', 'name': 'Netherlands'},
    {'code': '+91', 'flag': '🇮🇳', 'name': 'India'},
    {'code': '+86', 'flag': '🇨🇳', 'name': 'China'},
    {'code': '+81', 'flag': '🇯🇵', 'name': 'Japan'},
    {'code': '+234', 'flag': '🇳🇬', 'name': 'Nigeria'},
    {'code': '+27', 'flag': '🇿🇦', 'name': 'South Africa'},
  ];

  @override
  void initState() {
    super.initState();
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stepAnimationController, curve: Curves.easeInOut),
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

  String? _pickIdentifier({
    required String channel,
    required String email,
    required String phone,
  }) {
    final em = email.trim();
    final ph = phone.trim();
    if (channel == 'EMAIL') {
      return em.isNotEmpty ? em : null;
    } else {
      return ph.isNotEmpty ? ph : null;
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      setState(() {
        msg = null;
      });

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (image != null) {
        final fileSize = await image.length();
        debugPrint('📷 Image picked: ${image.path}');
        debugPrint('📊 File size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

        if (fileSize > 5 * 1024 * 1024) {
          setState(() {
            msg = 'Image is too large. Please select a smaller image.';
          });
          return;
        }

        setState(() {
          _profileImage = File(image.path);
          msg = 'Profile photo selected successfully';
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              if (msg == 'Profile photo selected successfully') {
                msg = null;
              }
            });
          }
        });
      } else {
        debugPrint('📷 No image selected');
      }
    } on PlatformException catch (e) {
      debugPrint('❌ Platform Exception: ${e.code} - ${e.message}');

      setState(() {
        if (e.code == 'photo_access_denied' || e.code == 'camera_access_denied') {
          msg = 'Permission denied. Please enable photo access in settings.';
        } else {
          msg = 'Error accessing photos: ${e.message ?? "Unknown error"}';
        }
      });
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      setState(() {
        msg = 'Error selecting image. Please try again.';
      });
    }
  }

  Future<void> _submitStep1() async {
    setState(() => msg = null);

    // Validation
    if (firstCtrl.text.trim().isEmpty) {
      setState(() => msg = 'First name is required');
      return;
    }
    if (lastCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Last name is required');
      return;
    }
    if (emailCtrl.text.trim().isEmpty && phoneCtrl.text.trim().isEmpty) {
      setState(() => msg = 'Email or phone number is required');
      return;
    }

    // Email validation
    if (emailCtrl.text.trim().isNotEmpty) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(emailCtrl.text.trim())) {
        setState(() => msg = 'Please enter a valid email address');
        return;
      }
    }

    _animateToNextStep();
  }

  Future<void> _submitStep2() async {
    setState(() => msg = null);

    // Validation
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

    // Show loading state
    setState(() => msg = 'Creating your pending signup...');

    try {
      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🚖 [PASSENGER SIGNUP] Starting registration...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      // Prepare payload
      final payload = <String, dynamic>{
        'first_name': firstCtrl.text.trim(),
        'last_name': lastCtrl.text.trim(),
        'password': pwCtrl.text,
      };

      // Add email or phone
      if (email.isNotEmpty) {
        payload['email'] = email;
        debugPrint('📧 Email: $email');
      }

      if (phone.isNotEmpty) {
        final fullPhone = '$selectedCountryCode$phone';
        payload['phone_e164'] = fullPhone;
        debugPrint('📱 Phone: $fullPhone');
      }

      debugPrint('👤 Name: ${payload['first_name']} ${payload['last_name']}');
      debugPrint('📸 Avatar: ${_profileImage != null ? "YES" : "NO"}');

      final resp = await ApiService.signupPassenger(
        payload,
        avatar: _profileImage,
      );

      // ✅ UPDATED: Check for 200 status (not 201) - pending signup created
      debugPrint('📥 [PASSENGER SIGNUP] Response received');
      debugPrint('   Success: ${resp['success']}');
      debugPrint('   Message: ${resp['message']}');

      if (resp['success'] == true) {
        debugPrint('\n✅ [SIGNUP] Pending signup created successfully!');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

        final data = resp['data'];

        // ✅ NEW: Store signup_id for tracking
        signupId = data['signup_id'];

        debugPrint('📋 Pending Signup Info:');
        debugPrint('   Signup ID: $signupId');
        debugPrint('   User Type: ${data['user_type']}');
        debugPrint('   Name: ${data['first_name']} ${data['last_name']}');
        debugPrint('   Email: ${data['email'] ?? "N/A"}');
        debugPrint('   Phone: ${data['phone_e164'] ?? "N/A"}');
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

        // Determine OTP channel
        final otpDelivery = data['otp_delivery'];
        if (otpDelivery != null) {
          if (otpDelivery['email'] != null) {
            channel = 'EMAIL';
            purpose = 'EMAIL_VERIFY';
            identifier = email;
            debugPrint('📧 [OTP] Will verify via EMAIL: $identifier');
          } else if (otpDelivery['phone'] != null) {
            channel = 'SMS';
            purpose = 'PHONE_VERIFY';
            identifier = '$selectedCountryCode$phone';
            debugPrint('📱 [OTP] Will verify via SMS: $identifier');
          }
        }

        setState(() {
          msg = resp['message'] ?? 'Verification code sent. Please verify to complete registration.';
        });

        // Wait a moment to show success message
        await Future.delayed(const Duration(milliseconds: 500));

        _animateToNextStep();
      } else {
        debugPrint('\n❌ [SIGNUP] Registration failed');
        debugPrint('   Error: ${resp['message']}\n');

        // ✅ IMPROVED: Better error handling
        String errorMessage = resp['message'] ?? 'Registration failed';

        // Handle specific error codes
        final errorCode = resp['code'];
        if (errorCode == 'EMAIL_ALREADY_EXISTS') {
          errorMessage = 'This email is already registered';
        } else if (errorCode == 'PHONE_ALREADY_EXISTS') {
          errorMessage = 'This phone number is already registered';
        }

        setState(() {
          msg = errorMessage;
        });
      }
    } catch (e) {
      debugPrint('❌ [PASSENGER SIGNUP] Error: $e\n');

      setState(() {
        msg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() => msg = null);

    if (otpCtrl.text.trim().length != 6) {
      setState(() => msg = 'Please enter a valid 6-digit OTP code');
      return;
    }

    try {
      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔐 [OTP] Verifying OTP and creating account...');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('Signup ID: $signupId');
      debugPrint('Identifier: $identifier');
      debugPrint('Purpose: $purpose');
      debugPrint('OTP: ${otpCtrl.text}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      identifier ??= _pickIdentifier(
        channel: channel,
        email: emailCtrl.text,
        phone: '$selectedCountryCode${phoneCtrl.text}',
      );

      if (identifier == null || identifier!.isEmpty) {
        setState(() {
          msg = 'Select the correct channel and provide email/phone.';
        });
        return;
      }

      // ✅ UPDATED: Use new OTP verification endpoint
      final resp = await ApiService.verifyOtp(
        identifier: identifier!,
        purpose: purpose,
        code: otpCtrl.text.trim(),
      );

      debugPrint('📥 [OTP] Response received');
      debugPrint('   Success: ${resp['success']}');
      debugPrint('   Message: ${resp['message']}');

      if (resp['success'] == true) {
        debugPrint('\n✅ [OTP] Verification successful!');
        debugPrint('✅ [ACCOUNT] Account created successfully!\n');

        // ✅ UPDATED: Show new success message
        setState(() {
          msg = 'Account created successfully! You can now login.';
        });

        // Navigate to login after 2 seconds
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );
        }
      } else {
        debugPrint('❌ [OTP] Verification failed');
        debugPrint('   Error: ${resp['message']}\n');

        // ✅ IMPROVED: Handle specific error codes
        String errorMessage = resp['message'] ?? 'Invalid OTP code';

        final errorCode = resp['code'];
        if (errorCode == 'OTP_EXPIRED') {
          errorMessage = 'OTP code has expired. Please request a new one.';
        } else if (errorCode == 'TOO_MANY_ATTEMPTS') {
          errorMessage = 'Too many failed attempts. Please request a new code.';
        } else if (errorCode == 'SIGNUP_EXPIRED') {
          errorMessage = 'Signup session expired. Please start registration again.';
        } else if (errorCode == 'INVALID_OTP') {
          errorMessage = 'Invalid OTP code. Please try again.';
        }

        setState(() {
          msg = errorMessage;
        });
      }
    } catch (e) {
      debugPrint('❌ [OTP] Exception: $e\n');
      setState(() {
        msg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _resendOtp() async {
    setState(() => msg = null);

    try {
      identifier = _pickIdentifier(
        channel: channel,
        email: emailCtrl.text,
        phone: '$selectedCountryCode${phoneCtrl.text}',
      );

      if (identifier == null || identifier!.isEmpty) {
        setState(() {
          msg = 'Enter your email/phone for the selected channel.';
        });
        return;
      }

      debugPrint('🔄 [OTP] Resending OTP...');

      await ApiService.sendOtp(
        identifier: identifier!,
        channel: channel,
        purpose: purpose,
      );

      debugPrint('✅ [OTP] OTP resent successfully\n');

      setState(() {
        msg = 'Verification code sent successfully';
      });
    } catch (e) {
      debugPrint('❌ [OTP] Resend failed: $e\n');
      setState(() {
        msg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _animateToNextStep() {
    _stepAnimationController.reset();
    setState(() {
      current += 1;
    });
    _stepAnimationController.forward();
  }

  void _animateToPreviousStep() {
    _stepAnimationController.reset();
    setState(() {
      current -= 1;
    });
    _stepAnimationController.forward();
  }

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
                Text(
                  'Select Country',
                  style: AppTypography.headlineSmall,
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final isSelected = selectedCountryCode == country['code'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryGold.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGold : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Text(
                        country['flag']!,
                        style: const TextStyle(fontSize: 28),
                      ),
                      title: Text(
                        country['name']!,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      trailing: Text(
                        country['code']!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textPrimary,
                size: 18,
              ),
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
    final isActive = current == step;
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
            ? const Icon(Icons.check, color: AppColors.textPrimary, size: 18)
            : Text(
          label,
          style: AppTypography.titleMedium.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textLight,
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
            Text('Personal Information', style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Please provide your details to get started',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),

            // Profile Photo Section
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
                        gradient: _profileImage == null ? AppColors.primaryGradient : null,
                        color: _profileImage != null ? AppColors.backgroundLight : null,
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
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('❌ Error displaying image: $error');
                            return Container(
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline,
                                color: AppColors.textPrimary,
                                size: 40,
                              ),
                            );
                          },
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) {
                              return child;
                            }
                            return AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut,
                              child: child,
                            );
                          },
                        ),
                      )
                          : const Icon(
                        Icons.person_outline,
                        color: AppColors.textPrimary,
                        size: 50,
                      ),
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
                            color: AppColors.backgroundWhite,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryGold.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: AppColors.textPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Add profile photo (optional)',
                style: AppTypography.caption,
              ),
            ),
            const SizedBox(height: 32),

            // Form Fields
            _buildTextField(
              controller: firstCtrl,
              label: 'First Name',
              hint: 'Enter your first name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: lastCtrl,
              label: 'Last Name',
              hint: 'Enter your last name',
              prefixIcon: Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _buildTextField(
              controller: emailCtrl,
              label: 'Email Address',
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

            _buildPrimaryButton(
              text: 'Next',
              onPressed: _submitStep1,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

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
            Text('Security', style: AppTypography.displaySmall),
            const SizedBox(height: 8),
            Text(
              'Create a strong password to secure your account',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 40),

            _buildTextField(
              controller: pwCtrl,
              label: 'Password',
              hint: 'Enter your password',
              obscureText: _obscurePassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Must be at least 8 characters',
              style: AppTypography.caption,
            ),
            const SizedBox(height: 24),

            _buildTextField(
              controller: confirmPwCtrl,
              label: 'Confirm Password',
              hint: 'Re-enter your password',
              obscureText: _obscureConfirmPassword,
              prefixIcon: Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: AppColors.textSecondary,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            const SizedBox(height: 40),

            if (msg != null) ...[
              _buildMessageBox(),
              const SizedBox(height: 20),
            ],

            _buildPrimaryButton(
              text: 'Continue to Verification',
              onPressed: _submitStep2,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpStep() {
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
            // Icon
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
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: AppColors.textPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Verification Code',
              style: AppTypography.displaySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'We sent a verification code to\n${channel == 'EMAIL' ? emailCtrl.text : '$selectedCountryCode${phoneCtrl.text}'}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
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

            // OTP Input Field
            Container(
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.inputBorder,
                  width: 1.5,
                ),
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                ),
              ),
            ),
            const SizedBox(height: 40),

            if (msg != null) ...[
              _buildMessageBox(),
              const SizedBox(height: 20),
            ],

            _buildPrimaryButton(
              text: 'Verify & Create Account',
              onPressed: _verifyOtp,
            ),
            const SizedBox(height: 32),

            // Resend OTP
            Column(
              children: [
                Text(
                  "Didn't receive the code?",
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: _resendOtp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primaryGold,
                        width: 1.5,
                      ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool obscureText = false,
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
            border: Border.all(
              color: AppColors.inputBorder,
              width: 1.5,
            ),
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
                  ? Icon(prefixIcon, color: AppColors.textSecondary, size: 22)
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
        Text('Phone Number', style: AppTypography.labelLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.inputBorder,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _showCountryPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        selectedCountryFlag,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          text,
          style: AppTypography.buttonLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
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
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
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