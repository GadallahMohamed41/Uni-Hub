import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the app's active locale, toggling strictly between
/// English `Locale('en')` and Arabic `Locale('ar')`.
class LocaleProvider extends ChangeNotifier {
  static const String _prefKey = 'app_locale';
  Locale _locale = const Locale('en');

  LocaleProvider() {
    _loadSavedLocale();
  }

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  /// Flips the locale between English and Arabic.
  void toggleLocale() {
    _locale = isArabic ? const Locale('en') : const Locale('ar');
    _persistLocale(_locale);
    notifyListeners();
  }

  /// Set locale directly.
  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    _persistLocale(_locale);
    notifyListeners();
  }

  Future<void> _loadSavedLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefKey);
    if (code == null || code.isEmpty) return;
    final next = Locale(code);
    if (_locale == next) return;
    _locale = next;
    notifyListeners();
  }

  Future<void> _persistLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.languageCode);
  }
}
