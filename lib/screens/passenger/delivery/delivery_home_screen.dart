// lib/presentation/screens/passenger/delivery/delivery_home_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../utils/app_colors.dart';
import '../../../../utils/app_typography.dart';
import '../../../../core/config.dart';
import 'delivery booking/delivery_location_selector.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with TickerProviderStateMixin {

  late AnimationController _pageController;
  late AnimationController _cardController;
  late Animation<double> _pageFade;
  late Animation<Offset> _pageSlide;
  late Animation<double> _card1Scale;
  late Animation<double> _card2Scale;

  // Surcharge fetched from backend — null until loaded
  bool    _loadingSurcharge   = true;
  String? _surchargeLabel;     // e.g. "+15%" — set only if surcharge > 0
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSurchargeInfo();
  }

  void _initAnimations() {
    _pageController = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _cardController = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);

    _pageFade  = CurvedAnimation(parent: _pageController, curve: Curves.easeOut);
    _pageSlide = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageController, curve: Curves.easeOutCubic));

    _card1Scale = Tween<double>(begin: 0.93, end: 1.0).animate(
        CurvedAnimation(parent: _cardController,
            curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
    _card2Scale = Tween<double>(begin: 0.93, end: 1.0).animate(
        CurvedAnimation(parent: _cardController,
            curve: const Interval(0.2, 0.8, curve: Curves.easeOutBack)));

    _pageController.forward();
    Future.delayed(const Duration(milliseconds: 100),
            () { if (mounted) _cardController.forward(); });
  }

  // ── Fetch express surcharge % from the backend ────────────────────────────
  //
  // We call /deliveries/estimate with a dummy short route and compare the
  // regular vs express total. This reveals the exact surcharge the backoffice
  // has configured — nothing is hardcoded in the UI.
  //
  // If the call fails or surcharge is 0, the badge simply doesn't appear.
  //
  Future<void> _loadSurchargeInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      if (_accessToken == null) {
        if (mounted) setState(() => _loadingSurcharge = false);
        return;
      }

      // Two parallel calls — regular and express — same dummy route
      final params = {
        'pickup_lat':  '4.0511',
        'pickup_lng':  '9.7679',
        'dropoff_lat': '4.0611',
        'dropoff_lng': '9.7779',
        'package_size': 'small',
      };

      final headers = {'Authorization': 'Bearer $_accessToken'};

      final results = await Future.wait([
        http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/deliveries/estimate')
              .replace(queryParameters: {...params, 'delivery_type': 'regular'}),
          headers: headers,
        ).timeout(const Duration(seconds: 12)),
        http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/deliveries/estimate')
              .replace(queryParameters: {...params, 'delivery_type': 'express'}),
          headers: headers,
        ).timeout(const Duration(seconds: 12)),
      ]);

      if (results[0].statusCode == 200 && results[1].statusCode == 200) {
        final regular = jsonDecode(results[0].body)['estimate'];
        final express = jsonDecode(results[1].body)['estimate'];

        final regularTotal  = (regular['totalPrice']       as num?)?.toDouble() ?? 0;
        final expressTotal  = (express['totalPrice']       as num?)?.toDouble() ?? 0;
        final surchargeXAF  = (express['expressSurcharge'] as num?)?.toDouble() ?? 0;

        if (regularTotal > 0 && surchargeXAF > 0) {
          final pct = (surchargeXAF / regularTotal * 100).round();
          if (mounted) {
            setState(() {
              _surchargeLabel   = '+$pct%';
              _loadingSurcharge = false;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Swallow — badge simply won't show if backend is unreachable
    }

    if (mounted) setState(() => _loadingSurcharge = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _selectType(String type) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DeliveryStep1Location(
        deliveryType: type,
        accessToken:  _accessToken ?? '',
      ),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _pageFade,
        child: SlideTransition(
          position: _pageSlide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),
                    _buildSubtitle(),
                    const SizedBox(height: 32),
                    _buildRegularCard(),
                    const SizedBox(height: 16),
                    _buildExpressCard(),
                    const SizedBox(height: 32),
                    _buildInfoBanner(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── App bar ────────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 130,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send a Package',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.3,
                )),
            const SizedBox(height: 2),
            Text('Choose your delivery type',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                )),
          ],
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
            ),
          ),
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 40, right: 20),
              child: Icon(Icons.local_shipping_rounded,
                  size: 64,
                  color: AppColors.primaryGold.withOpacity(0.12)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text('How would you like to track your delivery?',
        style: AppTypography.bodyMedium.copyWith(
            color: AppColors.darkTextSecondary, fontSize: 14));
  }

  // ── Regular card ───────────────────────────────────────────────────────────

  Widget _buildRegularCard() {
    return ScaleTransition(
      scale: _card1Scale,
      child: GestureDetector(
        onTap: () => _selectType('regular'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.darkBorder),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: AppColors.primaryGold, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Regular',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.darkTextPrimary,
                                letterSpacing: -0.3,
                              )),
                          const SizedBox(height: 3),
                          Text('Reliable delivery, step by step',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                color: AppColors.darkTextSecondary,
                              )),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: AppColors.textLight),
                  ],
                ),
              ),

              // Description + features
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Track your delivery through clear status updates. '
                          'Perfect for non-urgent packages at standard pricing.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        height: 1.55,
                        color: AppColors.darkTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: AppColors.darkBorder),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _pill('Step-by-step updates', false),
                        _pill('Driver info & contact', false),
                        _pill('Delivery PIN protection', false),
                        _pill('Standard pricing', false),
                      ],
                    ),
                  ],
                ),
              ),

              // CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _selectType('regular'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Book Regular Delivery',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            )),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Express card ───────────────────────────────────────────────────────────

  Widget _buildExpressCard() {
    return ScaleTransition(
      scale: _card2Scale,
      child: GestureDetector(
        onTap: () => _selectType('express'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.primaryGold.withOpacity(0.4), width: 1.5),
            boxShadow: [BoxShadow(
                color: AppColors.primaryGold.withOpacity(0.12),
                blurRadius: 24, offset: const Offset(0, 6))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: AppColors.primaryDark, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Express',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  )),
                              const SizedBox(width: 8),
                              _buildSurchargeBadge(),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('Live map. Real-time tracking.',
                              style: TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.55),
                              )),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: Colors.white.withOpacity(0.35)),
                  ],
                ),
              ),

              // Description + features
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch your driver move on a live map from pickup to '
                          'your door. Ideal for urgent or high-value packages. '
                          'A small surcharge applies — configured by the operator.',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 13,
                        height: 1.55,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(height: 1, color: Colors.white.withOpacity(0.08)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        _pill('Live GPS map tracking', true),
                        _pill('Real-time driver location', true),
                        _pill('Delivery PIN protection', true),
                        _pill('Small surcharge applies', true),
                      ],
                    ),
                  ],
                ),
              ),

              // CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => _selectType('express'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGold,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Book Express Delivery',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            )),
                        SizedBox(width: 8),
                        Icon(Icons.bolt_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Surcharge badge — always from backend ──────────────────────────────────

  Widget _buildSurchargeBadge() {
    // Still loading
    if (_loadingSurcharge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primaryGold.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: SizedBox(
          width: 30, height: 10,
          child: LinearProgressIndicator(
            backgroundColor: AppColors.primaryGold.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primaryGold.withOpacity(0.6)),
          ),
        ),
      );
    }

    // No surcharge configured (or call failed) — show nothing
    if (_surchargeLabel == null) return const SizedBox.shrink();

    // Show the actual surcharge from the backend
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryGold,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(_surchargeLabel!,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
          )),
    );
  }

  // ── Info banner ────────────────────────────────────────────────────────────

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryGold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: AppColors.primaryGold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                'Both options include driver tracking, PIN protection, '
                    'and support for MTN MoMo, Orange Money, or cash.',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.primaryGold.withOpacity(0.85), fontSize: 12, height: 1.5)),
          ),
        ],
      ),
    );
  }

  // ── Feature pill ───────────────────────────────────────────────────────────

  Widget _pill(String label, bool isExpress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isExpress
            ? Colors.white.withOpacity(0.07)
            : AppColors.darkSurfaceAlt,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isExpress
              ? Colors.white.withOpacity(0.12)
              : AppColors.darkBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded,
              size: 11,
              color: isExpress ? AppColors.primaryGold : AppColors.success),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isExpress
                    ? Colors.white.withOpacity(0.75)
                    : AppColors.darkTextSecondary,
              )),
        ],
      ),
    );
  }
}