import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../service/voice_guide.dart';
import '../utils/app_colors.dart';

/// Global user preferences: language (FR default) + light/dark mode.
///
/// Loaded in main() BEFORE runApp so the first frame already uses the right
/// palette/language. Toggling notifies listeners; the root RestartWidget then
/// remounts the tree so every screen (including ones that read AppColors
/// statics) repaints with the new values.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  static const _kDarkKey = 'app_dark_mode';
  static const _kLangKey = 'app_language';

  bool _isDark = false;
  String _lang = 'fr'; // French is the app default

  bool get isDark => _isDark;
  String get lang => _lang;
  bool get isFr => _lang == 'fr';

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDark = prefs.getBool(_kDarkKey) ?? false;
      _lang = prefs.getString(_kLangKey) ?? 'fr';
    } catch (_) {/* defaults */}
    AppColors.apply(dark: _isDark);
    VoiceGuide.instance.setLanguage(_lang == 'fr' ? 'fr-FR' : 'en-US');
  }

  Future<void> setDark(bool dark) async {
    if (dark == _isDark) return;
    _isDark = dark;
    AppColors.apply(dark: dark);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kDarkKey, dark);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setLang(String lang) async {
    if (lang == _lang) return;
    _lang = lang;
    VoiceGuide.instance.setLanguage(lang == 'fr' ? 'fr-FR' : 'en-US');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangKey, lang);
    } catch (_) {}
    notifyListeners();
  }
}
