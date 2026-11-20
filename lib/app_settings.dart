import 'app_text.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  static const _themeKey = 'nexsus_theme_v1';
  static const _fontKey = 'nexsus_font_v1';
  static const _scaleKey = 'nexsus_scale_v1';
  static const _backgroundKey = 'nexsus_background_v1';
  static const _languageKey = 'nexsus_language_v1';

  String theme = 'violet';
  String font = 'system';
  String background = 'midnight';
  double fontScale = 1.0;
  String language = 'ru';

  Color get accent => const {
    'violet': Color(0xFF8050FF),
    'blue': Color(0xFF398BFF),
    'emerald': Color(0xFF24B889),
    'rose': Color(0xFFE45D9A),
    'amber': Color(0xFFFFB84D),
    'cyan': Color(0xFF22C7D6),
    'crimson': Color(0xFFE34D65),
  }[theme] ?? const Color(0xFF8050FF);

  Color get scaffoldColor => background == 'black'
      ? const Color(0xFF030407)
      : background == 'navy'
          ? const Color(0xFF071426)
          : background == 'forest'
              ? const Color(0xFF071A17)
              : const Color(0xFF070817);

  String? get fontFamily => const {
    'serif': 'serif',
    'mono': 'monospace',
  }[font];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    theme = prefs.getString(_themeKey) ?? theme;
    font = prefs.getString(_fontKey) ?? font;
    background = prefs.getString(_backgroundKey) ?? background;
    fontScale = prefs.getDouble(_scaleKey) ?? fontScale;
    language = prefs.getString(_languageKey) ?? language;
    AppText.language = language;
    notifyListeners();
  }

  Future<void> setTheme(String value) async {
    theme = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, value);
  }

  Future<void> setFont(String value) async {
    font = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, value);
  }

  Future<void> setBackground(String value) async {
    background = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_backgroundKey, value);
  }

  Future<void> setLanguage(String value) async {
    language = value;
    AppText.language = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  Future<void> setFontScale(double value) async {
    fontScale = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_scaleKey, value);
  }
}

