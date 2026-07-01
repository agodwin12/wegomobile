import 'package:flutter/material.dart';

/// App Color Palette - Based on Cahier de Charge
class AppColors {
  // ── Primary ───────────────────────────────────────────────────────────────
  static const Color primaryGold     = Color(0xFFFFD700);
  static const Color primaryGoldDark = Color(0xFFFFC107); // darker gold for gradients
  static const Color primaryYellow   = Color(0xFFFFC107);
  static const Color primaryDark     = Color(0xFF1A1A1A);
  static const Color primaryBlack    = Color(0xFF000000);

  // ── Secondary ─────────────────────────────────────────────────────────────
  static const Color secondaryGrey      = Color(0xFF757575);
  static const Color secondaryLightGrey = Color(0xFFE0E0E0);
  static const Color secondaryDarkGrey  = Color(0xFF424242);

  // ── Background ────────────────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundWhite = Color(0xFFFFFFFF);
  static const Color backgroundDark  = Color(0xFF212121);

  /// Semantic alias — used as the main page background throughout the app
  static const Color background = backgroundLight;

  /// Semantic alias — card / sheet surface (white)
  static const Color surface = backgroundWhite;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textLight     = Color(0xFF9E9E9E);
  static const Color textWhite     = Color(0xFFFFFFFF);

  /// Semantic alias — placeholder / hint text
  static const Color textHint = textLight;

  // ── Border ────────────────────────────────────────────────────────────────
  static const Color borderLight  = Color(0xFFE0E0E0);
  static const Color borderMedium = Color(0xFFBDBDBD);
  static const Color borderDark   = Color(0xFF757575);

  /// Semantic alias — default border used on cards and dividers
  static const Color border = borderLight;

  // ── Status ────────────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color error        = Color(0xFFE53935);
  static const Color errorLight   = Color(0xFFFFEBEE);
  static const Color warning      = Color(0xFFFFA726);
  static const Color warningLight = Color(0xFFFFF3E0);
  static const Color info         = Color(0xFF29B6F6);
  static const Color infoLight    = Color(0xFFE1F5FE);

  // ── Input ─────────────────────────────────────────────────────────────────
  static const Color inputBackground = Color(0xFFFAFAFA);
  static const Color inputBorder     = Color(0xFFE0E0E0);
  static const Color inputFocused    = Color(0xFFFFD700);
  static const Color inputError      = Color(0xFFE53935);

  // ── Button ────────────────────────────────────────────────────────────────
  static const Color buttonPrimary        = Color(0xFFFFD700);
  static const Color buttonSecondary      = Color(0xFF424242);
  static const Color buttonDisabled       = Color(0xFFE0E0E0);
  static const Color buttonTextPrimary    = Color(0xFF1A1A1A);
  static const Color buttonTextSecondary  = Color(0xFFFFFFFF);

  // ── Shadow ────────────────────────────────────────────────────────────────
  static Color shadowLight  = Colors.black.withOpacity(0.05);
  static Color shadowMedium = Colors.black.withOpacity(0.10);
  static Color shadowDark   = Colors.black.withOpacity(0.20);


  // ── Dark UI surfaces (ride-hailing / map screens) ──────────────────────────
  static const Color darkBg            = Color(0xFF0E0E10); // scaffold / map dim
  static const Color darkSurface       = Color(0xFF1A1A1D); // bottom sheet
  static const Color darkSurfaceAlt    = Color(0xFF26262B); // cards / inputs
  static const Color darkSurfaceHigh   = Color(0xFF303036); // elevated chips
  static const Color darkBorder        = Color(0xFF34343B);
  static const Color darkDivider       = Color(0xFF2A2A2F);
  static const Color darkTextPrimary   = Color(0xFFF5F5F7);
  static const Color darkTextSecondary = Color(0xFF9A9AA2);
  static const Color darkTextTertiary  = Color(0xFF6C6C74);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFD700), Color(0xFFFFC107)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF424242)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}