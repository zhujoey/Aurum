import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';

class ThemeService {
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  static const MethodChannel _themeChannel = MethodChannel('com.example.aurum/theme');

  final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.dark);
  final ValueNotifier<Color> seedColor = ValueNotifier(Colors.blue);
  final ValueNotifier<bool> useTrueDark = ValueNotifier(false);

  Future<void> init([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    
    // Theme Mode
    final savedTheme = p.getString('themeMode');
    if (savedTheme == 'light') {
      themeMode.value = ThemeMode.light;
    } else if (savedTheme == 'system') {
      themeMode.value = ThemeMode.system;
    } else {
      themeMode.value = ThemeMode.dark;
    }

    // Seed Color
    final savedColor = p.getInt('seedColor');
    if (savedColor != null) {
      seedColor.value = Color(savedColor);
    }

    // True Dark (AMOLED Always On)
    useTrueDark.value = true;

    // Sync app icon and native night mode with current theme
    await updateAppIcon(themeMode.value);
    await updateNativeNightMode(themeMode.value);
  }

  Future<void> updateAppIcon(ThemeMode mode) async {
    try {
      if (await FlutterDynamicIconPlus.supportsAlternateIcons) {
        bool isDark = false;
        if (mode == ThemeMode.dark) {
          isDark = true;
        } else if (mode == ThemeMode.light) {
          isDark = false;
        } else {
          final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
          isDark = brightness == Brightness.dark;
        }
        
        final targetIcon = isDark ? 'logo_dark' : 'logo_light';
        final currentIcon = await FlutterDynamicIconPlus.alternateIconName;
        final cleanCurrent = currentIcon?.replaceAll('.', '');
        final cleanTarget = targetIcon.replaceAll('.', '');

        if (cleanCurrent != cleanTarget) {
          await FlutterDynamicIconPlus.setAlternateIconName(
            iconName: targetIcon,
            isSilent: true,
          );
        }
      }
    } catch (e) {
      debugPrint("Dynamic app icon update notice: $e");
    }
  }

  Future<void> updateNativeNightMode(ThemeMode mode) async {
    try {
      await _themeChannel.invokeMethod('setNativeNightMode', {'mode': mode.name});
    } catch (e) {
      debugPrint("Native night mode update notice: $e");
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.name);
    await updateAppIcon(mode);
    await updateNativeNightMode(mode);
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
