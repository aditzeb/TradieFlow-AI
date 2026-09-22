import 'package:flutter/material.dart';
import 'glassline_tokens.dart';

ThemeData buildGlasslineTheme() {
  const ink = GlasslineColors.primary;
  const muted = GlasslineColors.secondary;
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(GlasslineRadii.md),
    borderSide: const BorderSide(color: muted),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Geist',
    scaffoldBackgroundColor: GlasslineColors.neutral,
    colorScheme: const ColorScheme.light(
      primary: ink,
      onPrimary: Colors.white,
      secondary: muted,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      error: ink,
      onError: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GlasslineRadii.lg),
        side: const BorderSide(color: GlasslineColors.neutral),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: border,
      enabledBorder: border.copyWith(
        borderSide: BorderSide(color: muted.withValues(alpha: 0.4)),
      ),
      focusedBorder: border.copyWith(borderSide: const BorderSide(width: 2)),
      contentPadding: const EdgeInsets.all(16),
      labelStyle: const TextStyle(color: muted, fontSize: 14),
      errorMaxLines: 3,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: GlasslineColors.tertiary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 52),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GlasslineRadii.md),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Geist',
          fontSize: 15.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: ink),
    dividerTheme: DividerThemeData(color: muted.withValues(alpha: 0.16)),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontSize: 60,
        fontWeight: FontWeight.w600,
        letterSpacing: -1.8,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.72,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 15.2, height: 1.55, color: ink),
      bodySmall: TextStyle(fontSize: 13, height: 1.5, color: muted),
      labelSmall: TextStyle(
        fontFamily: 'Geist Mono',
        fontSize: 12,
        color: muted,
        height: 1.5,
      ),
    ),
  );
}
