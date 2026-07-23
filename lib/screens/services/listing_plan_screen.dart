// lib/screens/services/listing_plan_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Listing Plan Screen
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';

import '../../models/listing_plan_model.dart';
import '../../providers/services.dart';
import '../../widgets/payment/payment_status_view.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kPrimaryLight = Color(0xFFFFFDE7);
const _kPrimaryMid   = Color(0xFFFFECB3);
Color get _kSurface => AppColors.backgroundWhite;
Color get _kPageBg => AppColors.backgroundLight;
Color get _kInputBg => AppColors.inputBackground;
Color get _kBorder => AppColors.borderLight;
Color get _kTextPrimary => AppColors.textPrimary;
Color get _kTextSecond => AppColors.textSecondary;
Color get _kTextLight => AppColors.textLight;
const _kError        = AppColors.error;
Color get _kErrorLight => AppColors.errorLight;
const _kSuccess      = AppColors.success;
Color get _kSuccessLight => AppColors.successLight;

const double _rLg   = 16.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
];
const List<BoxShadow> _kBottomShadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3)),
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class ListingPlanScreen extends StatefulWidget {
  const ListingPlanScreen({Key? key}) : super(key: key);

  @override
  State<ListingPlanScreen> createState() => _ListingPlanScreenState();
}

class _ListingPlanScreenState extends State<ListingPlanScreen> {
  bool              _loadingPlans = true;
  List<ListingPlan> _plans        = [];
  ListingPlan?      _selected;

  bool    _showPaymentSheet = false;
  bool    _initiating       = false;
  String  _phone            = '';
  String? _paymentError;

  bool    _polling   = false;
  int?    _listingId;
  Timer?  _pollTimer;
  int     _pollCount = 0;
  String? _pollError;
  static const int _maxPolls = 30;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // ── Load plans ────────────────────────────────────────────────────────────
  Future<void> _loadPlans() async {
    setState(() => _loadingPlans = true);
    final plans = await context.read<ServicesProvider>().fetchListingPlans();
    if (!mounted) return;
    setState(() {
      _plans        = plans;
      _loadingPlans = false;
      if (plans.isNotEmpty) {
        final free = plans.cast<ListingPlan?>().firstWhere(
              (p) => p!.isFree,
          orElse: () => null,
        );
        _selected = free ?? plans.first;
      }
    });
  }

  // ── Proceed ───────────────────────────────────────────────────────────────
  void _onProceed() {
    if (_selected == null) return;
    if (_selected!.isFree) {
      _goToPostScreen();
    } else {
      setState(() {
        _showPaymentSheet = true;
        _paymentError     = null;
        _phone            = '';
      });
    }
  }

  // Subscription is bought FIRST (here). Then the post form just creates the
  // listing under the plan's quota. Called for the free plan directly, and for
  // a paid plan only after its CamPay payment is confirmed.
  Future<void> _goToPostScreen() async {
    final result = await Navigator.pushNamed(
      context,
      '/services/post',
      arguments: <String, dynamic>{ 'plan': _selected },
    );

    if (!mounted) return;
    if (result is Map && (result['created'] == true || result['listingId'] is int)) {
      _showSuccessDialog(free: _selected!.isFree);
    }
  }

  // Paid plan: buy the provider subscription via CamPay, then poll until it is
  // active, then continue to the post form.
  Future<void> _submitPhone() async {
    final phone = _phone.trim();
    if (phone.length < 9) {
      setState(() => _paymentError = 'Veuillez saisir un numéro valide');
      return;
    }
    setState(() { _initiating = true; _paymentError = null; });

    final res = await context
        .read<ServicesProvider>()
        .initiateSubscriptionPayment(planId: _selected!.id, phone: phone);

    if (!mounted) return;
    setState(() => _initiating = false);

    if (res == null) {
      setState(() => _paymentError = 'Échec de l\'initiation du paiement. Réessayez.');
      return;
    }
    setState(() => _showPaymentSheet = false);
    _startSubscriptionPolling();
  }

  // Poll the provider's subscription until it becomes active (webhook confirms
  // the CamPay payment), then go create the listing.
  void _startSubscriptionPolling() {
    _pollCount = 0;
    setState(() { _polling = true; _pollError = null; });

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) { _pollTimer?.cancel(); return; }

