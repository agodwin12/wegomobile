// lib/screens/forgot_password/forgot_password_screen.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// FORGOT PASSWORD — single self-contained 3-step flow
// ═══════════════════════════════════════════════════════════════════════════
// The whole recovery journey lives behind ONE route ('/forgot-password') and
// moves between steps with an internal PageView. The previous version pushed
// named routes ('/forgot-password/otp', '/forgot-password/new-password') that
// were never registered in main.dart, so asking for a code silently bounced
// the user back to the login screen.
//
// Backend contract (src/controllers/passwordReset.controller.js):
//   POST /auth/forgot-password        { identifier }          → sends the code
//   POST /auth/reset-password/verify  { identifier, code }    → checks it
//   POST /auth/reset-password         { identifier, code, newPassword }
//
// `identifier` is an email OR a phone number — the server splits on '@' to
// pick the channel — so this screen lets the user choose either one.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../authentication service/api_services.dart';
import '../../l10n/tr.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';
import '../../widgets/phone/country_code_field.dart';

const Color _kCanvas = Color(0xFFF5F4F0);
const Color _kFieldBorder = Color(0xFFE8E6E0);

enum _Method { email, phone }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _pageCtrl = PageController();
  final _auth = AuthService();

  int _step = 0; // 0 = identify, 1 = code, 2 = new password
  bool _loading = false;
  bool _done = false;
  String? _error;
  String? _info;

  // Step 1
  _Method _method = _Method.email;
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  DialingCountry _country = kFrancophoneAfricaCountries.first;

  /// What we actually send to the API — an email or a full international number.
  String _identifier = '';

  // Step 2
  final List<TextEditingController> _otp =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  Timer? _timer;
  int _countdown = 0;

  // Step 3
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    for (final c in _otp) {
      c.dispose();
    }
    for (final f in _otpFocus) {
      f.dispose();
    }
    super.dispose();
  }

  // ── navigation ───────────────────────────────────────────────────────────

  void _goTo(int step) {
    setState(() {
      _step = step;
      _error = null;
      _info = null;
    });
    _pageCtrl.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
    } else {
      _goTo(_step - 1);
    }
  }

  // ── step 1: send the code ────────────────────────────────────────────────

  Future<void> _sendCode() async {
    final identifier = _buildIdentifier();
    if (identifier == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await _auth.forgotPassword(identifier);
      _identifier = identifier;
      for (final c in _otp) {
        c.clear();
      }
      _startCountdown();
      if (!mounted) return;
      _goTo(1);
      _otpFocus.first.requestFocus();
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('fp.sendFailed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Validates the active field and returns the value to send, or null (and
  /// sets `_error`) when it is not usable.
  String? _buildIdentifier() {
    if (_method == _Method.email) {
      final email = _emailCtrl.text.trim();
      if (email.isEmpty) {
        setState(() => _error = tr('fp.emailRequired'));
        return null;
      }
      final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(email);
      if (!ok) {
        setState(() => _error = tr('fp.emailInvalid'));
        return null;
      }
      return email;
    }

    final local = _phoneCtrl.text.trim();
    if (local.isEmpty) {
      setState(() => _error = tr('fp.phoneRequired'));
      return null;
    }
    final full = buildInternationalNumber(_country, local);
    // dial code + at least 8 subscriber digits
    if (full.length < _country.dialCode.length + 8) {
      setState(() => _error = tr('fp.phoneInvalid'));
      return null;
    }
    return full;
  }

  /// Hides most of the identifier so the user can confirm it without the whole
  /// address being readable over their shoulder.
  String get _maskedTarget {
    if (_identifier.contains('@')) {
      final parts = _identifier.split('@');
      final name = parts.first;
      final head = name.isEmpty ? '' : name[0];
      return '$head•••@${parts.last}';
    }
    if (_identifier.length < 4) return _identifier;
    return '+${_identifier.substring(0, _identifier.length - 6)}'
        '•••• ${_identifier.substring(_identifier.length - 2)}';
  }

  // ── step 2: the code ─────────────────────────────────────────────────────

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _countdown = 240); // 4 minutes, matches the OTP TTL
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          t.cancel();
        }
      });
    });
  }

  String get _countdownLabel {
    final m = _countdown ~/ 60;
    final s = (_countdown % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _code => _otp.map((c) => c.text).join();

  void _onOtpChanged(String value, int index) {
    setState(() => _error = null);

    // Support pasting the whole code into any box.
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var i = 0; i < 6; i++) {
        _otp[i].text = i < digits.length ? digits[i] : '';
      }
      FocusScope.of(context).unfocus();
      if (digits.length >= 6) _verifyCode();
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }

    if (_code.length == 6) {
      FocusScope.of(context).unfocus();
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length != 6) {
      setState(() => _error = tr('fp.codeIncomplete'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await _auth.verifyResetOtp(_identifier, _code);
      if (!mounted) return;
      _goTo(2);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('fp.codeInvalid'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_countdown > 0 || _loading) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    try {
      await _auth.forgotPassword(_identifier);
      _startCountdown();
      setState(() => _info = tr('fp.resent'));
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('fp.resendFailed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── step 3: the new password ─────────────────────────────────────────────

  // Mirrors the server rules exactly, so the checklist can never disagree
  // with the error the API would return.
  bool get _has8 => _passwordCtrl.text.length >= 8;
  bool get _hasLower => RegExp(r'[a-z]').hasMatch(_passwordCtrl.text);
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_passwordCtrl.text);
  bool get _hasDigit => RegExp(r'[0-9]').hasMatch(_passwordCtrl.text);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(_passwordCtrl.text);

  int get _strength =>
      [_has8, _hasLower, _hasUpper, _hasDigit, _hasSpecial].where((v) => v).length;

  bool get _passwordValid => _strength == 5;
  bool get _passwordsMatch =>
      _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _passwordCtrl.text;

  Future<void> _submitPassword() async {
    if (!_passwordValid) return;
    if (!_passwordsMatch) {
      setState(() => _error = tr('fp.mismatch'));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.resetPassword(_identifier, _code, _passwordCtrl.text);
      _timer?.cancel();
      if (!mounted) return;
      setState(() => _done = true);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('fp.resetFailed'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_done) return _SuccessView(onDone: () => Navigator.pop(context));

    return Scaffold(
      backgroundColor: _kCanvas,
      body: Column(
        children: [
          _Header(step: _step, onBack: _back),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildIdentifyStep(),
                _buildCodeStep(),
                _buildPasswordStep(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody({required String title, required String subtitle, required List<Widget> children}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.primaryFont,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 28),
          ...children,
          if (_error != null) ...[
            const SizedBox(height: 16),
            _Banner(message: _error!, isError: true),
          ],
          if (_info != null) ...[
            const SizedBox(height: 16),
            _Banner(message: _info!, isError: false),
          ],
        ],
      ),
    );
  }

  // ── step 1 UI ────────────────────────────────────────────────────────────

  Widget _buildIdentifyStep() {
    return _stepBody(
      title: tr('fp.step1Title'),
      subtitle: tr('fp.step1Sub'),
      children: [
        _MethodToggle(
          method: _method,
          onChanged: (m) => setState(() {
            _method = m;
            _error = null;
          }),
        ),
        const SizedBox(height: 24),
        if (_method == _Method.email)
          _LabelledField(
            label: tr('fp.emailLabel'),
            child: _StyledField(
              controller: _emailCtrl,
              hint: tr('fp.emailHint'),
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() => _error = null),
            ),
          )
        else
          _LabelledField(
            label: tr('fp.phoneLabel'),
            child: CountryCodePhoneField(
              controller: _phoneCtrl,
              country: _country,
              hint: tr('fp.phoneHint'),
              onCountryChanged: (c) => setState(() => _country = c),
              onChanged: () => setState(() => _error = null),
            ),
          ),
        const SizedBox(height: 28),
        _GoldButton(
          label: tr('fp.sendCode'),
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  // ── step 2 UI ────────────────────────────────────────────────────────────

  Widget _buildCodeStep() {
    return _stepBody(
      title: tr('fp.step2Title'),
      subtitle: tr('fp.step2Sub', {'target': _maskedTarget}),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _goTo(0),
            icon: Icon(Icons.edit_rounded, size: 15, color: AppColors.textSecondary),
            label: Text(
              tr('fp.changeTarget'),
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => _OtpBox(
                controller: _otp[i],
                focusNode: _otpFocus[i],
                onChanged: (v) => _onOtpChanged(v, i),
              )),
        ),
        const SizedBox(height: 28),
        _GoldButton(
          label: tr('fp.verify'),
          loading: _loading,
          onPressed: _verifyCode,
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            tr('fp.noCode'),
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: _countdown > 0
              ? Text(
                  tr('fp.resendIn', {'time': _countdownLabel}),
                  style: TextStyle(
                    fontFamily: AppTypography.secondaryFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                )
              : TextButton(
                  onPressed: _loading ? null : _resend,
                  child: Text(
                    tr('fp.resend'),
                    style: const TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGoldDark,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ── step 3 UI ────────────────────────────────────────────────────────────

  Widget _buildPasswordStep() {
    return _stepBody(
      title: tr('fp.step3Title'),
      subtitle: tr('fp.step3Sub'),
      children: [
        _LabelledField(
          label: tr('fp.newPassword'),
          child: _StyledField(
            controller: _passwordCtrl,
            hint: tr('fp.newPasswordHint'),
            icon: Icons.lock_outline_rounded,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
            onChanged: (_) => setState(() => _error = null),
          ),
        ),
        const SizedBox(height: 14),
        _StrengthBar(strength: _strength),
        const SizedBox(height: 18),
        _Requirements(
          items: [
            (tr('fp.req8'), _has8),
            (tr('fp.reqLower'), _hasLower),
            (tr('fp.reqUpper'), _hasUpper),
            (tr('fp.reqDigit'), _hasDigit),
            (tr('fp.reqSpecial'), _hasSpecial),
          ],
        ),
        const SizedBox(height: 22),
        _LabelledField(
          label: tr('fp.confirmPassword'),
          child: _StyledField(
            controller: _confirmCtrl,
            hint: tr('fp.confirmHint'),
            icon: Icons.lock_reset_rounded,
            obscure: _obscureConfirm,
            onToggleObscure: () =>
                setState(() => _obscureConfirm = !_obscureConfirm),
            onChanged: (_) => setState(() => _error = null),
            trailing: _confirmCtrl.text.isEmpty
                ? null
                : Icon(
                    _passwordsMatch
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    size: 18,
                    color: _passwordsMatch ? AppColors.success : AppColors.error,
                  ),
          ),
        ),
        const SizedBox(height: 28),
        _GoldButton(
          label: tr('fp.confirmReset'),
          loading: _loading,
          enabled: _passwordValid && _passwordsMatch,
          onPressed: _submitPassword,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER — dark curved banner with the step progress
// ═══════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  final int step;
  final VoidCallback onBack;

  const _Header({required this.step, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurveClipper(),
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8),
        height: MediaQuery.of(context).padding.top + 168,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              Color.lerp(AppColors.primaryDark, Colors.black, 0.5)!,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                ),
                Text(
                  tr('fp.title'),
                  style: const TextStyle(
                    fontFamily: AppTypography.primaryFont,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('fp.stepOf', {'n': '${step + 1}'}),
                    style: const TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: AppColors.primaryGold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(3, (i) {
                      final reached = i <= step;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 4,
                          margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                          decoration: BoxDecoration(
                            color: reached
                                ? AppColors.primaryGold
                                : Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..lineTo(0, size.height - 26)
      ..quadraticBezierTo(
          size.width / 2, size.height + 14, size.width, size.height - 26)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// SMALL PIECES
// ═══════════════════════════════════════════════════════════════════════════

class _MethodToggle extends StatelessWidget {
  final _Method method;
  final ValueChanged<_Method> onChanged;

  const _MethodToggle({required this.method, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDECEA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _tab(_Method.email, Icons.mail_outline_rounded, tr('fp.byEmail')),
          _tab(_Method.phone, Icons.phone_iphone_rounded, tr('fp.byPhone')),
        ],
      ),
    );
  }

  Widget _tab(_Method value, IconData icon, String label) {
    final selected = method == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabelledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTypography.secondaryFont,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _StyledField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
  final Widget? trailing;

  const _StyledField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
    this.trailing,
  });

  @override
  State<_StyledField> createState() => _StyledFieldState();
}

class _StyledFieldState extends State<_StyledField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _focused ? AppColors.primaryGold : _kFieldBorder,
          width: _focused ? 1.6 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(
              widget.icon,
              size: 19,
              color: _focused ? AppColors.primaryGoldDark : AppColors.textLight,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              keyboardType: widget.keyboardType,
              obscureText: widget.obscure,
              onChanged: widget.onChanged,
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textLight,
                ),
              ),
            ),
          ),
          if (widget.trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: widget.trailing,
            ),
          if (widget.onToggleObscure != null)
            IconButton(
              onPressed: widget.onToggleObscure,
              icon: Icon(
                widget.obscure
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 19,
                color: AppColors.textLight,
              ),
            ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final filled = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 48,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              ? AppColors.primaryGold
              : filled
                  ? AppColors.primaryGoldDark.withOpacity(0.45)
                  : _kFieldBorder,
          width: focused ? 1.8 : 1,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.primaryGold.withOpacity(0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Center(
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontFamily: AppTypography.primaryFont,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}

class _StrengthBar extends StatelessWidget {
  final int strength; // 0..5

  const _StrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (strength) {
      0 || 1 || 2 => (AppColors.error, tr('fp.strengthWeak')),
      3 || 4 => (AppColors.warning, tr('fp.strengthMedium')),
      _ => (AppColors.success, tr('fp.strengthStrong')),
    };

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(5, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 5,
                  margin: EdgeInsets.only(right: i == 4 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i < strength ? color : const Color(0xFFE4E2DE),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
        if (strength > 0) ...[
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ],
    );
  }
}

class _Requirements extends StatelessWidget {
  final List<(String, bool)> items;

  const _Requirements({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kFieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('fp.reqTitle'),
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          ...items.map((item) {
            final (label, ok) = item;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      color: ok ? AppColors.success : const Color(0xFFEDECEA),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ok ? Icons.check_rounded : Icons.close_rounded,
                      size: 11,
                      color: ok ? Colors.white : AppColors.textLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: AppTypography.secondaryFont,
                      fontSize: 12.5,
                      fontWeight: ok ? FontWeight.w600 : FontWeight.w400,
                      color: ok ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  final String label;
  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading;

    return GestureDetector(
      onTap: active ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 54,
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  colors: [AppColors.primaryGold, AppColors.primaryGoldDark],
                )
              : null,
          color: active ? null : const Color(0xFFE4E2DE),
          borderRadius: BorderRadius.circular(15),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                  ),
                )
              : Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTypography.primaryFont,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primaryDark : AppColors.textLight,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;

  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUCCESS
// ═══════════════════════════════════════════════════════════════════════════

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;

  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 520),
                curve: Curves.elasticOut,
                builder: (context, value, child) =>
                    Transform.scale(scale: value, child: child),
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryGold, AppColors.primaryGoldDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGold.withOpacity(0.4),
                        blurRadius: 26,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 52, color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                tr('fp.successTitle'),
                style: TextStyle(
                  fontFamily: AppTypography.primaryFont,
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr('fp.successSub'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: _GoldButton(
                  label: tr('fp.backToLogin'),
                  onPressed: onDone,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
