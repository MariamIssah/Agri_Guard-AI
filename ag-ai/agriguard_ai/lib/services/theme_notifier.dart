import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const _key = 'agri_theme_dark';

  bool _isDark = false;
  bool get isDark => _isDark;
  ThemeMode get themeMode => _isDark ? ThemeMode.dark : ThemeMode.light;

  ThemeNotifier(bool isDark) : _isDark = isDark;

  static Future<ThemeNotifier> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemeNotifier(prefs.getBool(_key) ?? false);
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
    notifyListeners();
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, _isDark);
    notifyListeners();
  }
}