      _pollCount++;
      if (_pollCount > _maxPolls) {
        _pollTimer?.cancel();
        setState(() {
          _polling   = false;
          _pollError = 'Confirmation expirée. Vérifiez votre historique de paiement.';
        });
        return;
      }

      final sub = await context.read<ServicesProvider>().getMySubscription();
      if (!mounted) return;

      if (sub != null && sub['active'] == true) {
        _pollTimer?.cancel();
        setState(() => _polling = false);
        await _goToPostScreen();
      }
    });
  }

  void _showSuccessDialog({required bool free}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_rXl)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 130, height: 130,
              child: Lottie.asset(
                kPaymentSuccessLottie,
                repeat: false,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.check_circle_rounded, size: 72, color: _kSuccess),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              free ? 'Annonce soumise !' : 'Paiement confirmé !',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              free
                  ? 'Votre annonce est en cours d\'examen et sera publiée sous 24 h.'
                  : 'Votre annonce est en cours d\'examen. Elle sera publiée une fois approuvée.',
              style: AppTypography.bodySmall.copyWith(color: _kTextSecond),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/services/my-listings',
                        (route) => route.isFirst,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: _kTextPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_rLg)),
                ),
                child: Text('Voir mes annonces',
                    style: AppTypography.buttonMedium),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _kError : _kSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _kPageBg,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildBody()),
                if (!_loadingPlans && _plans.isNotEmpty && !_polling)
                  _buildBottomBar(),
              ],
            ),
            if (_polling)   _buildPollingOverlay(),
            if (_showPaymentSheet) _buildPaymentSheet(),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: _kSurface,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_rounded,
                color: _kTextPrimary, size: 24),
          ),
          const SizedBox(width: 16),
          // FIX: Expanded so the subtitle never overflows past the right edge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choisir un plan', style: AppTypography.titleLarge),
                Text(
                  'Sélectionnez comment publier votre annonce',
                  style: AppTypography.bodySmall
                      .copyWith(color: _kTextSecond),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loadingPlans) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
            SizedBox(height: 16),
            Text('Chargement des plans…', style: AppTypography.bodySmall),
          ],
        ),
      );
    }

    if (_plans.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_outlined, size: 48, color: _kTextLight),
              const SizedBox(height: 16),
              Text('Aucun plan disponible', style: AppTypography.titleLarge),
              const SizedBox(height: 8),
              Text('Veuillez réessayer plus tard',
                  style: AppTypography.bodySmall.copyWith(color: _kTextSecond),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadPlans,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Réessayer'),
                style: TextButton.styleFrom(foregroundColor: _kPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        // Poll error banner
        if (_pollError != null) ...[
          _ErrorBanner(
            message: _pollError!,
            onDismiss: () => setState(() => _pollError = null),
          ),
          const SizedBox(height: 12),
        ],

        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: _kPrimaryLight,
            borderRadius: BorderRadius.circular(_rLg),
            border: Border.all(color: _kPrimaryMid),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 18, color: _kPrimaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Toutes les annonces sont examinées avant publication. '
                      'Choisissez le plan qui vous convient.',
                  style: AppTypography.bodySmall
                      .copyWith(color: _kPrimaryDark),
                ),
              ),
            ],
          ),
        ),

        // Plan cards
        ..._plans.map((plan) => _PlanCard(
          plan:     plan,
          selected: _selected?.id == plan.id,
          onTap:    () => setState(() => _selected = plan),
        )),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final plan = _selected;
    if (plan == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _kSurface,
        boxShadow: _kBottomShadow,
      ),
      child: Row(
        children: [
          // Price summary — fixed intrinsic width
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.isFree ? 'Gratuit' : '${plan.priceXaf} XAF',
                style: AppTypography.titleLarge
                    .copyWith(color: _kPrimary, fontSize: 20),
              ),
              // FIX: ConstrainedBox prevents the duration+label string from
              // overflowing into the Expanded button on narrow screens
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  '${plan.durationDays} j · ${plan.labelFr}',
                  style: AppTypography.labelSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // Proceed button — Expanded fills remaining width
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _onProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kPrimary,
                  foregroundColor: _kTextPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_rLg)),
                ),
                icon: Icon(
                  plan.isFree
                      ? Icons.arrow_forward_rounded
                      : Icons.payment_rounded,
                  size: 20,
                ),
                label: Text(
                  plan.isFree ? 'Continuer gratuitement' : 'Payer et continuer',
                  style: AppTypography.buttonMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Polling overlay ───────────────────────────────────────────────────────
  Widget _buildPollingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(_rXl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 130, height: 130,
                child: Lottie.asset(
                  kPaymentPendingLottie,
                  repeat: true,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const CircularProgressIndicator(
                      color: _kPrimary, strokeWidth: 3),
                ),
              ),
              const SizedBox(height: 12),
              Text('En attente du paiement',
                  style: AppTypography.titleLarge),
              const SizedBox(height: 10),
              Text(
                'Vérifiez votre téléphone et saisissez votre PIN pour confirmer le paiement.',
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cela peut prendre jusqu\'à 90 secondes.',
                style: AppTypography.labelSmall
                    .copyWith(color: _kTextLight),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  _pollTimer?.cancel();
                  setState(() {
                    _polling   = false;
                    _pollError =
                    'Paiement annulé. Vous pouvez réessayer à tout moment.';
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kError,
                  side: const BorderSide(color: _kError),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_rLg)),
                ),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Payment sheet ─────────────────────────────────────────────────────────
  Widget _buildPaymentSheet() {
    return GestureDetector(
      onTap: () => setState(() {
        _showPaymentSheet = false;
        _paymentError     = null;
      }),
      child: Container(
        color: Colors.black54,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // prevent tap-through
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_rXl)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _kBorder,
                        borderRadius: BorderRadius.circular(_rPill),
                      ),
                    ),
                  ),

                  Text('Payer le plan', style: AppTypography.titleLarge),
                  const SizedBox(height: 4),
                  // FIX: wrap plan description in Flexible so a long label
                  // doesn't overflow past the screen edge on 360 dp phones
                  Text(
                    '${_selected?.labelFr ?? ''} · ${_selected?.priceXaf ?? 0} XAF · ${_selected?.durationDays ?? 0} j',
                    style: AppTypography.bodySmall
                        .copyWith(color: _kTextSecond),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 20),

                  // Amount chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      // FIX: gold gradient with dark text (correct contrast)
                      gradient: const LinearGradient(
                        colors: [_kPrimary, _kPrimaryDark],
                      ),
                      borderRadius: BorderRadius.circular(_rLg),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Montant à payer',
                          style: AppTypography.labelSmall
                              .copyWith(color: _kTextPrimary),
                        ),
                        // FIX: Flexible so a large amount doesn't push label off
                        Flexible(
                          child: Text(
                            '${_selected?.priceXaf ?? 0} XAF',
                            style: TextStyle(
                              fontFamily: 'LeagueSpartan',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text('Numéro Mobile Money',
                      style: AppTypography.titleSmall),
                  const SizedBox(height: 8),

                  // Phone input
                  Container(
                    decoration: BoxDecoration(
                      color: _kInputBg,
                      borderRadius: BorderRadius.circular(_rLg),
                      border: Border.all(
                        color: _paymentError != null ? _kError : _kBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Flag + prefix — fixed intrinsic width
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: _kBorder),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🇨🇲',
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                '+237',
                                style: AppTypography.bodySmall.copyWith(
                                  color: _kTextPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // FIX: Expanded on the TextField so it fills
                        // remaining width without overflowing
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.phone,
                            autofocus: true,
                            style: AppTypography.bodyMedium
                                .copyWith(color: _kTextPrimary),
                            decoration: InputDecoration(
                              hintText: '6XX XXX XXX',
                              hintStyle: AppTypography.bodyMedium
                                  .copyWith(color: _kTextLight),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14),
                            ),
                            onChanged: (v) => setState(() {
                              _phone        = v;
                              _paymentError = null;
                            }),
                            onSubmitted: (_) => _submitPhone(),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_paymentError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _paymentError!,
                      style: AppTypography.labelSmall
                          .copyWith(color: _kError),
                    ),
                  ],

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 14, color: _kPrimary),
                      const SizedBox(width: 6),
                      // FIX: Flexible so this note wraps instead of overflowing
                      Flexible(
                        child: Text(
                          'MTN MoMo & Orange Money acceptés',
                          style: AppTypography.labelSmall
                              .copyWith(color: _kTextSecond),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Pay button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _initiating ? null : _submitPhone,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: _kTextPrimary,
                        disabledBackgroundColor: _kBorder,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(_rLg)),
                      ),
                      icon: _initiating
                          ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kTextPrimary,
                        ),
                      )
                          : const Icon(Icons.payment_rounded, size: 20),
                      label: Text(
                        'Payer ${_selected?.priceXaf ?? 0} XAF',
                        style: AppTypography.buttonMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _showPaymentSheet = false;
                        _paymentError     = null;
                      }),
                      child: Text(
                        'Annuler',
                        style: AppTypography.labelMedium
                            .copyWith(color: _kTextSecond),
                      ),
                    ),
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

