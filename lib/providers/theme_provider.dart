import 'package:flutter/material.dart';
import '../repositories/theme_repository.dart';

/// State Manager for application-wide theme mode (Light/Dark).
/// Integrates with [ThemeRepository] to persist options across restarts.
class ThemeProvider extends ChangeNotifier {
  final ThemeRepository _repository;
  ThemeMode _themeMode;

  ThemeProvider({
    required ThemeRepository repository,
    required bool initialIsDark,
  })  : _repository = repository,
        _themeMode = initialIsDark ? ThemeMode.dark : ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Toggles between Light and Dark mode, persisting preference instantly.
  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
      _repository.setDarkMode(true);
    } else {
      _themeMode = ThemeMode.light;
      _repository.setDarkMode(false);
    }
    notifyListeners();
  }
}
