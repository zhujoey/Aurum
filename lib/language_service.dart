import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  final ValueNotifier<Locale> currentLocale = ValueNotifier<Locale>(const Locale('en'));

  // Official UN Languages + Convenient Global Sports Languages
  static const Map<String, Map<String, String>> supportedLanguages = {
    'en': {'name': 'English', 'native': 'English', 'flag': '🇺🇸', 'type': 'Official UN Language'},
    'fr': {'name': 'French', 'native': 'Français', 'flag': '🇫🇷', 'type': 'Official UN Language'},
    'es': {'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸', 'type': 'Official UN Language'},
    'ar': {'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦', 'type': 'Official UN Language'},
    'zh': {'name': 'Chinese', 'native': '简体中文', 'flag': '🇨🇳', 'type': 'Official UN Language'},
    'ru': {'name': 'Russian', 'native': 'Русский', 'flag': '🇷🇺', 'type': 'Official UN Language'},
    'de': {'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪', 'type': 'Global Sport Language'},
    'ja': {'name': 'Japanese', 'native': '日本語', 'flag': '🇯🇵', 'type': 'Global Sport Language'},
    'ko': {'name': 'Korean', 'native': '한국어', 'flag': '🇰🇷', 'type': 'Global Sport Language'},
    'pt': {'name': 'Portuguese', 'native': 'Português', 'flag': '🇧🇷', 'type': 'Global Sport Language'},
    'hi': {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳', 'type': 'Global Sport Language'},
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('selected_language_code');
    if (langCode != null && supportedLanguages.containsKey(langCode)) {
      currentLocale.value = Locale(langCode);
    }
  }

  Future<void> setLanguage(String langCode) async {
    if (!supportedLanguages.containsKey(langCode)) return;
    currentLocale.value = Locale(langCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', langCode);
  }

  Map<String, String> get currentLanguageInfo =>
      supportedLanguages[currentLocale.value.languageCode] ?? supportedLanguages['en']!;
}
