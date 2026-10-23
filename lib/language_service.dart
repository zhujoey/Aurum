import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LanguageService {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal();

  final ValueNotifier<Locale> currentLocale = ValueNotifier<Locale>(const Locale('en'));
  final ValueNotifier<int> appLanguageVersion = ValueNotifier<int>(0);

  final Map<String, Map<String, String>> _autoCache = {};
  final Set<String> _pending = {};
  final Set<String> _encounteredStrings = {};

  static const Map<String, Map<String, String>> supportedLanguages = {
    'en': {'name': 'English', 'native': 'English', 'flag': '🇺🇸'},
    'fr': {'name': 'French', 'native': 'Français', 'flag': '🇫🇷'},
    'es': {'name': 'Spanish', 'native': 'Español', 'flag': '🇪🇸'},
    'ar': {'name': 'Arabic', 'native': 'العربية', 'flag': '🇸🇦'},
    'zh': {'name': 'Chinese (Simplified)', 'native': '简体中文', 'flag': '🇨🇳'},
    'zh-TW': {'name': 'Chinese (Traditional)', 'native': '繁體中文', 'flag': '🇹🇼'},
    'ru': {'name': 'Russian', 'native': 'Русский', 'flag': '🇷🇺'},
    'id': {'name': 'Indonesian', 'native': 'Bahasa Indonesia', 'flag': '🇮🇩'},
    'bn': {'name': 'Bengali', 'native': 'বাংলা', 'flag': '🇧🇩'},
    'de': {'name': 'German', 'native': 'Deutsch', 'flag': '🇩🇪'},
    'it': {'name': 'Italian', 'native': 'Italiano', 'flag': '🇮🇹'},
    'tr': {'name': 'Turkish', 'native': 'Türkçe', 'flag': '🇹🇷'},
    'ja': {'name': 'Japanese', 'native': '日本語', 'flag': '🇯🇵'},
    'ko': {'name': 'Korean', 'native': '한국어', 'flag': '🇰🇷'},
    'pt': {'name': 'Portuguese', 'native': 'Português', 'flag': '🇧🇷'},
    'hi': {'name': 'Hindi', 'native': 'हिन्दी', 'flag': '🇮🇳'},
  };

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? langCode = prefs.getString('selected_language_code');
    if (langCode != null && supportedLanguages.containsKey(langCode)) {
      currentLocale.value = Locale(langCode);
    }

    // Defer heavy cache loading and network pre-warming to background after app launch
    Future.microtask(() async {
      try {
        final String? cacheJson = prefs.getString('auto_translations_cache');
        if (cacheJson != null) {
          final Map<String, dynamic> decoded = jsonDecode(cacheJson);
          decoded.forEach((lang, map) {
            if (map is Map) {
              _autoCache[lang] = map.map((k, v) => MapEntry(k.toString(), v.toString()));
            }
          });
        }

        final String? encounteredJson = prefs.getString('encountered_strings');
        if (encounteredJson != null) {
          final List<dynamic> list = jsonDecode(encounteredJson);
          _encounteredStrings.addAll(list.map((e) => e.toString()));
        }

        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _loadCloudLanguage(user.uid);
        }

        if (currentLocale.value.languageCode != 'en') {
          _prewarmCache(currentLocale.value.languageCode);
        }
      } catch (e) {
        debugPrint("Error in background LanguageService init: $e");
      }
    });
  }

  void _loadCloudLanguage(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final String? savedLang = doc.data()?['selectedLanguage'] as String?;
        if (savedLang != null && savedLang.isNotEmpty && supportedLanguages.containsKey(savedLang)) {
          currentLocale.value = Locale(savedLang);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('selected_language_code', savedLang);
        }
      }
    } catch (e) {
      debugPrint("LanguageService init: Error loading firestore language: $e");
    }
  }

  Future<void> _saveAutoCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auto_translations_cache', jsonEncode(_autoCache));
    } catch (e) {
      debugPrint("Error saving auto translation cache: $e");
    }
  }

  Future<void> _saveEncounteredStrings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encountered_strings', jsonEncode(_encounteredStrings.toList()));
    } catch (e) {
      debugPrint("Error saving encountered strings: $e");
    }
  }

  Future<void> setLanguage(String langCode, {bool updateFirestore = true}) async {
    if (!supportedLanguages.containsKey(langCode)) return;
    if (currentLocale.value.languageCode == langCode && updateFirestore == false) return;

    bool changed = currentLocale.value.languageCode != langCode;
    currentLocale.value = Locale(langCode);
    if (changed) appLanguageVersion.value++;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language_code', langCode);

    if (langCode != 'en') {
      _prewarmCache(langCode);
    }

    if (updateFirestore) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'selectedLanguage': langCode,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint("LanguageService: Error updating firestore language: $e");
        }
      }
    }
  }

  Map<String, String> get currentLanguageInfo =>
      supportedLanguages[currentLocale.value.languageCode] ?? supportedLanguages['en']!;

  static String tr(String text) {
    if (text.isEmpty) return text;

    // Normalize abbreviations so translation APIs translate them correctly (e.g. Indiv. -> Individual)
    String queryText = text;
    if (queryText.contains('(Indiv.)')) {
      queryText = queryText.replaceAll('(Indiv.)', '(Individual)');
    } else if (queryText.contains('Indiv.')) {
      queryText = queryText.replaceAll('Indiv.', 'Individual');
    }

    final service = LanguageService();
    final langCode = service.currentLocale.value.languageCode;
    if (langCode == 'en') return text;

    // Automatically track encountered UI strings
    if (!service._encounteredStrings.contains(text)) {
      service._encounteredStrings.add(text);
      service._saveEncounteredStrings();
    }

    // 1. Check auto-translation cache (instant O(1) lookup for original and queryText)
    final autoMap = service._autoCache[langCode];
    if (autoMap != null) {
      if (autoMap.containsKey(text)) {
        return autoMap[text]!;
      }
      if (autoMap.containsKey(queryText)) {
        return autoMap[queryText]!;
      }
    }

    // 2. Trigger silent background auto-translation fetch (no screen flashing)
    service._fetchAutoTranslation(queryText, langCode);

    // Return original text immediately so UI never blocks or lags
    return text;
  }

  Future<void> _prewarmCache(String targetLang) async {
    if (_encounteredStrings.isEmpty) return;
    final cached = _autoCache[targetLang] ?? {};
    final untranslated = _encounteredStrings.where((s) => !cached.containsKey(s)).toList();
    if (untranslated.isEmpty) return;

    // Concurrent batch pre-fetching (5 items at a time) for blazing fast translation
    for (int i = 0; i < untranslated.length; i += 5) {
      final batch = untranslated.skip(i).take(5);
      await Future.wait(batch.map((text) => _fetchAutoTranslation(text, targetLang)));
    }
  }

  Future<void> _fetchAutoTranslation(String text, String targetLang) async {
    final key = '${targetLang}_$text';
    if (_pending.contains(key)) return;
    _pending.add(key);

    try {
      String apiLang = targetLang;
      if (targetLang == 'zh') {
        apiLang = 'zh-CN';
      } else if (targetLang == 'zh-TW') {
        apiLang = 'zh-TW';
      }

      final Uri uri = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(text)}&langpair=en|$apiLang',
      );
      final client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final String body = await response.transform(utf8.decoder).join();
        final Map<String, dynamic> data = jsonDecode(body);
        final String? translated = data['responseData']?['translatedText'];

        if (translated != null && translated.isNotEmpty && translated.toLowerCase() != text.toLowerCase()) {
          _autoCache.putIfAbsent(targetLang, () => {})[text] = translated;
          await _saveAutoCache();
        }
      }
    } catch (e) {
      debugPrint("Auto translation error for '$text': $e");
    } finally {
      _pending.remove(key);
    }
  }
}

extension StringTranslationExtension on String {
  String get tr => LanguageService.tr(this);
}
