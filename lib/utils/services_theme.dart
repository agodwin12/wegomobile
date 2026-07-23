// lib/utils/services_theme.dart
// ─────────────────────────────────────────────────────────────────────────────
// Services Marketplace — colour & style constants
//
// All services screens import THIS file instead of app_colors.dart directly.
// Ride-hailing / delivery continue using AppColors (gold theme) untouched.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'app_colors.dart';      // your existing file
import 'app_typography.dart';  // your existing file

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE COLOURS
// ─────────────────────────────────────────────────────────────────────────────
class SvcColors {
  SvcColors._();

  // ── Primary green (matches screenshot mint/emerald) ───────────────────────
  static const Color primary        = Color(0xFF53C28B);  // main green CTA
  static const Color primaryDark    = Color(0xFF3DAA76);  // pressed / dark variant
  static const Color primaryLight   = Color(0xFFDFF5EC);  // chip / badge bg
  static const Color primaryMid     = Color(0xFFB2E8D0);  // progress track, dividers

  // ── Promo / discount accent (orange-red like the "35% OFF" badges) ────────
  static const Color discount       = Color(0xFFFF6B6B);
  static const Color discountLight  = Color(0xFFFFECEC);

  // ── Surface ───────────────────────────────────────────────────────────────
  /// Page background — very light grey-white
  static const Color pageBg         = Color(0xFFF8F9FA);
  /// Card / sheet surface
  static const Color surface        = Color(0xFFFFFFFF);
  /// Subtle divider / input bg
  static const Color inputBg        = Color(0xFFF1F3F4);

  // ── Text (re-export for convenience so screens only import SvcColors) ─────
  static Color get textPrimary => AppColors.textPrimary;
  static Color get textSecondary => AppColors.textSecondary;
  static Color get textLight => AppColors.textLight;

  // ── Border ────────────────────────────────────────────────────────────────
  static Color get border => AppColors.borderLight;
  static const Color borderFocus    = primary;

  // ── Status — pass-through from AppColors ─────────────────────────────────
  static const Color success        = AppColors.success;
  static Color get successLight => AppColors.successLight;
  static const Color error          = AppColors.error;
  static Color get errorLight => AppColors.errorLight;
  static const Color warning        = AppColors.warning;
  static Color get warningLight => AppColors.warningLight;
  static const Color info           = AppColors.info;
  static Color get infoLight => AppColors.infoLight;

