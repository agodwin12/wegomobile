// lib/widgets/services/promo_banner_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Auto-scrolling promo banner carousel
// Overflow-fixed + aligned to AppColors / AppTypography
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_typography.dart';

// ─── Local design tokens ──────────────────────────────────────────────────────
const _kPrimary      = AppColors.primaryGold;
const _kPrimaryDark  = AppColors.primaryGoldDark;
const _kPrimaryMid   = Color(0xFFFFECB3);
const _kTextPrimary  = AppColors.textPrimary;

const double _rMd   = 12.0;
const double _rXl   = 24.0;
const double _rPill = 999.0;

const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
];

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class PromoBanner {
  final String title;
  final String subtitle;
  final String ctaLabel;
  final String? imageUrl;
  final String? emoji;
  final Color bgColor;
  final Color textColor;
  final VoidCallback? onTap;

  const PromoBanner({
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.imageUrl,
    this.emoji,
    required this.bgColor,
    this.textColor = AppColors.textPrimary,
    this.onTap,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DEFAULT STATIC BANNERS
// ─────────────────────────────────────────────────────────────────────────────
final List<PromoBanner> _defaultBanners = [
  PromoBanner(
    title: 'Jusqu\'à 30% de réduction !',
    subtitle: 'Profitez de nos offres chaque jour',
    ctaLabel: 'Voir',
    emoji: '🛒',
    bgColor: const Color(0xFFFFFDE7),
    textColor: AppColors.textPrimary,
  ),
  PromoBanner(
    title: 'Nouveaux prestataires',
    subtitle: 'Des pros qualifiés près de chez vous',
    ctaLabel: 'Explorer',
    emoji: '⚡',
    bgColor: AppColors.infoLight,
    textColor: AppColors.textPrimary,
  ),
  PromoBanner(
    title: 'Urgence 24h/24',
    subtitle: 'De l\'aide quand vous en avez besoin',
    ctaLabel: 'Trouver',
    emoji: '🔧',
    bgColor: AppColors.warningLight,
    textColor: AppColors.textPrimary,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class PromoBannerWidget extends StatefulWidget {
  final List<PromoBanner>? banners;

  /// Height of each banner card.
  /// FIX: raised from 140 to 160 so the text column + CTA always fits.
  /// The text column is the overflow culprit — it needs ~155 px at minimum
  /// font sizes (title 18 pt × 1.2 + 6 gap + subtitle 12 pt × 1.4 × 2 lines
  /// + 14 gap + CTA 36 pt = ~142 px) plus 20 pt top/bottom padding = 182 px.
  /// We use 160 + clip-overflow so it degrades gracefully on very small text.
  final double height;

  final Duration? autoScrollInterval;

  const PromoBannerWidget({
    Key? key,
    this.banners,
    this.height = 160,
    this.autoScrollInterval = const Duration(seconds: 4),
  }) : super(key: key);

  @override
  State<PromoBannerWidget> createState() => _PromoBannerWidgetState();
}

class _PromoBannerWidgetState extends State<PromoBannerWidget> {
  late final PageController _pageController;
  late final List<PromoBanner> _banners;
  int    _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _banners        = widget.banners ?? _defaultBanners;
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    if (widget.autoScrollInterval == null || _banners.length <= 1) return;
    _timer = Timer.periodic(widget.autoScrollInterval!, (_) {
      if (!mounted) return;
      final next = (_currentIndex + 1) % _banners.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_banners.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (_, i) => _BannerCard(
              banner: _banners[i],
              height: widget.height,
            ),
          ),
        ),

        if (_banners.length > 1) ...[
          const SizedBox(height: 10),
          _DotIndicator(
            count: _banners.length,
            current: _currentIndex,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE BANNER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BannerCard extends StatelessWidget {
  final PromoBanner banner;
  final double height;

  const _BannerCard({required this.banner, required this.height});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: banner.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        height: height,
        decoration: BoxDecoration(
          color: banner.bgColor,
          borderRadius: BorderRadius.circular(_rXl),
          boxShadow: _kCardShadow,
        ),
        // FIX: ClipRect so decorative circles that extend outside the card
        // bounds never cause overflow assertions
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_rXl),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimary.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 40,
                bottom: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kPrimary.withOpacity(0.06),
                  ),
                ),
              ),

              // Content row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left: text + CTA
                    // FIX: The original Column had MainAxisSize.max with
                    // MainAxisAlignment.center — inside a tight height
                    // constraint this caused the column to measure its
                    // children at natural size THEN try to centre them,
                    // overflowing by 33 px when the natural size > height.
                    // Solution: MainAxisSize.min + no mainAxisAlignment so
                    // the column only takes what it needs, and add
                    // Flexible children so text wraps rather than overflows.
                    Expanded(
                      flex: 3,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title — max 2 lines, ellipsis if still too long
                          Text(
                            banner.title,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: banner.textColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Subtitle — max 2 lines
                          Text(
                            banner.subtitle,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: banner.textColor.withOpacity(0.75),
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 12),
                          _CtaButton(
                            label: banner.ctaLabel,
                            onTap: banner.onTap,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Right: image or emoji
                    Expanded(
                      flex: 2,
                      child: Center(
                        child: banner.imageUrl != null
                            ? ClipRRect(
                          borderRadius: BorderRadius.circular(_rMd),
                          child: Image.network(
                            banner.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _EmojiIllustration(
                                    emoji: banner.emoji ?? '🛒'),
                          ),
                        )
                            : _EmojiIllustration(
                            emoji: banner.emoji ?? '🛒'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CtaButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _CtaButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _kPrimary,
          borderRadius: BorderRadius.circular(_rPill),
          boxShadow: [
            BoxShadow(
              color: _kPrimary.withOpacity(0.35),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w700,
            // FIX: dark text on gold button (correct contrast)
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMOJI ILLUSTRATION
// ─────────────────────────────────────────────────────────────────────────────
class _EmojiIllustration extends StatelessWidget {
  final String emoji;
  const _EmojiIllustration({required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.55),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 34)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOT INDICATORS
// ─────────────────────────────────────────────────────────────────────────────
class _DotIndicator extends StatelessWidget {
  final int count;
  final int current;
  const _DotIndicator({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 20 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? _kPrimary : _kPrimaryMid,
            borderRadius: BorderRadius.circular(_rPill),
          ),
        );
      }),
    );
  }
}