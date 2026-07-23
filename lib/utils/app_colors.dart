import 'package:flutter/material.dart';

/// App Color Palette - Based on Cahier de Charge
///
/// THEMING: the app supports light (default) and dark mode while keeping the
/// black & gold identity. Brand tokens (gold, status, dark map surfaces) are
/// fixed. The "light-designed" tokens below (backgrounds, text, borders,
/// inputs) are MUTABLE statics swapped by [AppColors.apply]. After toggling,
/// the app is restarted (RestartWidget) so every screen repaints — this keeps
/// the thousands of existing `AppColors.x` references working without a
/// full Theme.of() refactor.
class AppColors {
  // ── Primary (fixed — brand) ───────────────────────────────────────────────
  // Charte graphique WEGO (p.6) : Jaune Or #FFDC71 (RVB 255 220 113) est la
  // couleur accent officielle — boutons, liens, détails visuels. #F5C844 est
  // sa déclinaison foncée pour les dégradés (déjà présente dans l'app).
  static const Color primaryGold     = Color(0xFFFFDC71);
  static const Color primaryGoldDark = Color(0xFFF5C844); // darker gold for gradients
  static const Color primaryYellow   = Color(0xFFF5C844);
  static const Color primaryDark     = Color(0xFF1A1A1A);
  static const Color primaryBlack    = Color(0xFF000000); // Noir profond (charte)

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const Color secondaryGrey     = Color(0xFF757575);
  static Color secondaryLightGrey      = const Color(0xFFE0E0E0);
  static const Color secondaryDarkGrey = Color(0xFF424242);

  // ── Background (mutable — theme-aware) ────────────────────────────────────
  static Color backgroundLight = const Color(0xFFF5F5F5);
  static Color backgroundWhite = const Color(0xFFFFFFFF);
  static const Color backgroundDark = Color(0xFF212121);

  /// Semantic alias — used as the main page background throughout the app
  static Color background = const Color(0xFFF5F5F5);

  /// Semantic alias — card / sheet surface
  static Color surface = const Color(0xFFFFFFFF);

  // ── Text (mutable — theme-aware) ──────────────────────────────────────────
  static Color textPrimary   = const Color(0xFF1A1A1A);
  // textSecondary reste plus foncé que le Gris neutre de la charte (#A9A9A9)
  // pour préserver la lisibilité sur fonds clairs (contraste AA) ; le gris
  // charte est appliqué aux textes tertiaires/indicatifs ci-dessous.
  static Color textSecondary = const Color(0xFF757575);
  static Color textLight     = const Color(0xFFA9A9A9); // Gris neutre (charte)
  static const Color textWhite = Color(0xFFFFFFFF);

  /// Semantic alias — placeholder / hint text
  static Color textHint = const Color(0xFFA9A9A9); // Gris neutre (charte)

  // ── Border (mutable — theme-aware) ────────────────────────────────────────
  static Color borderLight  = const Color(0xFFE0E0E0);
  static Color borderMedium = const Color(0xFFBDBDBD);
  static const Color borderDark = Color(0xFF757575);

  /// Semantic alias — default border used on cards and dividers
  static Color border = const Color(0xFFE0E0E0);

  // ── Status (accents fixed; tinted backgrounds theme-aware) ────────────────
  static const Color success = Color(0xFF4CAF50);
  static Color successLight  = const Color(0xFFE8F5E9);
  static const Color error   = Color(0xFFE53935);
  static Color errorLight    = const Color(0xFFFFEBEE);
  static const Color warning = Color(0xFFFFA726);
  static Color warningLight  = const Color(0xFFFFF3E0);
  static const Color info    = Color(0xFF29B6F6);
  static Color infoLight     = const Color(0xFFE1F5FE);

  // ── Input (mutable — theme-aware) ─────────────────────────────────────────
  static Color inputBackground = const Color(0xFFFAFAFA);
  static Color inputBorder     = const Color(0xFFE0E0E0);
  static const Color inputFocused = Color(0xFFFFDC71); // Jaune Or (charte)
  static const Color inputError   = Color(0xFFE53935);

  // ── Button ────────────────────────────────────────────────────────────────
  static const Color buttonPrimary       = Color(0xFFFFDC71); // Jaune Or (charte)
  static const Color buttonSecondary     = Color(0xFF424242);
  static Color buttonDisabled            = const Color(0xFFE0E0E0);
  static const Color buttonTextPrimary   = Color(0xFF1A1A1A);
  static const Color buttonTextSecondary = Color(0xFFFFFFFF);