  // ── Shadows (constants so they can be used in const constructors) ─────────
  static const Color shadowColor    = Color(0x0D000000);  // 5 % black
  static const Color shadowColorMd  = Color(0x1A000000);  // 10 % black

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF53C28B), Color(0xFF3DAA76)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient promoGradient = LinearGradient(
    colors: [Color(0xFFDFF5EC), Color(0xFFB2E8D0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE SHADOWS  (BoxShadow lists, ready to spread into `boxShadow:`)
// ─────────────────────────────────────────────────────────────────────────────
class SvcShadows {
  SvcShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: SvcColors.shadowColor,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: SvcColors.shadowColorMd,
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
  ];

  static const List<BoxShadow> bottom = [
    BoxShadow(
      color: SvcColors.shadowColorMd,
      blurRadius: 12,
      offset: Offset(0, -4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE RADIUS  (single source of truth)
// ─────────────────────────────────────────────────────────────────────────────
class SvcRadius {
  SvcRadius._();

  static const double xs  = 6.0;
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 20.0;
  static const double pill = 999.0;

  static BorderRadius small       = BorderRadius.circular(sm);
  static BorderRadius medium      = BorderRadius.circular(md);
  static BorderRadius large       = BorderRadius.circular(lg);
  static BorderRadius extraLarge  = BorderRadius.circular(xl);
  static BorderRadius circular    = BorderRadius.circular(pill);
}

// ─────────────────────────────────────────────────────────────────────────────
// SERVICE TEXT STYLES
// (wrap AppTypography so services can apply green-themed overrides easily)
// ─────────────────────────────────────────────────────────────────────────────
class SvcText {
  SvcText._();

  // ── Headings ─────────────────────────────────────────────────────────────
  static TextStyle sectionTitle({double fontSize = 18}) => TextStyle(
    fontFamily: 'LeagueSpartan',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: SvcColors.textPrimary,
    height: 1.3,
  );

  static TextStyle cardTitle({double fontSize = 13}) => TextStyle(
    fontFamily: 'LeagueSpartan',
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
    color: SvcColors.textPrimary,
    height: 1.4,
  );

  // ── Price ─────────────────────────────────────────────────────────────────
  static TextStyle price({double fontSize = 15, Color? color}) => TextStyle(
    fontFamily: 'LeagueSpartan',
    fontSize: fontSize,
    fontWeight: FontWeight.w700,
    color: color ?? SvcColors.primary,
    height: 1.2,
  );

  static TextStyle priceStrikethrough({double fontSize = 12}) => TextStyle(
    fontFamily: 'Quicksand',
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: SvcColors.textLight,
    decoration: TextDecoration.lineThrough,
    height: 1.2,
  );

  // ── Badges ────────────────────────────────────────────────────────────────
  static TextStyle badge({Color? color}) => TextStyle(
    fontFamily: 'LeagueSpartan',
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: color ?? Colors.white,
    height: 1.2,
    letterSpacing: 0.2,
  );

  // ── Body ──────────────────────────────────────────────────────────────────
  static TextStyle body({double fontSize = 13, Color? color}) => TextStyle(
    fontFamily: 'Quicksand',
    fontSize: fontSize,
    fontWeight: FontWeight.w400,
    color: color ?? SvcColors.textSecondary,
    height: 1.5,
  );

  // ── Labels ────────────────────────────────────────────────────────────────
  static TextStyle label({double fontSize = 11, Color? color}) => TextStyle(
    fontFamily: 'Quicksand',
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    color: color ?? SvcColors.textSecondary,
    height: 1.4,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED WIDGET HELPERS
// (tiny factory methods used across many services screens)
// ─────────────────────────────────────────────────────────────────────────────
class SvcWidgets {
  SvcWidgets._();

  // ── Discount badge  e.g. "35% OFF" ───────────────────────────────────────
  static Widget discountBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: SvcColors.discount,
        borderRadius: BorderRadius.circular(SvcRadius.sm),
      ),
      child: Text(label, style: SvcText.badge()),
    );
  }

  // ── Green category chip ───────────────────────────────────────────────────
  static Widget categoryChip(String label, {bool selected = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? SvcColors.primary : SvcColors.surface,
          borderRadius: BorderRadius.circular(SvcRadius.pill),
          border: Border.all(
            color: selected ? SvcColors.primary : SvcColors.border,
          ),
        ),
        child: Text(
          label,
          style: SvcText.label(
            color: selected ? Colors.white : SvcColors.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Rating row  e.g. ★ 4.5 (128) ────────────────────────────────────────
  static Widget ratingRow(double rating, int reviews, {double iconSize = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: iconSize, color: const Color(0xFFFFA726)),
        const SizedBox(width: 3),
        Text(
          rating.toStringAsFixed(1),
          style: SvcText.label(fontSize: iconSize - 2, color: SvcColors.textPrimary),
        ),
        const SizedBox(width: 3),
        Text(
          '($reviews)',
          style: SvcText.label(fontSize: iconSize - 2),
        ),
      ],
    );
  }

  // ── Section header row  e.g. "Category  See All ›" ───────────────────────
  static Widget sectionHeader(
      String title, {
        String seeAll = 'See All',
        VoidCallback? onSeeAll,
        double fontSize = 16,
      }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: SvcText.sectionTitle(fontSize: fontSize)),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              seeAll,
              style: SvcText.label(
                fontSize: 13,
                color: SvcColors.primary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  // ── Pill status badge ─────────────────────────────────────────────────────
  static Widget statusBadge(String label, {Color? bg, Color? fg}) {
    final background = bg ?? SvcColors.primaryLight;
    final foreground = fg ?? SvcColors.primaryDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(SvcRadius.pill),
      ),
      child: Text(label, style: SvcText.badge(color: foreground)),
    );
  }

  // ── Green CTA button ──────────────────────────────────────────────────────
  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    double height = 52,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: SvcColors.primary,
          disabledBackgroundColor: SvcColors.primaryMid,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SvcRadius.lg),
          ),
        ),
        child: loading
            ? const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Loading spinner (green) ───────────────────────────────────────────────
  static Widget loader({String? message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: SvcColors.primary,
            strokeWidth: 3,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message, style: SvcText.body()),
          ],
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  static Widget emptyState({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: SvcColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 52, color: SvcColors.primary),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: SvcText.sectionTitle(fontSize: 17),
                textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  style: SvcText.body(),
                  textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────
  static Widget errorState({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: SvcColors.textLight),
            const SizedBox(height: 16),
            Text(message,
                style: SvcText.body(color: SvcColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SvcColors.primary,
                side: const BorderSide(color: SvcColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SvcRadius.lg),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}