import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeNotifier() {
    _loadTheme();
  }

  static const _prefsKey = 'isDarkMode';
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefsKey);
      if (saved != null) {
        _mode = saved ? ThemeMode.dark : ThemeMode.light;
      } else {
        final hour = DateTime.now().hour;
        final isDarkMode = hour >= 18 || hour < 6; // Dark mode between 6 PM and 6 AM
        _mode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      }
    } catch (_) {
      final hour = DateTime.now().hour;
      final isDarkMode = hour >= 18 || hour < 6;
      _mode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, isDark);
    } catch (_) {}
  }
}
