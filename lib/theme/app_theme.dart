import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TBR's palette. The first four are nikki's primary colours; the rest are
/// lighter and darker shades of them, used for book spines, chips and the
/// dark shelf page.
class AppColors {
  static const cream = Color(0xFFF9EEC9);
  static const brown = Color(0xFF783B19);
  static const charcoal = Color(0xFF2C282C);
  static const green = Color(0xFF0F401F);

  static const paper = Color(0xFFFFF8E3);
  static const sand = Color(0xFFE2B07A);
  static const tan = Color(0xFFC08A5A);
  static const rust = Color(0xFF9C5A35);
  static const walnut = Color(0xFF5B3326);
  static const plum = Color(0xFF4A3A3A);
  static const sage = Color(0xFF4F6B4A);
  static const night = Color(0xFF1D1819);
  static const muted = Color(0xFF6B5D55);
  static const bulb = Color(0xFFFFE6B3);

  /// Colours a book spine or a genre chip can take.
  static const spines = [green, brown, charcoal, rust, tan, walnut, plum, sage, sand];
}

/// The three typefaces: a serif for headings, a handwritten one for quotes,
/// and a clean sans for everything else.
class AppText {
  static TextStyle serif({double size = 28, Color? color, FontWeight? weight}) =>
      GoogleFonts.dmSerifDisplay(fontSize: size, color: color, fontWeight: weight, height: 1.1);

  static TextStyle hand({double size = 24, Color? color}) =>
      GoogleFonts.caveat(fontSize: size, color: color ?? AppColors.green, fontWeight: FontWeight.w600);

  static TextStyle sans({double size = 15, Color? color, FontWeight? weight}) =>
      GoogleFonts.inter(fontSize: size, color: color, fontWeight: weight);
}

class AppTheme {
  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.charcoal,
      onPrimary: AppColors.cream,
      secondary: AppColors.green,
      onSecondary: AppColors.cream,
      tertiary: AppColors.brown,
      onTertiary: AppColors.cream,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: AppColors.cream,
      onSurface: AppColors.charcoal,
      surfaceContainer: AppColors.paper,
      onSurfaceVariant: AppColors.muted,
      outline: Color(0xFFD9C9A3),
    ),
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.cream,
      onPrimary: AppColors.charcoal,
      secondary: Color(0xFF7FB08A),
      onSecondary: AppColors.night,
      tertiary: AppColors.sand,
      onTertiary: AppColors.charcoal,
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: AppColors.charcoal,
      onSurface: AppColors.cream,
      surfaceContainer: Color(0xFF3A3436),
      onSurfaceVariant: Color(0xFFB9AB95),
      outline: Color(0xFF5A4B45),
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.interTextTheme(
        base.textTheme,
      ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppText.sans(size: 16, weight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.onSurface, textStyle: AppText.sans(size: 15)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: AppText.sans(color: AppColors.cream),
        actionTextColor: AppColors.sand,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.charcoal, borderRadius: BorderRadius.circular(8)),
        textStyle: AppText.sans(size: 13, color: AppColors.cream),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
