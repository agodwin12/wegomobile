// lib/screens/profile/change_password_screen.dart
// WEGO - Change Password Screen
// Allows users to change their password securely

import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({Key? key}) : super(key: key);

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Password visibility
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;

  // Password requirements
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigit = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_updatePasswordStrength);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Change Password',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header
                _buildHeader(),

                const SizedBox(height: 32),

                // Current Password
                _buildPasswordField(
                  controller: _currentPasswordController,
                  label: tr('pwd.current'),
                  showPassword: _showCurrentPassword,
                  onToggleVisibility: () {
                    setState(() => _showCurrentPassword = !_showCurrentPassword);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr('val.currentPwdRequired');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // New Password
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: tr('pwd.new'),
                  showPassword: _showNewPassword,
                  onToggleVisibility: () {
                    setState(() => _showNewPassword = !_showNewPassword);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr('val.newPwdRequired');
                    }
                    if (value == _currentPasswordController.text) {
                      return tr('val.pwdMustDiffer');
                    }
                    if (value.length < 8) {
                      return tr('val.pwdMin8');
                    }
                    if (!_hasUppercase || !_hasLowercase || !_hasDigit || !_hasSpecialChar) {
                      return tr('val.pwdRequirements');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // Password Strength Indicator
                _buildPasswordStrengthIndicator(),

                const SizedBox(height: 24),

                // Confirm Password
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: tr('pwd.confirmNew'),
                  showPassword: _showConfirmPassword,
                  onToggleVisibility: () {
                    setState(() => _showConfirmPassword = !_showConfirmPassword);
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return tr('val.confirmPwdRequired');
                    }
                    if (value != _newPasswordController.text) {
                      return tr('fp.mismatch');
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Password Requirements
                _buildPasswordRequirements(),

                const SizedBox(height: 32),

                // Error Display
                if (provider.hasError)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            provider.error ?? 'An error occurred',
                            style: TextStyle(
                              color: Colors.red[700],
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: provider.isUpdating ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDC71),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: provider.isUpdating
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                        : Text(
                      'Change Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFDC71).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFDC71).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDC71),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock,
                  color: Colors.black,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keep Your Account Safe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Use a strong password to protect your account',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASSWORD FIELD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !showPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFFFDC71)),
        suffixIcon: IconButton(
          icon: Icon(
            showPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey[600],
          ),
          onPressed: onToggleVisibility,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFFDC71), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: validator,
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASSWORD STRENGTH INDICATOR
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPasswordStrengthIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              _passwordStrengthText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _passwordStrengthColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _passwordStrength,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(_passwordStrengthColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASSWORD REQUIREMENTS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          _buildRequirementItem('At least 8 characters', _hasMinLength),
          _buildRequirementItem('One uppercase letter', _hasUppercase),
          _buildRequirementItem('One lowercase letter', _hasLowercase),
          _buildRequirementItem('One number', _hasDigit),
          _buildRequirementItem('One special character (!@#\$%^&*)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: isMet ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: isMet ? Colors.green : Colors.grey[600],
              fontWeight: isMet ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // PASSWORD STRENGTH CALCULATION
  // ═══════════════════════════════════════════════════════════════════

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;

    // Reset requirements
    _hasMinLength = password.length >= 8;
    _hasUppercase = password.contains(RegExp(r'[A-Z]'));
    _hasLowercase = password.contains(RegExp(r'[a-z]'));
    _hasDigit = password.contains(RegExp(r'[0-9]'));
    _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    // Calculate strength
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUppercase) strength++;
    if (_hasLowercase) strength++;
    if (_hasDigit) strength++;
    if (_hasSpecialChar) strength++;

    // Bonus for longer passwords
    if (password.length >= 12) strength++;
    if (password.length >= 16) strength++;

    // Convert to 0-1 scale
    _passwordStrength = strength / 7;

    // Determine strength text and color
    if (_passwordStrength < 0.3) {
      _passwordStrengthText = 'Weak';
      _passwordStrengthColor = Colors.red;
    } else if (_passwordStrength < 0.5) {
      _passwordStrengthText = 'Fair';
      _passwordStrengthColor = Colors.orange;
    } else if (_passwordStrength < 0.7) {
      _passwordStrengthText = 'Good';
      _passwordStrengthColor = const Color(0xFFFFDC71);
    } else {
      _passwordStrengthText = 'Strong';
      _passwordStrengthColor = Colors.green;
    }

    setState(() {});
  }

  // ═══════════════════════════════════════════════════════════════════
  // CHANGE PASSWORD
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _changePassword() async {
    // Clear any existing errors
    final provider = context.read<ProfileProvider>();
    provider.clearError();

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Change password
    final success = await provider.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (success && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('pwd.changed')),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Wait a moment then go back
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        Navigator.pop(context);
      }
    }
    // Error is already displayed in the UI via provider.error
  }
}
