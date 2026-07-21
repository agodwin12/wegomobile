// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import 'dart:async';
import '../../utils/utils.dart';
import '../../widgets/common_widgets.dart';
import '../../authentication service/api_services.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();
  bool loading = false;
  String? message;

  Future<void> _resetPassword() async {
    if (emailCtrl.text.trim().isEmpty) {
      setState(() {
        message = 'Please enter your email address';
      });
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await AuthService().forgotPassword(emailCtrl.text.trim());

      // Navigate to OTP verification screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/forgot-password/otp',
          arguments: {'email': emailCtrl.text.trim()},
        );
      }

    } on AuthException catch (e) {
      setState(() {
        message = e.message;
      });
    } catch (e) {
      setState(() {
        message = 'Failed to send reset code. Please try again.';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),

              // WEGO Logo
              const Center(child: WegoLogo()),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Reset Your Password',
                style: AppTextStyles.displaySmall,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                'Forgot your password? No worries! we\'ll send a reset link to your email.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Email Address Field
              WegoTextField(
                controller: emailCtrl,
                label: tr('auth.email'),
                hint: 'Enter your email',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: AppSpacing.xl - AppSpacing.sm),

              // Reset Password Button
              WegoPrimaryButton(
                text: 'Reset password',
                onPressed: _resetPassword,
                isLoading: loading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Error Message
              if (message != null)
                WegoMessageCard(
                  message: message!,
                  type: MessageType.error,
                ),

              const Spacer(),

              // Back to login
              Center(
                child: WegoBackButton(
                  text: 'Back to login screen',
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/auth/forgot_password_otp_screen.dart
class ForgotPasswordOtpScreen extends StatefulWidget {
  const ForgotPasswordOtpScreen({super.key});

  @override
  State<ForgotPasswordOtpScreen> createState() => _ForgotPasswordOtpScreenState();
}

class _ForgotPasswordOtpScreenState extends State<ForgotPasswordOtpScreen> {
  final List<TextEditingController> otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> otpFocusNodes = List.generate(6, (index) => FocusNode());
  bool loading = false;
  String? message;
  int resendCountdown = 0;
  Timer? countdownTimer;
  String email = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          email = args['email'] ?? '';
        });
      }
      startCountdown();
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var focusNode in otpFocusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void startCountdown() {
    setState(() {
      resendCountdown = 240; // 4 minutes
    });

    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (resendCountdown > 0) {
          resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onOtpChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      otpFocusNodes[index - 1].requestFocus();
    }

    // Check if all fields are filled
    if (otpControllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otp = otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      setState(() {
        message = 'Please enter the complete 6-digit code';
      });
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await AuthService().verifyResetOtp(email, otp);

      // Navigate to set new password screen
      if (mounted) {
        Navigator.pushNamed(
          context,
          '/forgot-password/new-password',
          arguments: {'email': email, 'otp': otp},
        );
      }

    } on AuthException catch (e) {
      setState(() {
        message = e.message;
      });
    } catch (e) {
      setState(() {
        message = 'Invalid code. Please try again.';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _resendOtp() async {
    if (resendCountdown > 0) return;

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await AuthService().forgotPassword(email);

      setState(() {
        message = 'Reset code resent successfully!';
      });

      startCountdown();

    } on AuthException catch (e) {
      setState(() {
        message = e.message;
      });
    } catch (e) {
      setState(() {
        message = 'Failed to resend code. Please try again.';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),

              // WEGO Logo
              const Center(child: WegoLogo()),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Reset Your Password',
                style: AppTextStyles.displaySmall,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                'Enter your 6-digit OTP code in order to reset. It will be sent to your email.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Email Address (readonly)
              WegoTextField(
                controller: TextEditingController(text: email),
                label: tr('auth.email'),
                readOnly: true,
                enabled: false,
              ),

              const SizedBox(height: AppSpacing.lg),

              // OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 45,
                    height: 50,
                    child: TextField(
                      controller: otpControllers[index],
                      focusNode: otpFocusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: AppTextStyles.headingMedium,
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: AppBorderRadius.medium,
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: AppBorderRadius.medium,
                          borderSide: const BorderSide(color: AppColors.borderPrimary),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppBorderRadius.medium,
                          borderSide: const BorderSide(color: AppColors.borderFocus, width: 2),
                        ),
                      ),
                      onChanged: (value) => _onOtpChanged(value, index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Error Message
              if (message != null)
                WegoMessageCard(
                  message: message!,
                  type: message!.contains('success')
                      ? MessageType.success
                      : MessageType.error,
                ),

              if (message != null)
                const SizedBox(height: AppSpacing.md),

              // Didn't receive code?
              Center(
                child: Text(
                  'Didn\'t receive the code?',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // Resend countdown or button
              Center(
                child: resendCountdown > 0
                    ? Text(
                  'Re-send OTP Code in ${formatTime(resendCountdown)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    : WegoTextButton(
                  text: 'Resend Code',
                  onPressed: loading ? null : _resendOtp,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Reset with phone number
              WegoSecondaryButton(
                text: 'Reset with phone number',
                icon: const Icon(Icons.phone, size: 20),
                onPressed: () {
                  // Navigate to phone reset option
                },
              ),

              const Spacer(),

              // Back to login
              Center(
                child: WegoBackButton(
                  text: 'Back to login screen',
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/screens/auth/set_new_password_screen.dart
class SetNewPasswordScreen extends StatefulWidget {
  const SetNewPasswordScreen({super.key});

  @override
  State<SetNewPasswordScreen> createState() => _SetNewPasswordScreenState();
}

class _SetNewPasswordScreenState extends State<SetNewPasswordScreen> {
  final passwordCtrl = TextEditingController();
  final confirmPasswordCtrl = TextEditingController();
  bool loading = false;
  String? message;
  String email = '';
  String otp = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          email = args['email'] ?? '';
          otp = args['otp'] ?? '';
        });
      }
    });
  }

  Future<void> _setNewPassword() async {
    if (passwordCtrl.text.trim().isEmpty) {
      setState(() {
        message = 'Please enter a new password';
      });
      return;
    }

    if (confirmPasswordCtrl.text.trim().isEmpty) {
      setState(() {
        message = 'Please confirm your password';
      });
      return;
    }

    if (passwordCtrl.text != confirmPasswordCtrl.text) {
      setState(() {
        message = 'Passwords do not match';
      });
      return;
    }

    if (passwordCtrl.text.length < 8) {
      setState(() {
        message = 'Password must be at least 8 characters';
      });
      return;
    }

    setState(() {
      loading = true;
      message = null;
    });

    try {
      await AuthService().resetPassword(email, otp, passwordCtrl.text);

      setState(() {
        message = 'Password reset successful!';
      });

      // Navigate back to login after success
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }

    } on AuthException catch (e) {
      setState(() {
        message = e.message;
      });
    } catch (e) {
      setState(() {
        message = 'Failed to reset password. Please try again.';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxxl + AppSpacing.lg),

              // WEGO Logo
              const Center(child: WegoLogo()),

              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Set a new password',
                style: AppTextStyles.displaySmall,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Subtitle
              Text(
                'The password must be different than before',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              // Password Field
              WegoTextField(
                controller: passwordCtrl,
                label: tr('auth.password'),
                hint: 'Enter new password',
                obscureText: true,
                showPasswordToggle: true,
              ),

              const SizedBox(height: AppSpacing.lg - AppSpacing.xs),

              // Confirm Password Field
              WegoTextField(
                controller: confirmPasswordCtrl,
                label: tr('signup.confirmPassword'),
                hint: 'Re-enter password',
                obscureText: true,
                showPasswordToggle: true,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Confirm Button
              WegoPrimaryButton(
                text: 'Confirm',
                onPressed: _setNewPassword,
                isLoading: loading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Message
              if (message != null)
                WegoMessageCard(
                  message: message!,
                  type: message!.contains('successful')
                      ? MessageType.success
                      : MessageType.error,
                ),

              const Spacer(),

              // Back to login
              Center(
                child: WegoBackButton(
                  text: 'Back to login screen',
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }
}