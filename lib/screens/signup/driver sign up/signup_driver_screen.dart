// lib/screens/signup/driver_sign_up/signup_driver_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../authentication service/api_services.dart';
import '../../../core/config.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/app_typography.dart';

class SignupDriverScreen extends StatefulWidget {
  const SignupDriverScreen({super.key});

  @override
  State<SignupDriverScreen> createState() => _SignupDriverScreenState();
}

class _SignupDriverScreenState extends State<SignupDriverScreen>
    with TickerProviderStateMixin {
  int current = 0;
  bool isLoading = false;

  // ═══════════════════════════════════════════════════════════════
  // GOOGLE SIGNUP STATE
  // ═══════════════════════════════════════════════════════════════

  bool isGoogleSignup = false;
  String? googleIdToken;
  String? googleAvatarUrl;

  // ═══════════════════════════════════════════════════════════════
  // CONTROLLERS
  // ═══════════════════════════════════════════════════════════════

  final emailCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final firstCtrl = TextEditingController();
  final lastCtrl = TextEditingController();
  final cniCtrl = TextEditingController();

  final vehicleTypeCtrl = TextEditingController(text: 'Economy');
  final vehicleMakeModelCtrl = TextEditingController();
  final vehicleColorCtrl = TextEditingController();
  final vehicleYearCtrl = TextEditingController();
  final vehiclePlateCtrl = TextEditingController();

  final licenseNumberCtrl = TextEditingController();
  final licenseExpiryCtrl = TextEditingController();
  final insuranceNumberCtrl = TextEditingController();
  final insuranceExpiryCtrl = TextEditingController();

  final pwCtrl = TextEditingController();
  final confirmPwCtrl = TextEditingController();

  final otpCtrl = TextEditingController();

  // ═══════════════════════════════════════════════════════════════
  // STATE VARIABLES
  // ═══════════════════════════════════════════════════════════════

  String? msg;
  String? errorMsg;

  String channel = 'EMAIL';
  String purpose = 'EMAIL_VERIFY';
  String? identifier;
  String? signupId;

  String selectedCountryCode = '+237';
  String selectedCountryFlag = '🇨🇲';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _profileImage;
  File? _licenseImage;
  File? _insuranceImage;
  File? _vehicleImage;

  final ImagePicker _picker = ImagePicker();

  late AnimationController _stepAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<String> vehicleTypes = [
    'Economy',
    'Comfort',
    'Business',
    'Premium',
    'SUV',
    'Van',
  ];

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateGoogleArguments();
    });
  }

  void _hydrateGoogleArguments() {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is! Map) return;

    final provider = args['signup_provider']?.toString();

    if (provider != 'google') return;

    setState(() {
      isGoogleSignup = true;
      googleIdToken = args['google_id_token']?.toString();
      googleAvatarUrl = args['avatar_url']?.toString();

      final email = args['email']?.toString() ?? '';
      final firstName = args['first_name']?.toString() ?? '';
      final lastName = args['last_name']?.toString() ?? '';

      if (emailCtrl.text.trim().isEmpty) {
        emailCtrl.text = email;
      }

      if (firstCtrl.text.trim().isEmpty) {
        firstCtrl.text = firstName;
      }

      if (lastCtrl.text.trim().isEmpty) {
        lastCtrl.text = lastName;
      }

      msg = 'Google account connected. Complete your driver documents.';
    });
  }

  void _initializeAnimations() {
    _stepAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stepAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _stepAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _stepAnimationController.forward();
  }

  @override
  void dispose() {
    _stepAnimationController.dispose();

    emailCtrl.dispose();
    phoneCtrl.dispose();
    firstCtrl.dispose();
    lastCtrl.dispose();
    cniCtrl.dispose();

    vehicleTypeCtrl.dispose();
    vehicleMakeModelCtrl.dispose();
    vehicleColorCtrl.dispose();
    vehicleYearCtrl.dispose();
    vehiclePlateCtrl.dispose();

    licenseNumberCtrl.dispose();
    licenseExpiryCtrl.dispose();
    insuranceNumberCtrl.dispose();
    insuranceExpiryCtrl.dispose();

    pwCtrl.dispose();
    confirmPwCtrl.dispose();
    otpCtrl.dispose();

    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // IMAGE PICKER
  // ═══════════════════════════════════════════════════════════════

  Future<void> _pickImage(String type) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        switch (type) {
          case 'profile':
            _profileImage = File(image.path);
            break;
          case 'license':
            _licenseImage = File(image.path);
            break;
          case 'insurance':
            _insuranceImage = File(image.path);
            break;
          case 'vehicle':
            _vehicleImage = File(image.path);
            break;
        }
      });

      debugPrint(
        '✅ [IMAGE PICKER] ${type.toUpperCase()} image selected: ${image.path}',
      );
    } catch (e) {
      debugPrint('❌ [IMAGE PICKER] Error: $e');

      setState(() {
        errorMsg = 'Error selecting image: $e';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP VALIDATION
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitStep1() async {
    setState(() {
      msg = null;
      errorMsg = null;
    });

    if (firstCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'First name is required');
      return;
    }

    if (lastCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Last name is required');
      return;
    }

    if (cniCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'National identity card number is required');
      return;
    }

    if (emailCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Email is required');
      return;
    }

    if (phoneCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Phone number is required');
      return;
    }

    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

    if (!emailRegex.hasMatch(emailCtrl.text.trim())) {
      setState(() => errorMsg = 'Please enter a valid email address');
      return;
    }

    _animateToNextStep();
  }

  Future<void> _submitStep2() async {
    setState(() {
      msg = null;
      errorMsg = null;
    });

    if (vehicleMakeModelCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Vehicle make/model is required');
      return;
    }

    if (vehicleColorCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Vehicle color is required');
      return;
    }

    if (vehicleYearCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Vehicle year is required');
      return;
    }

    if (vehiclePlateCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Vehicle plate number is required');
      return;
    }

    _animateToNextStep();
  }

  Future<void> _submitStep3() async {
    setState(() {
      msg = null;
      errorMsg = null;
    });

    if (licenseNumberCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'Driver\'s license number is required');
      return;
    }

    if (licenseExpiryCtrl.text.trim().isEmpty) {
      setState(() => errorMsg = 'License expiry date is required');
      return;
    }

    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');

    if (!dateRegex.hasMatch(licenseExpiryCtrl.text.trim())) {
      setState(() => errorMsg = 'Invalid date format. Use YYYY-MM-DD');
      return;
    }

    if (_licenseImage == null) {
      setState(() => errorMsg = 'Driver\'s license document photo is required');
      return;
    }

    _animateToNextStep();
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 4 — CREATE PENDING SIGNUP / GOOGLE DRIVER SIGNUP
  // ═══════════════════════════════════════════════════════════════

  Future<void> _submitStep4() async {
    setState(() {
      msg = null;
      errorMsg = null;
      isLoading = true;
    });

    try {
      if (isGoogleSignup) {
        if (googleIdToken == null || googleIdToken!.trim().isEmpty) {
          setState(() {
            errorMsg = 'Google session expired. Please restart signup.';
            isLoading = false;
          });
          return;
        }
      } else {
        if (pwCtrl.text.trim().isEmpty) {
          setState(() {
            errorMsg = 'Password is required';
            isLoading = false;
          });
          return;
        }

        if (confirmPwCtrl.text.trim().isEmpty) {
          setState(() {
            errorMsg = 'Please confirm your password';
            isLoading = false;
          });
          return;
        }

        if (pwCtrl.text != confirmPwCtrl.text) {
          setState(() {
            errorMsg = 'Passwords do not match';
            isLoading = false;
          });
          return;
        }

        if (pwCtrl.text.length < 8) {
          setState(() {
            errorMsg = 'Password must be at least 8 characters';
            isLoading = false;
          });
          return;
        }
      }

      debugPrint('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(
        isGoogleSignup
            ? '🚗 [GOOGLE DRIVER SIGNUP] Starting registration...'
            : '🚗 [DRIVER SIGNUP] Starting registration...',
      );
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/signup/driver');

      debugPrint('📡 [SIGNUP] API URL: $uri');

      final request = http.MultipartRequest('POST', uri);

      final email = emailCtrl.text.trim();
      final phone = phoneCtrl.text.trim();
      final fullPhone = '$selectedCountryCode$phone';

      if (email.isNotEmpty) {
        request.fields['email'] = email;
        debugPrint('📧 Email: $email');
      }

      if (phone.isNotEmpty) {
        request.fields['phone_e164'] = fullPhone;
        debugPrint('📱 Phone: $fullPhone');
      }

      request.fields['first_name'] = firstCtrl.text.trim();
      request.fields['last_name'] = lastCtrl.text.trim();
      request.fields['cni_number'] = cniCtrl.text.trim();
      request.fields['license_number'] = licenseNumberCtrl.text.trim();

      if (isGoogleSignup) {
        request.fields['provider'] = 'google';
        request.fields['google_id_token'] = googleIdToken!.trim();

        if (googleAvatarUrl != null && googleAvatarUrl!.trim().isNotEmpty) {
          request.fields['google_avatar_url'] = googleAvatarUrl!.trim();
        }
      } else {
        request.fields['password'] = pwCtrl.text;
      }

      if (licenseExpiryCtrl.text.trim().isNotEmpty) {
        request.fields['license_expiry'] = licenseExpiryCtrl.text.trim();
      }

      if (insuranceNumberCtrl.text.trim().isNotEmpty) {
        request.fields['insurance_number'] = insuranceNumberCtrl.text.trim();
      }

      if (insuranceExpiryCtrl.text.trim().isNotEmpty) {
        request.fields['insurance_expiry'] = insuranceExpiryCtrl.text.trim();
      }

      request.fields['vehicle_type'] = vehicleTypeCtrl.text.trim();
      request.fields['vehicle_make_model'] = vehicleMakeModelCtrl.text.trim();
      request.fields['vehicle_color'] = vehicleColorCtrl.text.trim();
      request.fields['vehicle_year'] = vehicleYearCtrl.text.trim();
      request.fields['vehicle_plate'] = vehiclePlateCtrl.text.trim();

      debugPrint('📋 [SIGNUP] Text fields added');

      if (_profileImage != null) {
        debugPrint('📸 [SIGNUP] Adding profile picture...');

        request.files.add(
          await http.MultipartFile.fromPath(
            'avatar',
            _profileImage!.path,
          ),
        );

        debugPrint('   ✅ Profile picture added');
      }

      if (_licenseImage != null) {
        debugPrint('📄 [SIGNUP] Adding license document...');

        request.files.add(
          await http.MultipartFile.fromPath(
            'license',
            _licenseImage!.path,
          ),
        );

        debugPrint('   ✅ License document added');
      }

      if (_insuranceImage != null) {
        debugPrint('📄 [SIGNUP] Adding insurance document...');

        request.files.add(
          await http.MultipartFile.fromPath(
            'insurance',
            _insuranceImage!.path,
          ),
        );

        debugPrint('   ✅ Insurance document added');
      }

      if (_vehicleImage != null) {
        debugPrint('🚗 [SIGNUP] Adding vehicle photo...');

        request.files.add(
          await http.MultipartFile.fromPath(
            'vehicle_photo',
            _vehicleImage!.path,
          ),
        );

        debugPrint('   ✅ Vehicle photo added');
      }

      debugPrint('\n📤 [SIGNUP] Sending registration request...');

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      debugPrint('📥 [SIGNUP] Response received');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Body: $responseBody');

      final decoded = jsonDecode(responseBody);

      if (decoded is! Map<String, dynamic>) {
        setState(() {
          errorMsg = 'Invalid server response';
        });
        return;
      }

      final jsonResponse = decoded;

      debugPrint('   Success: ${jsonResponse['success']}');
      debugPrint('   Message: ${jsonResponse['message']}');

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          jsonResponse['success'] == true) {
        final data = jsonResponse['data'];

        if (isGoogleSignup) {
          debugPrint('\n✅ [GOOGLE DRIVER SIGNUP] Completed successfully!');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

          setState(() {
            msg = jsonResponse['message']?.toString() ??
                'Driver account created successfully. You can now login.';
          });

          await Future.delayed(const Duration(seconds: 2));

          if (!mounted) return;

          Navigator.of(context).pushNamedAndRemoveUntil(
            '/login',
                (route) => false,
          );

          return;
        }

        if (data is Map<String, dynamic>) {
          signupId = data['signup_id']?.toString();

          debugPrint('\n✅ [SIGNUP] Pending signup created successfully!');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('📋 Pending Signup Info:');
          debugPrint('   Signup ID: $signupId');
          debugPrint('   User Type: ${data['user_type']}');
          debugPrint('   Name: ${data['first_name']} ${data['last_name']}');
          debugPrint('   Email: ${data['email'] ?? "N/A"}');
          debugPrint('   Phone: ${data['phone_e164'] ?? "N/A"}');
          debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

          final otpDelivery = data['otp_delivery'];

          if (otpDelivery is Map) {
            if (otpDelivery['email'] != null) {
              channel = 'EMAIL';
              purpose = 'EMAIL_VERIFY';
              identifier = email;

              debugPrint('📧 [OTP] Will verify via EMAIL: $identifier');
            } else if (otpDelivery['phone'] != null) {
              channel = 'SMS';
              purpose = 'PHONE_VERIFY';
              identifier = fullPhone;

              debugPrint('📱 [OTP] Will verify via SMS: $identifier');
            }
          }
        }

        setState(() {
          msg = jsonResponse['message']?.toString();
        });

        _animateToNextStep();
      } else {
        debugPrint('\n❌ [SIGNUP] Registration failed');
        debugPrint('   Error: ${jsonResponse['message']}');
        debugPrint('   Code: ${jsonResponse['code']}\n');

        String errorMessage =
            jsonResponse['message']?.toString() ?? 'Registration failed';

        final errorCode = jsonResponse['code']?.toString();

        if (errorCode == 'EMAIL_ALREADY_EXISTS') {
          errorMessage = 'This email is already registered';
        } else if (errorCode == 'PHONE_ALREADY_EXISTS') {
          errorMessage = 'This phone number is already registered';
        } else if (errorCode == 'PLATE_EXISTS') {
          errorMessage = 'This vehicle plate is already registered';
        } else if (errorCode == 'GOOGLE_ACCOUNT_ALREADY_EXISTS') {
          errorMessage = 'This Google account is already registered.';
        } else if (errorCode == 'INVALID_GOOGLE_TOKEN') {
          errorMessage = 'Invalid Google session. Please restart signup.';
        }

        setState(() {
          errorMsg = errorMessage;
        });
      }
    } catch (e) {
      debugPrint('\n❌ [SIGNUP] Exception occurred');
      debugPrint('   Error: $e\n');

      setState(() {
        errorMsg = 'Registration failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OTP
  // ═══════════════════════════════════════════════════════════════

  Future<void> _verifyOtpAndComplete() async {
    setState(() {
      msg = null;
      errorMsg = null;
      isLoading = true;
    });

    if (otpCtrl.text.trim().length != 6) {
      setState(() {
        errorMsg = 'Please enter a valid 6-digit OTP code';
        isLoading = false;
      });
      return;
    }

    if (identifier == null || identifier!.trim().isEmpty) {
      setState(() {
        errorMsg = 'Verification identifier missing. Please restart signup.';
        isLoading = false;
      });
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

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/verify');

      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'purpose': purpose,
          'code': otpCtrl.text.trim(),
        }),
      );

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        setState(() {
          errorMsg = 'Invalid server response';
        });
        return;
      }

      final jsonResponse = decoded;

      debugPrint('📥 [OTP] Response received');
      debugPrint('   Status Code: ${response.statusCode}');
      debugPrint('   Success: ${jsonResponse['success']}');
      debugPrint('   Message: ${jsonResponse['message']}');

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('\n✅ [OTP] Verification successful!');
        debugPrint('✅ [ACCOUNT] Account created successfully!\n');

        setState(() {
          msg = 'Account created successfully! You can now login.';
        });

        await Future.delayed(const Duration(seconds: 2));

        if (!mounted) return;

        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
              (route) => false,
        );
      } else {
        debugPrint('❌ [OTP] Verification failed');
        debugPrint('   Error: ${jsonResponse['message']}\n');

        String errorMessage =
            jsonResponse['message']?.toString() ?? 'Invalid OTP code';

        final errorCode = jsonResponse['code']?.toString();

        if (errorCode == 'OTP_EXPIRED') {
          errorMessage = 'OTP code has expired. Please request a new one.';
        } else if (errorCode == 'TOO_MANY_ATTEMPTS') {
          errorMessage = 'Too many failed attempts. Please request a new code.';
        } else if (errorCode == 'SIGNUP_EXPIRED') {
          errorMessage =
          'Signup session expired. Please start registration again.';
        } else if (errorCode == 'INVALID_OTP') {
          errorMessage = 'Invalid OTP code. Please try again.';
        }

        setState(() {
          errorMsg = errorMessage;
        });
      }
    } catch (e) {
      debugPrint('❌ [OTP] Exception: $e\n');

      setState(() {
        errorMsg = 'Verification failed: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _resendOtp() async {
    setState(() {
      msg = null;
      errorMsg = null;
    });

    if (identifier == null || identifier!.trim().isEmpty) {
      setState(() {
        errorMsg = 'Cannot resend code. Please restart signup.';
      });
      return;
    }

    try {
      debugPrint('🔄 [OTP] Resending OTP...');

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/auth/otp/send');

      final response = await http.post(
        uri,
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier,
          'channel': channel,
          'purpose': purpose,
        }),
      );

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        setState(() {
          errorMsg = 'Invalid server response';
        });
        return;
      }

      final jsonResponse = decoded;

      if (response.statusCode == 200 && jsonResponse['success'] == true) {
        debugPrint('✅ [OTP] OTP resent successfully\n');

        setState(() {
          msg = 'Verification code sent successfully';
        });
      } else {
        debugPrint('❌ [OTP] Resend failed: ${jsonResponse['message']}\n');

        setState(() {
          errorMsg = jsonResponse['message']?.toString() ??
              'Failed to resend verification code';
        });
      }
    } catch (e) {
      debugPrint('❌ [OTP] Resend failed: $e\n');

      setState(() {
        errorMsg = 'Failed to resend code';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION HELPERS
  // ═══════════════════════════════════════════════════════════════

  void _animateToNextStep() {
    _stepAnimationController.reset();

    setState(() {
      current += 1;
    });

    _stepAnimationController.forward();
  }

  void _animateToPreviousStep() {
    if (current <= 0) return;

    _stepAnimationController.reset();

    setState(() {
      current -= 1;
    });

    _stepAnimationController.forward();
  }

  Future<void> _selectDate(
      BuildContext context,
      TextEditingController controller,
      ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGold,
              onPrimary: AppColors.textPrimary,
              surface: AppColors.backgroundWhite,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    final formattedDate =
        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

    controller.text = formattedDate;
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundWhite,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
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
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.textSecondary,
                  ),
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
                    leading: Text(
                      country['flag']!,
                      style: const TextStyle(fontSize: 28),
                    ),
                    title: Text(
                      country['name']!,
                      style: AppTypography.bodyMedium,
                    ),
                    trailing: Text(
                      country['code']!,
                      style: AppTypography.bodySmall,
                    ),
                    selected: isSelected,
                    selectedTileColor:
                    AppColors.primaryGold.withOpacity(0.1),
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
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 18,
              ),
            ),
          ),
          Expanded(
            child: Text(
              isGoogleSignup
                  ? 'Google Driver Registration'
                  : 'Driver Registration',
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
    final totalSteps = isGoogleSignup ? 4 : 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          for (int i = 0; i < totalSteps; i++) ...[
            _buildStepCircle(i, '${i + 1}'),
            if (i < totalSteps - 1) _buildProgressLine(i),
          ],
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = current == step;
    final isCompleted = current > step;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: isCompleted || isActive ? AppColors.primaryGradient : null,
        color: isCompleted || isActive ? null : AppColors.secondaryLightGrey,
        shape: BoxShape.circle,
        boxShadow: isActive
            ? [
          BoxShadow(
            color: AppColors.primaryGold.withOpacity(0.4),
            blurRadius: 12,
          ),
        ]
            : null,
      ),
      child: Center(
        child: isCompleted
            ? Icon(
          Icons.check,
          color: AppColors.textPrimary,
          size: 16,
        )
            : Text(
          label,
          style: AppTypography.bodySmall.copyWith(
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
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: isCompleted ? AppColors.primaryGradient : null,
          color: isCompleted ? null : AppColors.secondaryLightGrey,
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (current) {
      case 0:
        return _buildPersonalInfoStep();
      case 1:
        return _buildVehicleInfoStep();
      case 2:
        return _buildDocumentsStep();
      case 3:
        return _buildSecurityStep();
      case 4:
        return _buildOtpStep();
      default:
        return _buildPersonalInfoStep();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 1 — PERSONAL INFO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Personal Information',
              style: AppTypography.displaySmall,
            ),
            const SizedBox(height: 8),
            Text(
              isGoogleSignup
                  ? 'Your Google information was added. Complete the remaining fields.'
                  : 'Provide your personal and identification details',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (isGoogleSignup) ...[
              _buildGoogleConnectedBox(),
              const SizedBox(height: 24),
            ],
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => _pickImage('profile'),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient:
                        _profileImage == null ? AppColors.primaryGradient : null,
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
                        ),
                      )
                          : Icon(
                        Icons.person_outline,
                        color: AppColors.textPrimary,
                        size: 50,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
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
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: AppColors.textPrimary,
                        size: 18,
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
              controller: cniCtrl,
              label: 'National Identity Card (CNI)',
              hint: 'Enter your CNI number',
              prefixIcon: Icons.badge_outlined,
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
            _buildMessages(),
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

  Widget _buildGoogleConnectedBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Google account connected: ${emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : "verified account"}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 2 — VEHICLE INFO
  // ═══════════════════════════════════════════════════════════════

  Widget _buildVehicleInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              icon: Icons.directions_car,
              title: 'Vehicle Information',
              subtitle: 'Tell us about your vehicle',
            ),
            const SizedBox(height: 32),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vehicle Type',
                  style: AppTypography.labelLarge,
                ),
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
                  child: DropdownButtonFormField<String>(
                    value: vehicleTypeCtrl.text,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.category_outlined,
                        color: AppColors.textSecondary,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    items: vehicleTypes.map((String type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(
                          type,
                          style: AppTypography.inputText,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue == null) return;

                      setState(() {
                        vehicleTypeCtrl.text = newValue;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: vehicleMakeModelCtrl,
              label: 'Vehicle Make & Model',
              hint: 'e.g., Toyota Corolla',
              prefixIcon: Icons.car_rental,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: vehicleColorCtrl,
              label: 'Vehicle Color',
              hint: 'e.g., Black, White, Silver',
              prefixIcon: Icons.palette_outlined,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: vehicleYearCtrl,
              label: 'Vehicle Year',
              hint: 'e.g., 2020',
              keyboardType: TextInputType.number,
              prefixIcon: Icons.calendar_today_outlined,
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: vehiclePlateCtrl,
              label: 'Vehicle Plate Number',
              hint: 'e.g., LT-1234-AB',
              prefixIcon: Icons.pin_outlined,
            ),
            const SizedBox(height: 32),
            _buildImageUploadCard(
              title: 'Vehicle Photo',
              subtitle: 'Upload a clear photo of your vehicle (Optional)',
              icon: Icons.directions_car,
              image: _vehicleImage,
              onTap: () => _pickImage('vehicle'),
            ),
            const SizedBox(height: 32),
            _buildMessages(),
            _buildPrimaryButton(
              text: 'Continue',
              onPressed: _submitStep2,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 3 — DOCUMENTS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDocumentsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              icon: Icons.description_outlined,
              title: 'Documents',
              subtitle: 'Upload your driver documents',
            ),
            const SizedBox(height: 32),
            _buildTextField(
              controller: licenseNumberCtrl,
              label: 'Driver\'s License Number',
              hint: 'Enter your license number',
              prefixIcon: Icons.credit_card,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _selectDate(context, licenseExpiryCtrl),
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: licenseExpiryCtrl,
                  label: 'License Expiry Date',
                  hint: 'YYYY-MM-DD',
                  prefixIcon: Icons.event_outlined,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Required - Format: YYYY-MM-DD',
              style: AppTypography.caption.copyWith(
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            _buildImageUploadCard(
              title: 'Driver\'s License Document',
              subtitle: 'Upload a clear photo of your license (Required)',
              icon: Icons.credit_card,
              image: _licenseImage,
              onTap: () => _pickImage('license'),
              isRequired: true,
            ),
            const SizedBox(height: 24),
            _buildTextField(
              controller: insuranceNumberCtrl,
              label: 'Insurance Policy Number (Optional)',
              hint: 'Enter insurance number',
              prefixIcon: Icons.shield_outlined,
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _selectDate(context, insuranceExpiryCtrl),
              child: AbsorbPointer(
                child: _buildTextField(
                  controller: insuranceExpiryCtrl,
                  label: 'Insurance Expiry Date (Optional)',
                  hint: 'YYYY-MM-DD',
                  prefixIcon: Icons.event_outlined,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildImageUploadCard(
              title: 'Insurance Document',
              subtitle: 'Upload your insurance document (Optional)',
              icon: Icons.shield_outlined,
              image: _insuranceImage,
              onTap: () => _pickImage('insurance'),
            ),
            const SizedBox(height: 32),
            _buildMessages(),
            _buildPrimaryButton(
              text: 'Continue',
              onPressed: _submitStep3,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 4 — SECURITY / GOOGLE CONFIRMATION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSecurityStep() {
    if (isGoogleSignup) {
      return _buildGoogleFinalStep();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              icon: Icons.lock_outline,
              title: 'Security',
              subtitle: 'Create a strong password',
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
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
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
            _buildMessages(),
            _buildPrimaryButton(
              text: isLoading
                  ? 'Creating Pending Signup...'
                  : 'Continue to Verification',
              onPressed: isLoading ? () {} : _submitStep4,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleFinalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepTitle(
              icon: Icons.verified_user_outlined,
              title: 'Complete Google Registration',
              subtitle:
              'Your Google account will be used instead of password and OTP.',
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    icon: Icons.person_outline,
                    label: 'Name',
                    value:
                    '${firstCtrl.text.trim()} ${lastCtrl.text.trim()}'.trim(),
                  ),
                  const SizedBox(height: 14),
                  _buildSummaryRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: emailCtrl.text.trim(),
                  ),
                  const SizedBox(height: 14),
                  _buildSummaryRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: '$selectedCountryCode${phoneCtrl.text.trim()}',
                  ),
                  const SizedBox(height: 14),
                  _buildSummaryRow(
                    icon: Icons.directions_car_outlined,
                    label: 'Vehicle',
                    value: vehiclePlateCtrl.text.trim(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _buildMessageBox(
              'Password and OTP will be skipped because your Google account is already verified. Your driver documents are still required.',
              isError: false,
            ),
            const SizedBox(height: 28),
            _buildMessages(),
            _buildPrimaryButton(
              text: isLoading ? 'Creating Account...' : 'Create Driver Account',
              onPressed: isLoading ? () {} : _submitStep4,
            ),
            const SizedBox(height: 20),
            _buildLoginLink(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.textSecondary,
          size: 22,
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value.isNotEmpty ? value : 'N/A',
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP 5 — OTP
  // ═══════════════════════════════════════════════════════════════

  Widget _buildOtpStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(),
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
            _buildMessages(),
            _buildPrimaryButton(
              text: isLoading
                  ? 'Creating Account...'
                  : 'Verify & Create Account',
              onPressed: isLoading ? () {} : _verifyOtpAndComplete,
            ),
            const SizedBox(height: 32),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
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

  // ═══════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════════

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.backgroundWhite,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.shadowLight,
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  Widget _buildStepTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.textPrimary,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.displaySmall,
              ),
              Text(
                subtitle,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessages() {
    return Column(
      children: [
        if (errorMsg != null) ...[
          _buildMessageBox(errorMsg!, isError: true),
          const SizedBox(height: 20),
        ],
        if (msg != null) ...[
          _buildMessageBox(msg!, isError: false),
          const SizedBox(height: 20),
        ],
      ],
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
        Text(
          label,
          style: AppTypography.labelLarge,
        ),
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
                  ? Icon(
                prefixIcon,
                color: AppColors.textSecondary,
                size: 22,
              )
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
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
        Text(
          'Phone Number',
          style: AppTypography.labelLarge,
        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
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
                      Icon(
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: AppTypography.inputText,
                  decoration: InputDecoration(
                    hintText: '6 77 77 77 77',
                    hintStyle: AppTypography.inputHint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required File? image,
    required VoidCallback onTap,
    bool isRequired = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
          image != null ? AppColors.successLight : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: image != null
                ? AppColors.success
                : (isRequired ? AppColors.error : AppColors.borderLight),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: image != null
                    ? AppColors.success
                    : AppColors.primaryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: image != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  image,
                  fit: BoxFit.cover,
                ),
              )
                  : Icon(
                icon,
                color: AppColors.textPrimary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTypography.titleMedium,
                        ),
                      ),
                      if (isRequired)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Required',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.backgroundWhite,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    image != null ? 'Image uploaded ✓' : subtitle,
                    style: AppTypography.caption.copyWith(
                      color: image != null
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              image != null
                  ? Icons.check_circle
                  : Icons.cloud_upload_outlined,
              color: image != null ? AppColors.success : AppColors.textSecondary,
              size: 24,
            ),
          ],
        ),
      ),
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
        child: isLoading
            ? SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppColors.textPrimary,
            ),
          ),
        )
            : Text(
          text,
          style: AppTypography.buttonLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBox(String message, {required bool isError}) {
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
              message,
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