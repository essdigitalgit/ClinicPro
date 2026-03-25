import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Central design system — colors, gradients, and ThemeData.
class AppTheme {
  AppTheme._();

  // ── Brand palette ──────────────────────────────────────────────────────────
  static const Color primary          = Color(0xFF0077B6);
  static const Color primaryDark      = Color(0xFF005F8A);
  static const Color primaryLight     = Color(0xFF48CAE4);
  static const Color primaryContainer = Color(0xFFDCEEF8);

  static const Color success   = Color(0xFF059669);
  static const Color successBg = Color(0xFFD1FAE5);
  static const Color warning   = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error     = Color(0xFFDC2626);
  static const Color errorBg   = Color(0xFFFEE2E2);

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color background  = Color(0xFFF0F6FC);
  static const Color surface     = Color(0xFFFFFFFF);
  static const Color surfaceAlt  = Color(0xFFF8FAFC);
  static const Color border      = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFEFF3F8);

  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textTertiary  = Color(0xFF94A3B8);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0077B6), Color(0xFF0096C7)],
  );

  static const LinearGradient softGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDCEEF8), Color(0xFFE8F4FD)],
  );

  // ── ThemeData ──────────────────────────────────────────────────────────────
  static ThemeData get light {
    const cs = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: Colors.white,
      primaryContainer: primaryContainer,
      onPrimaryContainer: Color(0xFF003652),
      secondary: Color(0xFF06B6D4),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFCFFAFE),
      onSecondaryContainer: Color(0xFF083344),
      tertiary: Color(0xFF0EA5A0),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFCCFBF1),
      onTertiaryContainer: Color(0xFF042F2E),
      error: error,
      onError: Colors.white,
      errorContainer: errorBg,
      onErrorContainer: Color(0xFF7F1D1D),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerLowest: Color(0xFFF8FAFC),
      surfaceContainerLow: Color(0xFFF1F5F9),
      surfaceContainer: Color(0xFFE8EFF7),
      surfaceContainerHigh: Color(0xFFDDE6F0),
      surfaceContainerHighest: Color(0xFFD1DDE9),
      onSurfaceVariant: textSecondary,
      outline: border,
      outlineVariant: borderLight,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1E293B),
      onInverseSurface: Colors.white,
      inversePrimary: primaryLight,
      shadow: Colors.black,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: background,

      // ── AppBar ─────────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Color(0x1A000000),
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textSecondary, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // ── Cards ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: borderLight, width: 1.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Input fields ───────────────────────────────────────────────────────
      inputDecorationTheme: const InputDecorationTheme(
        filled: true,
        fillColor: Color(0xFFF1F5F9),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: error, width: 2),
        ),
        labelStyle: TextStyle(
            color: textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        hintStyle: TextStyle(color: textTertiary, fontSize: 14),
        prefixIconColor: textSecondary,
        errorStyle: TextStyle(color: error, fontSize: 12),
        floatingLabelStyle: TextStyle(
            color: primary, fontSize: 12, fontWeight: FontWeight.w600),
      ),

      // ── Filled button ──────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1),
        ),
      ),

      // ── Outlined button ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1),
        ),
      ),

      // ── FAB ────────────────────────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // ── Chips ──────────────────────────────────────────────────────────────
      chipTheme: const ChipThemeData(
        backgroundColor: surfaceAlt,
        selectedColor: primaryContainer,
        labelStyle:
            TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        side: BorderSide(color: border, width: 1),
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),

      // ── Divider ────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),

      // ── SnackBar ───────────────────────────────────────────────────────────
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF1E293B),
        contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),

      // ── Text ───────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: textPrimary,
            letterSpacing: -1),
        displaySmall: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5),
        headlineLarge: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.5),
        headlineMedium: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
            letterSpacing: -0.3),
        headlineSmall: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleLarge: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleMedium: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        titleSmall: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textPrimary),
        bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textPrimary),
        bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: textSecondary),
        bodySmall: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: textTertiary),
        labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textPrimary,
            letterSpacing: 0.1),
        labelMedium: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSecondary),
        labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: textTertiary,
            letterSpacing: 0.2),
      ),
    );
  }
}
