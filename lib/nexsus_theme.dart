import 'package:flutter/material.dart';

/// Shared visual language for every NEXSUS screen.
class NexsusTheme {
  static const Color background = Color(0xFF101114);
  static const Color surface = Color(0xFF1A1C20);
  static const Color surfaceRaised = Color(0xFF22252A);
  static const Color accent = Color(0xFFB7A2F6);
  static const Color textMuted = Color(0xFF9A9DA5);

  static ThemeData build({Color accentColor = accent, String? fontFamily}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: accentColor,
      onPrimary: const Color(0xFF17131F),
      secondary: accentColor,
      surface: surface,
      onSurface: const Color(0xFFF2F1F5),
      outline: const Color(0xFF393C43),
    );

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      fontFamily: fontFamily,
      dividerColor: const Color(0xFF303238),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: Color(0xFFF2F1F5),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceRaised,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF393C43)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFF393C43)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: accentColor, width: 1.4),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: const Color(0xFF17131F),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: shape,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE6E3EC),
          side: const BorderSide(color: Color(0xFF454850)),
          shape: shape,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF17191D),
        indicatorColor: accentColor.withValues(alpha: .16),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
          TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
            color: states.contains(WidgetState.selected) ? accentColor : textMuted,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: const Color(0xFF17131F),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceRaised,
        selectedColor: accentColor.withValues(alpha: .18),
        side: const BorderSide(color: Color(0xFF393C43)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: const TextStyle(color: Color(0xFFE6E3EC)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceRaised,
        contentTextStyle: const TextStyle(color: Color(0xFFF2F1F5)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