  // ── Shadow ────────────────────────────────────────────────────────────────
  static Color shadowLight  = Colors.black.withOpacity(0.05);
  static Color shadowMedium = Colors.black.withOpacity(0.10);
  static Color shadowDark   = Colors.black.withOpacity(0.20);

  // ── Dark UI surfaces (ride-hailing / map screens — fixed) ─────────────────
  static const Color darkBg            = Color(0xFF0E0E10); // scaffold / map dim
  static const Color darkSurface       = Color(0xFF1A1A1D); // bottom sheet
  static const Color darkSurfaceAlt    = Color(0xFF26262B); // cards / inputs
  static const Color darkSurfaceHigh   = Color(0xFF303036); // elevated chips
  static const Color darkBorder        = Color(0xFF34343B);
  static const Color darkDivider       = Color(0xFF2A2A2F);
  static const Color darkTextPrimary   = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF9A9AA2);
  static const Color darkTextTertiary  = Color(0xFF6C6C74);

  // ── Gradients (fixed) ─────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFDC71), Color(0xFFF5C844)], // Jaune Or charte → foncé
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ═══════════════════════════════════════════════════════════════════════
  // THEME SWITCHING
  // ═══════════════════════════════════════════════════════════════════════

  static bool isDark = false;

  /// Swap the theme-aware tokens. Call before runApp and on toggle (followed
  /// by an app restart so all mounted screens repaint).
  static void apply({required bool dark}) {
    isDark = dark;
    if (dark) {
      backgroundLight   = const Color(0xFF0E0E10);
      backgroundWhite   = const Color(0xFF1A1A1D);
      background        = const Color(0xFF0E0E10);
      surface           = const Color(0xFF1A1A1D);
      textPrimary       = const Color(0xFFF5F5F7);
      textSecondary     = const Color(0xFF9A9AA2);
      textLight         = const Color(0xFF6C6C74);
      textHint          = const Color(0xFF6C6C74);
      borderLight       = const Color(0xFF34343B);
      borderMedium      = const Color(0xFF44444B);
      border            = const Color(0xFF34343B);
      inputBackground   = const Color(0xFF26262B);
      inputBorder       = const Color(0xFF34343B);
      secondaryLightGrey= const Color(0xFF3A3A41);
      buttonDisabled    = const Color(0xFF3A3A41);
      successLight      = const Color(0xFF1B2E1D);
      errorLight        = const Color(0xFF331D1F);
      warningLight      = const Color(0xFF332A18);
      infoLight         = const Color(0xFF16282F);
      shadowLight       = Colors.black.withOpacity(0.25);
      shadowMedium      = Colors.black.withOpacity(0.35);
      shadowDark        = Colors.black.withOpacity(0.50);
    } else {
      backgroundLight   = const Color(0xFFF5F5F5);
      backgroundWhite   = const Color(0xFFFFFFFF);
      background        = const Color(0xFFF5F5F5);
      surface           = const Color(0xFFFFFFFF);
      textPrimary       = const Color(0xFF1A1A1A);
      textSecondary     = const Color(0xFF757575);
      textLight         = const Color(0xFFA9A9A9); // Gris neutre (charte)
      textHint          = const Color(0xFFA9A9A9); // Gris neutre (charte)
      borderLight       = const Color(0xFFE0E0E0);
      borderMedium      = const Color(0xFFBDBDBD);
      border            = const Color(0xFFE0E0E0);
      inputBackground   = const Color(0xFFFAFAFA);
      inputBorder       = const Color(0xFFE0E0E0);
      secondaryLightGrey= const Color(0xFFE0E0E0);
      buttonDisabled    = const Color(0xFFE0E0E0);
      successLight      = const Color(0xFFE8F5E9);
      errorLight        = const Color(0xFFFFEBEE);
      warningLight      = const Color(0xFFFFF3E0);
      infoLight         = const Color(0xFFE1F5FE);
      shadowLight       = Colors.black.withOpacity(0.05);
      shadowMedium      = Colors.black.withOpacity(0.10);
      shadowDark        = Colors.black.withOpacity(0.20);
    }
  }
}
