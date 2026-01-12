import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider that manages app theme mode (light/dark)
/// Persists user preference using shared_preferences
class ThemeProvider extends ChangeNotifier {
  static const _themeModeKey = 'theme_mode';
  ThemeMode _themeMode = ThemeMode.light; // Default to light mode

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Load saved theme preference from local storage
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMode = prefs.getString(_themeModeKey);
      if (savedMode != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == savedMode,
          orElse: () => ThemeMode.light,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _saveThemePreference();
  }

  /// Save theme preference to local storage
  Future<void> _saveThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, _themeMode.toString());
    } catch (e) {
      debugPrint('Failed to save theme preference: $e');
    }
  }
}
