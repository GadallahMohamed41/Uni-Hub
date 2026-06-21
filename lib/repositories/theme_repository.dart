import 'package:shared_preferences/shared_preferences.dart';

/// A repository responsible solely for reading and writing 
/// the user's theme preference locally.
class ThemeRepository {
  final SharedPreferences _prefs;
  static const String _themeKey = 'is_dark_mode';

  ThemeRepository(this._prefs);

  /// Reads the stored preference. If none exists, defaults to false (Light Mode).
  bool isDarkMode() {
    return _prefs.getBool(_themeKey) ?? false;
  }

  /// Persists the selected preference locally.
  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_themeKey, value);
  }
}
