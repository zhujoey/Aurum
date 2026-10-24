import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<Color> seedColor = ValueNotifier(Colors.blue);
  final ValueNotifier<bool> useTrueDark = ValueNotifier(false);

  Future<void> init([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    
    // Theme Mode
    final savedTheme = p.getString('themeMode');
    if (savedTheme == 'light') {
      themeMode.value = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      themeMode.value = ThemeMode.dark;
    } else {
      themeMode.value = ThemeMode.system;
    }

    // Seed Color
    final savedColor = p.getInt('seedColor');
    if (savedColor != null) {
      seedColor.value = Color(savedColor);
    }

    // True Dark (AMOLED Always On)
    useTrueDark.value = true;
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
  }

  Future<void> setColor(Color color) async {
    seedColor.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('seedColor', color.toARGB32());
  }

  Future<void> setTrueDark(bool value) async {
    useTrueDark.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('useTrueDark', value);
  }
}