// ─────────────────────────────────────────────────────────────────────────────
// PLAN CARD
// ─────────────────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final ListingPlan  plan;
  final bool         selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(_rXl),
          border: Border.all(
            color: selected ? _kPrimary : _kBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? _kCardShadow : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: radio + name + price ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated radio dot — fixed 22×22
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? _kPrimary : _kBorder,
                        width: 2,
                      ),
                      color: selected ? _kPrimary : Colors.transparent,
                    ),
                    child: selected
                        ? Icon(Icons.check_rounded,
                        // FIX: dark check on gold (correct contrast)
                        size: 13, color: AppColors.textPrimary)
                        : null,
                  ),

                  const SizedBox(width: 12),

                  // Plan name + badge — Expanded so it shrinks before price
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // FIX: Flexible so long plan names don't push
                            // the highlight badge off-screen
                            Flexible(
                              child: Text(
                                plan.labelFr,
                                style: AppTypography.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (plan.isHighlighted &&
                                plan.highlightLabelFr != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B35),
                                  borderRadius:
                                  BorderRadius.circular(_rPill),
                                ),
                                child: Text(
                                  plan.highlightLabelFr!,
                                  style: const TextStyle(
                                    fontFamily: 'LeagueSpartan',
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${plan.durationDays} jours de visibilité',
                          style: AppTypography.labelSmall,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Price — fixed intrinsic width, no Expanded
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // FIX: ConstrainedBox prevents very large price numbers
                      // from overflowing the card on 320 dp screens
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(
                          plan.isFree ? 'GRATUIT' : '${plan.priceXaf}',
                          style: AppTypography.titleLarge.copyWith(
                            color: _kPrimary,
                            fontSize: plan.isFree ? 16 : 22,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!plan.isFree)
                        Text(
                          'XAF',
                          style: AppTypography.labelSmall
                              .copyWith(color: _kPrimaryDark),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Divider(height: 1, color: _kBorder),

            // ── Feature chips ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (plan.descriptionFr != null &&
                      plan.descriptionFr!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        plan.descriptionFr!,
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FeatureChip(
                        icon: Icons.photo_library_outlined,
                        label: 'Max ${plan.maxPhotos} photos',
                      ),
                      _FeatureChip(
                        icon: Icons.visibility_rounded,
                        label: '${plan.durationDays}j visibilité',
                      ),
                      if (plan.isHeroPlacement)
                        const _FeatureChip(
                          icon: Icons.star_rounded,
                          label: 'Placement hero',
                          highlight: true,
                        ),
                      if (plan.boostPriority > 0)
                        _FeatureChip(
                          icon: Icons.rocket_launch_rounded,
                          label: 'Priorité boost',
                          highlight: plan.boostPriority > 1,
                        ),
                    ],
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

// ─────────────────────────────────────────────────────────────────────────────
// FEATURE CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     highlight;

  const _FeatureChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? _kPrimaryDark : _kTextSecond;
    final bg    = highlight ? _kPrimaryLight : _kInputBg;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(_rPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          // FIX: ConstrainedBox so a long feature label doesn't widen the chip
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: AppTypography.labelSmall.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String       message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kErrorLight,
        borderRadius: BorderRadius.circular(_rLg),
        border: Border.all(color: _kError.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: _kError),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySmall.copyWith(color: _kError),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            // FIX: explicit tap target size for the small × icon
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.close_rounded, size: 16, color: _kError),
            ),
          ),
        ],
      ),
    );
  }
}