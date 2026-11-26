import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppTheme {
  static const gold = Color(0xffddbf83);
  static const radius = 24.0;

  static ThemeData build(Brightness brightness, {bool sinhala = false}) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      brightness: brightness,
      seedColor: const Color(0xffb49153),
      surface: dark ? const Color(0xff1b1a18) : const Color(0xfffffcf6),
      primary: dark ? gold : const Color(0xff765623),
      onPrimary: dark ? const Color(0xff251b0d) : Colors.white,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: colors);
    final body = sinhala
        ? GoogleFonts.notoSansSinhalaTextTheme(base.textTheme)
        : GoogleFonts.interTextTheme(base.textTheme);
    return base.copyWith(
      scaffoldBackgroundColor: dark
          ? const Color(0xff11110f)
          : const Color(0xfff8f4eb),
      textTheme: body.copyWith(
        headlineLarge:
            (sinhala
            ? GoogleFonts.notoSansSinhala
            : GoogleFonts.playfairDisplay)(
              textStyle: body.headlineLarge,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
        headlineMedium:
            (sinhala
            ? GoogleFonts.notoSansSinhala
            : GoogleFonts.playfairDisplay)(
              textStyle: body.headlineMedium,
              fontWeight: FontWeight.w600,
            ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 17,
          horizontal: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
