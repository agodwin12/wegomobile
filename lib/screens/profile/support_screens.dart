// lib/screens/profile/support_screens.dart
//
// ═══════════════════════════════════════════════════════════════════════════
// CONTACT SUPPORT  +  REPORT A PROBLEM
// ═══════════════════════════════════════════════════════════════════════════
// Both routes used to render a "Coming Soon" placeholder even though the
// backend has had working endpoints all along (POST /support/contact and
// POST /support/report). These screens speak that contract exactly, and mirror
// the server's length rules in the UI so a user never gets rejected after
// typing a long message.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../service/support_api.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

const Color _kCanvas = Color(0xFFF5F4F0);
const Color _kBorder = Color(0xFFE8E6E0);

// ═══════════════════════════════════════════════════════════════════════════
// CONTACT SUPPORT
// ═══════════════════════════════════════════════════════════════════════════

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  static const _categories = [
    ('general', Icons.chat_bubble_outline_rounded),
    ('account', Icons.person_outline_rounded),
    ('payment', Icons.payments_outlined),
    ('rides', Icons.local_taxi_outlined),
    ('services', Icons.storefront_outlined),
    ('technical', Icons.build_outlined),
    ('other', Icons.more_horiz_rounded),
  ];

  static const _priorities = ['low', 'medium', 'high', 'urgent'];

  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  String _category = 'general';
  String _priority = 'medium';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  // Server rules: subject 5-200, message 20-2000.
  bool get _subjectOk => _subjectCtrl.text.trim().length >= 5;
  bool get _messageOk => _messageCtrl.text.trim().length >= 20;
  bool get _canSend => _subjectOk && _messageOk && !_sending;

  Future<void> _send() async {
    if (!_subjectOk) {
      setState(() => _error = tr('sup.subjectTooShort'));
      return;
    }
    if (!_messageOk) {
      setState(() => _error = tr('sup.messageTooShort'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final ref = await SupportApi.createTicket(
        subject: _subjectCtrl.text.trim(),
        message: _messageCtrl.text.trim(),
        category: _category,
        priority: _priority,
      );
      if (!mounted) return;
      await showSupportSuccessSheet(
        context,
        title: tr('sup.sent'),
        subtitle: tr('sup.sentSub'),
        reference: ref == null ? null : tr('sup.sentRef', {'ref': ref}),
      );
      if (mounted) Navigator.pop(context);
    } on SupportException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('sup.failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: buildSupportAppBar(context, tr('sup.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Intro(icon: Icons.support_agent_rounded, text: tr('sup.sub')),
          const SizedBox(height: 24),

          _SectionLabel(tr('sup.category')),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final (value, icon) = c;
              return _ChoiceChip(
                label: tr('sup.cat.$value'),
                icon: icon,
                selected: _category == value,
                onTap: () => setState(() => _category = value),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _SectionLabel(tr('sup.priority')),
          const SizedBox(height: 10),
          Row(
            children: _priorities.map((p) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: p == 'urgent' ? 0 : 8),
                  child: _PriorityPill(
                    label: tr('sup.pri.$p'),
                    color: _priorityColor(p),
                    selected: _priority == p,
                    onTap: () => setState(() => _priority = p),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          _SectionLabel(tr('sup.subject')),
          const SizedBox(height: 10),
          _Field(
            controller: _subjectCtrl,
            hint: tr('sup.subjectHint'),
            maxLength: 200,
            minLength: 5,
            onChanged: () => setState(() => _error = null),
          ),
          const SizedBox(height: 20),

          _SectionLabel(tr('sup.message')),
          const SizedBox(height: 10),
          _Field(
            controller: _messageCtrl,
            hint: tr('sup.messageHint'),
            maxLength: 2000,
            minLength: 20,
            maxLines: 7,
            onChanged: () => setState(() => _error = null),
          ),

          if (_error != null) ...[
            const SizedBox(height: 18),
            _ErrorBanner(_error!),
          ],

          const SizedBox(height: 28),
          _SubmitButton(
            label: tr('sup.send'),
            icon: Icons.send_rounded,
            enabled: _canSend,
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }

  Color _priorityColor(String p) => switch (p) {
        'low' => AppColors.info,
        'medium' => AppColors.success,
        'high' => AppColors.warning,
        _ => AppColors.error,
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// REPORT A PROBLEM
// ═══════════════════════════════════════════════════════════════════════════

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  static const _types = [
    ('app_crash', Icons.error_outline_rounded),
    ('payment_issue', Icons.credit_card_off_rounded),
    ('login_problem', Icons.lock_outline_rounded),
    ('feature_not_working', Icons.bug_report_outlined),
    ('other', Icons.more_horiz_rounded),
  ];

  final _descCtrl = TextEditingController();
  String? _type;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _descOk => _descCtrl.text.trim().length >= 20;
  bool get _canSend => _type != null && _descOk && !_sending;

  Future<void> _send() async {
    if (_type == null) {
      setState(() => _error = tr('rep.typeRequired'));
      return;
    }
    if (!_descOk) {
      setState(() => _error = tr('rep.descTooShort'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      final ref = await SupportApi.reportProblem(
        problemType: _type!,
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      await showSupportSuccessSheet(
        context,
        title: tr('rep.sent'),
        subtitle: tr('rep.sentSub'),
        reference: ref == null ? null : tr('sup.sentRef', {'ref': ref}),
      );
      if (mounted) Navigator.pop(context);
    } on SupportException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = tr('rep.failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kCanvas,
      appBar: buildSupportAppBar(context, tr('rep.title')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _Intro(icon: Icons.bug_report_rounded, text: tr('rep.sub')),
          const SizedBox(height: 24),

          _SectionLabel(tr('rep.type')),
          const SizedBox(height: 10),
          ..._types.map((t) {
            final (value, icon) = t;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _TypeRow(
                label: tr('rep.t.$value'),
                icon: icon,
                selected: _type == value,
                onTap: () => setState(() {
                  _type = value;
                  _error = null;
                }),
              ),
            );
          }),
          const SizedBox(height: 20),

          _SectionLabel(tr('rep.description')),
          const SizedBox(height: 10),
          _Field(
            controller: _descCtrl,
            hint: tr('rep.descHint'),
            maxLength: 2000,
            minLength: 20,
            maxLines: 8,
            onChanged: () => setState(() => _error = null),
          ),

          if (_error != null) ...[
            const SizedBox(height: 18),
            _ErrorBanner(_error!),
          ],

          const SizedBox(height: 28),
          _SubmitButton(
            label: tr('rep.send'),
            icon: Icons.send_rounded,
            enabled: _canSend,
            loading: _sending,
            onPressed: _send,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED PIECES
// ═══════════════════════════════════════════════════════════════════════════

PreferredSizeWidget buildSupportAppBar(BuildContext context, String title) {
  return AppBar(
    backgroundColor: AppColors.primaryDark,
    elevation: 0,
    centerTitle: false,
    leading: IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
    ),
    title: Text(
      title,
      style: const TextStyle(
        fontFamily: AppTypography.primaryFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
  );
}

/// Success confirmation shown as a bottom sheet before popping the form.
Future<void> showSupportSuccessSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  String? reference,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 480),
            curve: Curves.elasticOut,
            builder: (context, v, child) =>
                Transform.scale(scale: v, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.primaryGold, AppColors.primaryGoldDark],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.38),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.check_rounded,
                  size: 40, color: AppColors.primaryDark),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTypography.primaryFont,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 13.5,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (reference != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _kCanvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kBorder),
              ),
              child: Text(
                reference,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: _SubmitButton(
              label: tr('common.close'),
              enabled: true,
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Intro extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Intro({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.32)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.primaryGold,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 21, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 13.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: AppTypography.secondaryFont,
        fontSize: 12.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryDark : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primaryDark : _kBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primaryGold : AppColors.textSecondary),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityPill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.14) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : _kBorder),
        ),
        child: Column(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? color : AppColors.textLight,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TypeRow({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryGold : _kBorder,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.16),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 19,
                color:
                    selected ? AppColors.primaryGoldDark : AppColors.textLight),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: AppTypography.secondaryFont,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primaryGold : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primaryGold : AppColors.borderMedium,
                  width: 1.6,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: AppColors.primaryDark)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLength;
  final int minLength;
  final int maxLines;
  final VoidCallback onChanged;

  const _Field({
    required this.controller,
    required this.hint,
    required this.maxLength,
    required this.minLength,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
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
    final length = widget.controller.text.trim().length;
    final ok = length >= widget.minLength;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _focused ? AppColors.primaryGold : _kBorder,
              width: _focused ? 1.6 : 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            onChanged: (_) {
              setState(() {});
              widget.onChanged();
            },
            style: TextStyle(
              fontFamily: AppTypography.secondaryFont,
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 14,
                height: 1.45,
                color: AppColors.textLight,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$length / ${widget.maxLength}',
          style: TextStyle(
            fontFamily: AppTypography.secondaryFont,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: ok ? AppColors.success : AppColors.textLight,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withOpacity(0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: AppTypography.secondaryFont,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.enabled,
    required this.onPressed,
    this.icon,
    this.loading = false,
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
                    color: AppColors.primaryGold.withOpacity(0.32),
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
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon,
                          size: 18,
                          color: active
                              ? AppColors.primaryDark
                              : AppColors.textLight),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      label,
                      style: TextStyle(
                        fontFamily: AppTypography.primaryFont,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color:
                            active ? AppColors.primaryDark : AppColors.textLight,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
