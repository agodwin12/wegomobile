// lib/widgets/payment/payment_status_view.dart
// ─────────────────────────────────────────────────────────────────────────────
// Reusable CamPay pending / success widgets shared by every payment flow
// (driver top-up, delivery-agent top-up, rental, delivery booking, services).
//
//   PaymentPendingView  → shown while the CamPay charge is PENDING and we poll.
//   PaymentSuccessView  → plays the success Lottie once, then reveals a button
//                         (or auto-advances) to move to the next step.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

const String kPaymentSuccessLottie = 'assets/lottie/payment_success.json';

// ═══════════════════════════════════════════════════════════════════════
// PENDING
// ═══════════════════════════════════════════════════════════════════════

class PaymentPendingView extends StatelessWidget {
  final String  title;
  final String  message;
  final String? amountLabel;
  final Color   background;
  final Color   accent;
  final Color   titleColor;
  final Color   textColor;
  final VoidCallback? onCancel;

  const PaymentPendingView({
    super.key,
    this.title      = 'Confirm on your phone',
    this.message    = 'Check your phone and enter your Mobile Money PIN to confirm the payment. This screen updates automatically.',
    this.amountLabel,
    this.background  = const Color(0xFF0A0A0A),
    this.accent      = const Color(0xFFFF6B35),
    this.titleColor  = Colors.white,
    this.textColor   = const Color(0xFFA9A9A9),
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: background,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulsing phone + spinner
            SizedBox(
              width: 110, height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 110, height: 110,
                    child: CircularProgressIndicator(
                      color: accent, strokeWidth: 3,
                    ),
                  ),
                  Container(
                    width: 74, height: 74,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.phone_android_rounded, color: accent, size: 34),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(title, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 22, fontWeight: FontWeight.w800, color: titleColor)),
            if (amountLabel != null) ...[
              const SizedBox(height: 8),
              Text(amountLabel!, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 26, fontWeight: FontWeight.w800, color: accent)),
            ],
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Quicksand', fontSize: 13, height: 1.5, color: textColor, fontWeight: FontWeight.w500)),
            if (onCancel != null) ...[
              const SizedBox(height: 28),
              TextButton(
                onPressed: onCancel,
                child: Text('Cancel',
                  style: TextStyle(fontFamily: 'Quicksand', fontSize: 14, fontWeight: FontWeight.w700, color: textColor)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// SUCCESS
// ═══════════════════════════════════════════════════════════════════════

class PaymentSuccessView extends StatefulWidget {
  final String  title;
  final String? subtitle;
  final String  buttonLabel;
  final VoidCallback onContinue;
  final Color   background;
  final Color   titleColor;
  final Color   subtitleColor;
  final Color   buttonColor;
  final Color   buttonTextColor;

  /// When true, [onContinue] fires automatically ~0.6s after the animation
  /// finishes (no button shown). When false, a button is revealed instead.
  final bool autoContinue;

  const PaymentSuccessView({
    super.key,
    this.title        = 'Payment Successful',
    this.subtitle,
    this.buttonLabel  = 'Continue',
    required this.onContinue,
    this.background      = const Color(0xFF0A0A0A),
    this.titleColor      = Colors.white,
    this.subtitleColor   = const Color(0xFFA9A9A9),
    this.buttonColor     = const Color(0xFF4CAF50),
    this.buttonTextColor = Colors.white,
    this.autoContinue    = false,
  });

  @override
  State<PaymentSuccessView> createState() => _PaymentSuccessViewState();
}

class _PaymentSuccessViewState extends State<PaymentSuccessView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && !_finished) {
        _finished = true;
        if (widget.autoContinue) {
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) widget.onContinue();
          });
        } else if (mounted) {
          setState(() {}); // reveal the button
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.background,
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 190, height: 190,
              child: Lottie.asset(
                kPaymentSuccessLottie,
                controller: _ctrl,
                repeat: false,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _ctrl
                    ..duration = composition.duration
                    ..forward();
                },
                // If the asset ever fails to load, fall back to a static check.
                errorBuilder: (_, __, ___) => Icon(
                  Icons.check_circle_rounded, color: widget.buttonColor, size: 120),
              ),
            ),
            const SizedBox(height: 4),
            Text(widget.title, textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'LeagueSpartan', fontSize: 25, fontWeight: FontWeight.w800, color: widget.titleColor)),
            if (widget.subtitle != null) ...[
              const SizedBox(height: 8),
              Text(widget.subtitle!, textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Quicksand', fontSize: 14, height: 1.4, color: widget.subtitleColor, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 30),
            if (!widget.autoContinue)
              AnimatedOpacity(
                opacity: _finished ? 1 : 0,
                duration: const Duration(milliseconds: 350),
                child: IgnorePointer(
                  ignoring: !_finished,
                  child: GestureDetector(
                    onTap: widget.onContinue,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 15),
                      decoration: BoxDecoration(
                        color: widget.buttonColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(widget.buttonLabel,
                        style: TextStyle(fontFamily: 'Quicksand', fontSize: 15, fontWeight: FontWeight.w700, color: widget.buttonTextColor)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
