import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
    'en': {'name': 'English', 'native': 'English', 'flag': '🇺🇸 🇬🇧'},
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

  Future<void> init([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    final String? langCode = p.getString('selected_language_code');
    if (langCode != null && supportedLanguages.containsKey(langCode)) {
      currentLocale.value = Locale(langCode);
    }

    // Defer heavy JSON cache parsing and network operations to background microtask
    Future.microtask(() async {
      try {
        final String? cacheJson = p.getString('auto_translations_cache');
        if (cacheJson != null) {
          final Map<String, dynamic> decoded = jsonDecode(cacheJson);
          decoded.forEach((lang, map) {
            if (map is Map) {
              _autoCache[lang] = map.map((k, v) => MapEntry(k.toString(), v.toString()));
            }
          });
        }

        final String? encounteredJson = p.getString('encountered_strings');
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

  static const Map<String, Map<String, String>> _staticTranslations = {
    'es': {
      'Settings': 'Configuración',
      'Rankings': 'Clasificación',
      'Clubs': 'Clubes',
      'Quick Match': 'Partida Rápida',
      'Tournaments': 'Torneos',
      'Open Singles': 'Individuales Abiertos',
      'My Clubs': 'Mis Clubes',
      'Create': 'Crear',
      'Select Sport': 'Seleccionar Deporte',
      'Table Tennis Setup': 'Configuración de Tenis de Mesa',
      'Badminton Setup': 'Configuración de Bádminton',
      'Tennis Setup': 'Configuración de Tenis',
      'Game Type': 'Tipo de Juego',
      'Match Format': 'Formato de Partido',
      'Players': 'Jugadores',
      'Timer Options': 'Opciones de Temporizador',
      'Keep running timers when page not loaded': 'Mantener temporizadores activos cuando la página no esté cargada',
      'Timer continues running even when you leave the match screen': 'El temporizador sigue funcionando incluso al salir de la pantalla de partido',
      'Start Match': 'Iniciar Partido',
      'Home Side': 'Lado Local',
      'Away Side': 'Lado Visitante',
      'Warmup': 'Calentamiento',
      'Skip': 'Omitir',
      'Singles': 'Individuales',
      'Dobles': 'Dobles',
      'Me': 'Yo',
      'Guest': 'Invitado',
      'Invite': 'Invitar',
      'Custom': 'Personalizado',
      'First to 4 sets': 'Primero a 4 sets',
      'First to 3 sets': 'Primero a 3 sets',
      'Friends': 'Amigos',
      'Login': 'Iniciar Sesión',
      'Sign Up': 'Registrarse',
      'Email': 'Correo Electrónico',
      'Password': 'Contraseña',
      'Remember Me': 'Recordarme',
      'Forgot Password?': '¿Olvidaste tu contraseña?',
      'Send Link': 'Enviar Enlace',
      'OR': 'O',
      'Sign in with Google': 'Iniciar sesión con Google',
      'Username': 'Nombre de usuario',
      'Gender': 'Género',
      'Male': 'Masculino',
      'Female': 'Femenino',
      'Verified': 'Verificado',
      'Unverified': 'No verificado',
      'Cancel': 'Cancelar',
      'Confirm': 'Confirmar',
      'Save': 'Guardar',
      'Delete': 'Eliminar',
      'Remove': 'Quitar',
      'Back': 'Atrás',
      'Next': 'Siguiente',
      'Search': 'Buscar',
      'Notifications': 'Notificaciones',
      'Requests': 'Solicitudes',
      'Accept': 'Aceptar',
      'Decline': 'Rechazar',
      'Badminton': 'Bádminton',
      'Tennis': 'Tenis',
      'Table Tennis': 'Tenis de Mesa',
      'This tournament is closed. Only an owner or manager can invite you.': 'Este torneo está cerrado. Solo un propietario o administrador puede invitarte.',
      'Tournament Match History': 'Historial de Partidos del Torneo',
      'No completed matches in history yet.': 'Aún no hay partidos completados en el historial.',
      'Participants': 'Participantes',
      'No participants yet.': 'Aún no hay participantes.',
      'Player 1': 'Jugador 1',
      'Player 2': 'Jugador 2',
      'Player 3': 'Jugador 3',
      'Player 4': 'Jugador 4',
      'Ready to make today count, {name}?': '¿Listo para hacer que hoy cuente, {name}?',
      'Small daily wins add up, {name}.': 'Las pequeñas victorias diarias suman, {name}.',
      'Focus on progress, not perfection.': 'Concéntrate en el progreso, no en la perfección.',
      'Your next personal best starts right now.': 'Tu próxima marca personal empieza ahora mismo.',
      'Keep pushing your limits today, {name}.': 'Sigue superando tus límites hoy, {name}.',
      'Every match makes you sharper.': 'Cada partido te hace más agudo.',
      'Time to put in the work, {name}.': 'Es hora de ponerse a trabajar, {name}.',
      'Stay sharp, stay hungry.': 'Mantente alerta, mantente hambriento de éxito.',
      'Consistency is your superpower.': 'La consistencia es tu superpoder.',
      'One step closer to your goals, {name}.': 'Un paso más cerca de tus metas, {name}.',
      'Let\'s make today productive, {name}.': 'Hagamos que hoy sea productivo, {name}.',
      'Trust the process and play your game.': 'Confía en el proceso y juega tu juego.',
      'Discipline beats motivation, {name}.': 'La disciplina supera a la motivación, {name}.',
      'Own your momentum today.': 'Dueño de tu momento hoy.',
      'Greatness is built one step at a time, {name}.': 'La grandeza se construye paso a paso, {name}.',
      'Keep moving forward, {name}.': 'Sigue adelante, {name}.',
      'Chasing excellence, one day at a time.': 'Persiguiendo la excelencia, un día a la vez.',
      'Your potential is endless, {name}.': 'Tu potencial es infinito, {name}.',
    },
    'fr': {
      'Settings': 'Paramètres',
      'Rankings': 'Classement',
      'Clubs': 'Clubs',
      'Quick Match': 'Match Rapide',
      'Tournaments': 'Tournois',
      'Open Singles': 'Simple Ouvert',
      'My Clubs': 'Mes Clubs',
      'Create': 'Créer',
      'Select Sport': 'Sélectionner le sport',
      'Table Tennis Setup': 'Configuration Tennis de Table',
      'Badminton Setup': 'Configuration Badminton',
      'Tennis Setup': 'Configuration Tennis',
      'Game Type': 'Type de Jeu',
      'Match Format': 'Format du Match',
      'Players': 'Joueurs',
      'Timer Options': 'Options du Minuteur',
      'Keep running timers when page not loaded': 'Garder les minuteurs actifs si la page n\'est pas chargée',
      'Timer continues running even when you leave the match screen': 'Le minuteur continue même en quittant l\'écran du match',
      'Start Match': 'Commencer le Match',
      'Home Side': 'Côté Domicile',
      'Away Side': 'Côté Extérieur',
      'Warmup': 'Échauffement',
      'Skip': 'Passer',
      'Singles': 'Simple',
      'Doubles': 'Double',
      'Me': 'Moi',
      'Guest': 'Invité',
      'Invite': 'Inviter',
      'Custom': 'Personnalisé',
      'First to 4 sets': 'Premier à 4 sets',
      'First to 3 sets': 'Premier à 3 sets',
      'Ready to make today count, {name}?': 'Prêt à faire compter la journée, {name} ?',
      'Small daily wins add up, {name}.': 'Les petites victoires quotidiennes s\'accumulent, {name}.',
      'Focus on progress, not perfection.': 'Concentrez-vous sur les progrès, pas sur la perfection.',
      'Your next personal best starts right now.': 'Votre prochain record personnel commence dès maintenant.',
      'Keep pushing your limits today, {name}.': 'Continuez à repousser vos limites aujourd\'hui, {name}.',
      'Every match makes you sharper.': 'Chaque match vous rend plus affûté.',
      'Time to put in the work, {name}.': 'Il est temps de se mettre au travail, {name}.',
      'Stay sharp, stay hungry.': 'Restez affûté, restez ambitieux.',
      'Consistency is your superpower.': 'La régularité est votre super-pouvoir.',
      'One step closer to your goals, {name}.': 'Un pas de plus vers vos objectifs, {name}.',
      'Let\'s make today productive, {name}.': 'Faisons de cette journée une journée productive, {name}.',
      'Trust the process and play your game.': 'Faites confiance au processus et jouez votre jeu.',
      'Discipline beats motivation, {name}.': 'La discipline l\'emporte sur la motivation, {name}.',
      'Own your momentum today.': 'Maîtrisez votre élan aujourd\'hui.',
      'Greatness is built one step at a time, {name}.': 'La grandeur se construit un pas à la fois, {name}.',
      'Keep moving forward, {name}.': 'Continuez d\'avancer, {name}.',
      'Chasing excellence, one day at a time.': 'À la poursuite de l\'excellence, un jour à la fois.',
      'Your potential is endless, {name}.': 'Votre potentiel est infini, {name}.',
      'Friends': 'Amis',
      'Login': 'Connexion',
      'Sign Up': 'S\'inscrire',
      'Email': 'E-mail',
      'Password': 'Mot de passe',
      'Remember Me': 'Se souvenir de moi',
      'Forgot Password?': 'Mot de passe oublié ?',
      'Send Link': 'Envoyer le lien',
      'OR': 'OU',
      'Sign in with Google': 'Se connecter avec Google',
      'Username': 'Nom d\'utilisateur',
      'Gender': 'Genre',
      'Male': 'Homme',
      'Female': 'Femme',
      'Verified': 'Vérifié',
      'Unverified': 'Non vérifié',
      'Cancel': 'Annuler',
      'Confirm': 'Confirmer',
      'Save': 'Enregistrer',
      'Delete': 'Supprimer',
      'Remove': 'Retirer',
      'Back': 'Retour',
      'Next': 'Suivant',
      'Search': 'Rechercher',
      'Notifications': 'Notifications',
      'Requests': 'Demandes',
      'Accept': 'Accepter',
      'Decline': 'Refuser',
      'Badminton': 'Badminton',
      'Tennis': 'Tennis',
      'Table Tennis': 'Tennis de Table',
    },
    'de': {
      'Settings': 'Einstellungen',
      'Rankings': 'Rangliste',
      'Clubs': 'Clubs',
      'Quick Match': 'Schnellspiel',
      'Tournaments': 'Turniere',
      'Open Singles': 'Offenes Einzel',
      'My Clubs': 'Meine Clubs',
      'Create': 'Erstellen',
      'Select Sport': 'Sportart wählen',
      'Table Tennis Setup': 'Tischtennis-Setup',
      'Badminton Setup': 'Badminton-Setup',
      'Tennis Setup': 'Tennis-Setup',
      'Game Type': 'Spieltyp',
      'Match Format': 'Match-Format',
      'Players': 'Spieler',
      'Timer Options': 'Timer-Optionen',
      'Keep running timers when page not loaded': 'Timer laufen lassen, wenn Seite nicht geladen ist',
      'Timer continues running even when you leave the match screen': 'Timer läuft weiter, auch wenn Sie den Match-Bildschirm verlassen',
      'Start Match': 'Spiel starten',
      'Home Side': 'Heimseite',
      'Away Side': 'Auswärtsseite',
      'Warmup': 'Aufwärmen',
      'Skip': 'Überspringen',
      'Singles': 'Einzel',
      'Doubles': 'Doppel',
      'Me': 'Ich',
      'Guest': 'Gast',
      'Invite': 'Einladen',
      'Custom': 'Benutzerdefiniert',
      'First to 4 sets': 'Erster zu 4 Sätzen',
      'First to 3 sets': 'Erster zu 3 Sätzen',
      'Friends': 'Freunde',
      'Login': 'Anmelden',
      'Sign Up': 'Registrieren',
      'Email': 'E-Mail',
      'Password': 'Passwort',
      'Remember Me': 'Angemeldet bleiben',
      'Forgot Password?': 'Passwort vergessen?',
      'Send Link': 'Link senden',
      'OR': 'ODER',
      'Sign in with Google': 'Mit Google anmelden',
      'Username': 'Benutzername',
      'Gender': 'Geschlecht',
      'Male': 'Männlich',
      'Female': 'Weiblich',
      'Verified': 'Verifiziert',
      'Unverified': 'Unverifiziert',
      'Cancel': 'Abbrechen',
      'Confirm': 'Bestätigen',
      'Save': 'Speichern',
      'Delete': 'Löschen',
      'Remove': 'Entfernen',
      'Back': 'Zurück',
      'Next': 'Weiter',
      'Search': 'Suchen',
      'Notifications': 'Benachrichtigungen',
      'Requests': 'Anfragen',
      'Accept': 'Annehmen',
      'Decline': 'Ablehnen',
      'Badminton': 'Badminton',
      'Tennis': 'Tennis',
      'Table Tennis': 'Tischtennis',
    },
    'zh': {
      'Settings': '设置',
      'Rankings': '排行榜',
      'Clubs': '俱乐部',
      'Quick Match': '快速比赛',
      'Tournaments': '锦标赛',
      'Open Singles': '公开单打',
      'My Clubs': '我的俱乐部',
      'Create': '创建',
      'Select Sport': '选择运动',
      'Table Tennis Setup': '乒乓球设置',
      'Badminton Setup': '羽毛球设置',
      'Tennis Setup': '网球设置',
      'Game Type': '比赛类型',
      'Match Format': '比赛形式',
      'Players': '球员',
      'Timer Options': '计时器选项',
      'Keep running timers when page not loaded': '页面未加载时保持计时器运行',
      'Timer continues running even when you leave the match screen': '离开比赛界面时计时器仍继续运行',
      'Start Match': '开始比赛',
      'Home Side': '主场方',
      'Away Side': '客场方',
      'Warmup': '热身',
      'Skip': '跳过',
      'Singles': '单打',
      'Doubles': '双打',
      'Me': '我',
      'Guest': '访客',
      'Invite': '邀请',
      'Custom': '自定义',
      'First to 4 sets': '先赢得4局',
      'First to 3 sets': '先赢得3局',
      'Friends': '好友',
      'Login': '登录',
      'Sign Up': '注册',
      'Email': '电子邮件',
      'Password': '密码',
      'Remember Me': '记住我',
      'Forgot Password?': '忘记密码？',
      'Send Link': '发送链接',
      'OR': '或',
      'Sign in with Google': '使用谷歌登录',
      'Username': '用户名',
      'Gender': '性别',
      'Male': '男',
      'Female': '女',
      'Verified': '已验证',
      'Unverified': '未验证',
      'Cancel': '取消',
      'Confirm': '确认',
      'Save': '保存',
      'Delete': '删除',
      'Remove': '移除',
      'Back': '返回',
      'Next': '下一步',
      'Search': '搜索',
      'Notifications': '通知',
      'Requests': '请求',
      'Accept': '接受',
      'Decline': '拒绝',
      'Badminton': '羽毛球',
      'Tennis': '网球',
      'Table Tennis': '乒乓球',
    },
    'zh-TW': {
      'Settings': '設定',
      'Rankings': '排行榜',
      'Clubs': '俱樂部',
      'Quick Match': '快速比賽',
      'Tournaments': '錦標賽',
      'Open Singles': '公開單打',
      'My Clubs': '我的俱樂部',
      'Create': '建立',
      'Select Sport': '選擇運動',
      'Table Tennis Setup': '桌球設定',
      'Badminton Setup': '羽球設定',
      'Tennis Setup': '網球設定',
      'Game Type': '比賽類型',
      'Match Format': '比賽形式',
      'Players': '球員',
      'Timer Options': '計時器選項',
      'Keep running timers when page not loaded': '頁面未載入時保持計時器運行',
      'Timer continues running even when you leave the match screen': '離開比賽畫面時計時器仍繼續運行',
      'Start Match': '開始比賽',
      'Home Side': '主場方',
      'Away Side': '客場方',
      'Warmup': '熱身',
      'Skip': '略過',
      'Singles': '單打',
      'Doubles': '雙打',
      'Me': '我',
      'Guest': '訪客',
      'Invite': '邀請',
      'Custom': '自訂',
      'First to 4 sets': '先贏得4局',
      'First to 3 sets': '先贏得3局',
      'Friends': '好友',
      'Login': '登入',
      'Sign Up': '註冊',
      'Email': '電子郵件',
      'Password': '密碼',
      'Remember Me': '記住我',
      'Forgot Password?': '忘記密碼？',
      'Send Link': '傳送連結',
      'OR': '或',
      'Sign in with Google': '使用 Google 登入',
      'Username': '使用者名稱',
      'Gender': '性別',
      'Male': '男',
      'Female': '女',
      'Verified': '已驗證',
      'Unverified': '未驗證',
      'Cancel': '取消',
      'Confirm': '確認',
      'Save': '儲存',
      'Delete': '刪除',
      'Remove': '移除',
      'Back': '返回',
      'Next': '下一步',
      'Search': '搜尋',
      'Notifications': '通知',
      'Requests': '請求',
      'Accept': '接受',
      'Decline': '拒絕',
      'Badminton': '羽球',
      'Tennis': '網球',
      'Table Tennis': '桌球',
    },
    'ja': {
      'Settings': '設定',
      'Rankings': 'ランキング',
      'Clubs': 'クラブ',
      'Quick Match': 'クイックマッチ',
      'Tournaments': 'トーナメント',
      'Open Singles': 'オープンシングルス',
      'My Clubs': 'マイクラブ',
      'Create': '作成',
      'Select Sport': 'スポーツを選択',
      'Table Tennis Setup': '卓球設定',
      'Badminton Setup': 'バドミントン設定',
      'Tennis Setup': 'テニス設定',
      'Game Type': 'ゲームタイプ',
      'Match Format': 'マッチ形式',
      'Players': 'プレイヤー',
      'Timer Options': 'タイマーオプション',
      'Keep running timers when page not loaded': 'ページが読み込まれていないときもタイマーを維持する',
      'Timer continues running even when you leave the match screen': '試合画面を離れてもタイマーが動き続けます',
      'Start Match': '試合開始',
      'Home Side': 'ホーム側',
      'Away Side': 'アウェイ側',
      'Warmup': 'ウォーミングアップ',
      'Skip': 'スキップ',
      'Singles': 'シングルス',
      'Doubles': 'ダブルス',
      'Me': '自分',
      'Guest': 'ゲスト',
      'Invite': '招待',
      'Custom': 'カスタム',
      'First to 4 sets': '4セット先取',
      'First to 3 sets': '3セット先取',
      'Friends': 'フレンド',
      'Login': 'ログイン',
      'Sign Up': 'サインアップ',
      'Email': 'メールアドレス',
      'Password': 'パスワード',
      'Remember Me': 'ログイン状態を保持する',
      'Forgot Password?': 'パスワードをお忘れですか？',
      'Send Link': 'リンクを送信',
      'OR': 'または',
      'Sign in with Google': 'Googleでサインイン',
      'Username': 'ユーザー名',
      'Gender': '性別',
      'Male': '男性',
      'Female': '女性',
      'Verified': '認証済み',
      'Unverified': '未認証',
      'Cancel': 'キャンセル',
      'Confirm': '確認',
      'Save': '保存',
      'Delete': '削除',
      'Remove': '削除',
      'Back': '戻る',
      'Next': '次へ',
      'Search': '検索',
      'Notifications': '通知',
      'Requests': 'リクエスト',
      'Accept': '承認',
      'Decline': '拒否',
      'Badminton': 'バドミントン',
      'Tennis': 'テニス',
      'Table Tennis': '卓球',
    },
    'ko': {
      'Settings': '설정',
      'Rankings': '순위',
      'Clubs': '클럽',
      'Quick Match': '빠른 매치',
      'Tournaments': '토너먼트',
      'Open Singles': '오픈 단식',
      'My Clubs': '내 클럽',
      'Create': '만들기',
      'Select Sport': '스포츠 선택',
      'Table Tennis Setup': '탁구 설정',
      'Badminton Setup': '배드민턴 설정',
      'Tennis Setup': '테니스 설정',
      'Game Type': '게임 유형',
      'Match Format': '매치 형식',
      'Players': '플레이어',
      'Timer Options': '타이머 옵션',
      'Keep running timers when page not loaded': '페이지가 로드되지 않았을 때 타이머 유지',
      'Timer continues running even when you leave the match screen': '매치 화면을 떠나도 타이머가 계속 실행됩니다',
      'Start Match': '매치 시작',
      'Home Side': '홈 진영',
      'Away Side': '원정 진영',
      'Warmup': '웜업',
      'Skip': '건너뛰기',
      'Singles': '단식',
      'Doubles': '복식',
      'Me': '나',
      'Guest': '게스트',
      'Invite': '초대',
      'Custom': '사용자 지정',
      'First to 4 sets': '4세트 선승',
      'First to 3 sets': '3세트 선승',
      'Friends': '친구',
      'Login': '로그인',
      'Sign Up': '회원가입',
      'Email': '이메일',
      'Password': '비밀번호',
      'Remember Me': '로그인 상태 유지',
      'Forgot Password?': '비밀번호를 잊으셨나요?',
      'Send Link': '링크 보내기',
      'OR': '또는',
      'Sign in with Google': 'Google로 로그인',
      'Username': '사용자 이름',
      'Gender': '성별',
      'Male': '남성',
      'Female': '여성',
      'Verified': '인증됨',
      'Unverified': '미인증',
      'Cancel': '취소',
      'Confirm': '확인',
      'Save': '저장',
      'Delete': '삭제',
      'Remove': '제거',
      'Back': '뒤로',
      'Next': '다음',
      'Search': '검색',
      'Notifications': '알림',
      'Requests': '요청',
      'Accept': '수락',
      'Decline': '거절',
      'Badminton': '배드민턴',
      'Tennis': '테니스',
      'Table Tennis': '탁구',
    },
    'pt': {
      'Settings': 'Configurações',
      'Rankings': 'Classificação',
      'Clubs': 'Clubes',
      'Quick Match': 'Partida Rápida',
      'Tournaments': 'Torneios',
      'Open Singles': 'Singles Abertos',
      'My Clubs': 'Meus Clubes',
      'Create': 'Criar',
      'Select Sport': 'Selecionar Esporte',
      'Table Tennis Setup': 'Configuração de Tênis de Mesa',
      'Badminton Setup': 'Configuração de Badminton',
      'Tennis Setup': 'Configuração de Tênis',
      'Game Type': 'Tipo de Jogo',
      'Match Format': 'Formato da Partida',
      'Players': 'Jogadores',
      'Timer Options': 'Opções de Timer',
      'Keep running timers when page not loaded': 'Manter timers rodando quando a página não estiver carregada',
      'Timer continues running even when you leave the match screen': 'O timer continua rodando mesmo ao sair da tela da partida',
      'Start Match': 'Iniciar Partida',
      'Home Side': 'Lado da Casa',
      'Away Side': 'Lado Visitante',
      'Warmup': 'Aquecimento',
      'Skip': 'Pular',
      'Singles': 'Simples',
      'Doubles': 'Duplas',
      'Me': 'Eu',
      'Guest': 'Convidado',
      'Invite': 'Convidar',
      'Custom': 'Personalizado',
      'First to 4 sets': 'Primeiro a 4 sets',
      'First to 3 sets': 'Primeiro a 3 sets',
      'Friends': 'Amigos',
      'Login': 'Entrar',
      'Sign Up': 'Cadastrar',
      'Email': 'E-mail',
      'Password': 'Senha',
      'Remember Me': 'Lembrar de mim',
      'Forgot Password?': 'Esqueceu a senha?',
      'Send Link': 'Enviar Link',
      'OR': 'OU',
      'Sign in with Google': 'Entrar com Google',
      'Username': 'Nome de usuário',
      'Gender': 'Gênero',
      'Male': 'Masculino',
      'Female': 'Feminino',
      'Verified': 'Verificado',
      'Unverified': 'Não verificado',
      'Cancel': 'Cancelar',
      'Confirm': 'Confirmar',
      'Save': 'Salvar',
      'Delete': 'Excluir',
      'Remove': 'Remover',
      'Back': 'Voltar',
      'Next': 'Avançar',
      'Search': 'Pesquisar',
      'Notifications': 'Notificações',
      'Requests': 'Solicitações',
      'Accept': 'Aceitar',
      'Decline': 'Recusar',
      'Badminton': 'Badminton',
      'Tennis': 'Tênis',
      'Table Tennis': 'Tênis de Mesa',
    },
    'ar': {
      'Settings': 'الإعدادات',
      'Rankings': 'التصنيفات',
      'Clubs': 'النوادي',
      'Quick Match': 'مباراة سريعة',
      'Tournaments': 'البطولات',
      'Open Singles': 'فردي مفتوح',
      'My Clubs': 'نواديّ',
      'Create': 'إنشاء',
      'Select Sport': 'اختر الرياضة',
      'Table Tennis Setup': 'إعداد تنس الطاولة',
      'Badminton Setup': 'إعداد الريشة الطائرة',
      'Tennis Setup': 'إعداد التنس',
      'Game Type': 'نوع اللعبة',
      'Match Format': 'تنسيق المباراة',
      'Players': 'اللاعبون',
      'Timer Options': 'خيارات المؤقت',
      'Keep running timers when page not loaded': 'إبقاء المؤقتات قيد التشغيل عندما لا يتم تحميل الصفحة',
      'Timer continues running even when you leave the match screen': 'يستمر المؤقت في العمل حتى عند مغادرة شاشة المباراة',
      'Start Match': 'بدء المباراة',
      'Home Side': 'جانب المضيف',
      'Away Side': 'الجانب الضيف',
      'Warmup': 'الإحماء',
      'Skip': 'تخطي',
      'Singles': 'فردي',
      'Doubles': 'زوجي',
      'Me': 'أنا',
      'Guest': 'ضيف',
      'Invite': 'دعوة',
      'Custom': 'مخصص',
      'First to 4 sets': 'الأول إلى 4 مجموعات',
      'First to 3 sets': 'الأول إلى 3 مجموعات',
      'Friends': 'الأصدقاء',
      'Login': 'تسجيل الدخول',
      'Sign Up': 'إنشاء حساب',
      'Email': 'البريد الإلكتروني',
      'Password': 'كلمة المرور',
      'Remember Me': 'تذكرني',
      'Forgot Password?': 'هل نسيت كلمة المرور؟',
      'Send Link': 'إرسال الرابط',
      'OR': 'أو',
      'Sign in with Google': 'تسجيل الدخول بواسطة جوجل',
      'Username': 'اسم المستخدم',
      'Gender': 'الجنس',
      'Male': 'ذكر',
      'Female': 'أنثى',
      'Verified': 'مؤكد',
      'Unverified': 'غير مؤكد',
      'Cancel': 'إلغاء',
      'Confirm': 'تأكيد',
      'Save': 'حفظ',
      'Delete': 'حذف',
      'Remove': 'إزالة',
      'Back': 'رجوع',
      'Next': 'التالي',
      'Search': 'بحث',
      'Notifications': 'الإشعارات',
      'Requests': 'الطلبات',
      'Accept': 'قبول',
      'Decline': 'رفض',
      'Badminton': 'الريشة الطائرة',
      'Tennis': 'التنس',
      'Table Tennis': 'تنس الطاولة',
    },
    'ru': {
      'Settings': 'Настройки',
      'Rankings': 'Рейтинг',
      'Clubs': 'Клубы',
      'Quick Match': 'Быстрый матч',
      'Tournaments': 'Турниры',
      'Open Singles': 'Открытый одиночный',
      'My Clubs': 'Мои клубы',
      'Create': 'Создать',
      'Select Sport': 'Выберите вид спорта',
      'Table Tennis Setup': 'Настройка настольного тенниса',
      'Badminton Setup': 'Настройка бадминтона',
      'Tennis Setup': 'Настройка тенниса',
      'Game Type': 'Тип игры',
      'Match Format': 'Формат матча',
      'Players': 'Игроки',
      'Timer Options': 'Параметры таймера',
      'Keep running timers when page not loaded': 'Продолжать работу таймеров, когда страница не загружена',
      'Timer continues running even when you leave the match screen': 'Таймер продолжает работать даже при выходе с экрана матча',
      'Start Match': 'Начать матч',
      'Home Side': 'Домашняя сторона',
      'Away Side': 'Гостевая сторона',
      'Warmup': 'Разминка',
      'Skip': 'Пропустить',
      'Singles': 'Одиночные',
      'Doubles': 'Парные',
      'Me': 'Я',
      'Guest': 'Гость',
      'Invite': 'Пригласить',
      'Custom': 'Пользовательский',
      'First to 4 sets': 'Первый до 4 сетов',
      'First to 3 sets': 'Первый до 3 сетов',
      'Friends': 'Друзья',
      'Login': 'Войти',
      'Sign Up': 'Регистрация',
      'Email': 'Эл. почта',
      'Password': 'Пароль',
      'Remember Me': 'Запомнить меня',
      'Forgot Password?': 'Забыли пароль?',
      'Send Link': 'Отправить ссылку',
      'OR': 'ИЛИ',
      'Sign in with Google': 'Войти через Google',
      'Username': 'Имя пользователя',
      'Gender': 'Пол',
      'Male': 'Мужской',
      'Female': 'Женский',
      'Verified': 'Подтверждено',
      'Unverified': 'Не подтверждено',
      'Cancel': 'Отмена',
      'Confirm': 'Подтвердить',
      'Save': 'Сохранить',
      'Delete': 'Удалить',
      'Remove': 'Убрать',
      'Back': 'Назад',
      'Next': 'Далее',
      'Search': 'Поиск',
      'Notifications': 'Уведомления',
      'Requests': 'Запросы',
      'Accept': 'Принять',
      'Decline': 'Отклонить',
      'Badminton': 'Бадминтон',
      'Tennis': 'Теннис',
      'Table Tennis': 'Настольный теннис',
    },
    'id': {
      'Settings': 'Pengaturan',
      'Rankings': 'Peringkat',
      'Clubs': 'Klub',
      'Quick Match': 'Pertandingan Cepat',
      'Tournaments': 'Turnamen',
      'Open Singles': 'Tunggal Terbuka',
      'My Clubs': 'Klub Saya',
      'Create': 'Buat',
      'Select Sport': 'Pilih Olahraga',
      'Table Tennis Setup': 'Pengaturan Tenis Meja',
      'Badminton Setup': 'Pengaturan Bulu Tangkis',
      'Tennis Setup': 'Pengaturan Tenis',
      'Game Type': 'Jenis Permainan',
      'Match Format': 'Format Pertandingan',
      'Players': 'Pemain',
      'Timer Options': 'Opsi Pengatur Waktu',
      'Keep running timers when page not loaded': 'Biarkan timer tetap berjalan saat halaman tidak dimuat',
      'Timer continues running even when you leave the match screen': 'Timer terus berjalan bahkan saat Anda meninggalkan layar pertandingan',
      'Start Match': 'Mulai Pertandingan',
      'Home Side': 'Sisi Tuan Rumah',
      'Away Side': 'Sisi Tamu',
      'Warmup': 'Pemanasan',
      'Skip': 'Lewati',
      'Singles': 'Tunggal',
      'Doubles': 'Ganda',
      'Me': 'Saya',
      'Guest': 'Tamu',
      'Invite': 'Undang',
      'Custom': 'Kustom',
      'First to 4 sets': 'Pertama ke 4 set',
      'First to 3 sets': 'Pertama ke 3 set',
      'Friends': 'Teman',
      'Login': 'Masuk',
      'Sign Up': 'Daftar',
      'Email': 'Email',
      'Password': 'Kata Sandi',
      'Remember Me': 'Ingat Saya',
      'Forgot Password?': 'Lupa Kata Sandi?',
      'Send Link': 'Kirim Tautan',
      'OR': 'ATAU',
      'Sign in with Google': 'Masuk dengan Google',
      'Username': 'Nama Pengguna',
      'Gender': 'Jenis Kelamin',
      'Male': 'Laki-laki',
      'Female': 'Perempuan',
      'Verified': 'Terverifikasi',
      'Unverified': 'Belum Terverifikasi',
      'Cancel': 'Batal',
      'Confirm': 'Konfirmasi',
      'Save': 'Simpan',
      'Delete': 'Hapus',
      'Remove': 'Hapus',
      'Back': 'Kembali',
      'Next': 'Berikutnya',
      'Search': 'Cari',
      'Notifications': 'Notifikasi',
      'Requests': 'Permintaan',
      'Accept': 'Terima',
      'Decline': 'Tolak',
      'Badminton': 'Bulu Tangkis',
      'Tennis': 'Tenis',
      'Table Tennis': 'Tenis Meja',
    },
    'tr': {
      'Settings': 'Ayarlar',
      'Rankings': 'Sıralama',
      'Clubs': 'Kulüpler',
      'Quick Match': 'Hızlı Maç',
      'Tournaments': 'Turnuvalar',
      'Open Singles': 'Açık Tekler',
      'My Clubs': 'Kulüplerim',
      'Create': 'Oluştur',
      'Select Sport': 'Spor Seç',
      'Table Tennis Setup': 'Masa Tenisi Kurulumu',
      'Badminton Setup': 'Badminton Kurulumu',
      'Tennis Setup': 'Tenis Kurulumu',
      'Game Type': 'Oyun Türü',
      'Match Format': 'Maç Formatı',
      'Players': 'Oyuncular',
      'Timer Options': 'Zamanlayıcı Seçenekleri',
      'Keep running timers when page not loaded': 'Sayfa yüklenmediğinde zamanlayıcıları çalışmaya devam ettir',
      'Timer continues running even when you leave the match screen': 'Maç ekranından ayrılsanız bile zamanlayıcı çalışmaya devam eder',
      'Start Match': 'Maçı Başlat',
      'Home Side': 'Ev Sahibi Taraf',
      'Away Side': 'Deplasman Tarafı',
      'Warmup': 'Isınma',
      'Skip': 'Atla',
      'Singles': 'Tekler',
      'Doubles': 'Çiftler',
      'Me': 'Ben',
      'Guest': 'Misafir',
      'Invite': 'Davet Et',
      'Custom': 'Özel',
      'First to 4 sets': '4 sete ulaşan kazanır',
      'First to 3 sets': '3 sete ulaşan kazanır',
      'Friends': 'Arkadaşlar',
      'Login': 'Giriş Yap',
      'Sign Up': 'Kayıt Ol',
      'Email': 'E-posta',
      'Password': 'Şifre',
      'Remember Me': 'Beni Hatırla',
      'Forgot Password?': 'Şifrenizi mi unuttunuz?',
      'Send Link': 'Bağlantı Gönder',
      'OR': 'VEYA',
      'Sign in with Google': 'Google ile Giriş Yap',
      'Username': 'Kullanıcı Adı',
      'Gender': 'Cinsiyet',
      'Male': 'Erkek',
      'Female': 'Kadın',
      'Verified': 'Doğrulandı',
      'Unverified': 'Doğrulanmadı',
      'Cancel': 'İptal',
      'Confirm': 'Onayla',
      'Save': 'Kaydet',
      'Delete': 'Sil',
      'Remove': 'Kaldır',
      'Back': 'Geri',
      'Next': 'İleri',
      'Search': 'Ara',
      'Notifications': 'Bildirimler',
      'Requests': 'İstekler',
      'Accept': 'Kabul Et',
      'Decline': 'Reddet',
      'Badminton': 'Badminton',
      'Tennis': 'Tenis',
      'Table Tennis': 'Masa Tenisi',
    },
    'it': {
      'Settings': 'Impostazioni',
      'Rankings': 'Classifica',
      'Clubs': 'Club',
      'Quick Match': 'Partita Rapida',
      'Tournaments': 'Tornei',
      'Open Singles': 'Singolo Aperto',
      'My Clubs': 'I Miei Club',
      'Create': 'Crea',
      'Select Sport': 'Seleziona Sport',
      'Table Tennis Setup': 'Configurazione Tennistavolo',
      'Badminton Setup': 'Configurazione Badminton',
      'Tennis Setup': 'Configurazione Tennis',
      'Game Type': 'Tipo di Gioco',
      'Match Format': 'Formato Partita',
      'Players': 'Giocatori',
      'Timer Options': 'Opzioni Timer',
      'Keep running timers when page not loaded': 'Mantieni i timer attivi quando la pagina non è caricata',
      'Timer continues running even when you leave the match screen': 'Il timer continua a girare anche quando lasci la schermata della partita',
      'Start Match': 'Inizia Partita',
      'Home Side': 'Lato Casa',
      'Away Side': 'Lato Ospite',
      'Warmup': 'Riscaldamento',
      'Skip': 'Salta',
      'Singles': 'Singolo',
      'Doubles': 'Doppio',
      'Me': 'Io',
      'Guest': 'Ospite',
      'Invite': 'Invita',
      'Custom': 'Personalizzato',
      'First to 4 sets': 'Primo a 4 set',
      'First to 3 sets': 'Primo a 3 set',
      'Friends': 'Amici',
      'Login': 'Accedi',
      'Sign Up': 'Registrati',
      'Email': 'E-mail',
      'Password': 'Password',
      'Remember Me': 'Ricordami',
      'Forgot Password?': 'Password dimenticata?',
      'Send Link': 'Invia Link',
      'OR': 'O',
      'Sign in with Google': 'Accedi con Google',
      'Username': 'Nome utente',
      'Gender': 'Genere',
      'Male': 'Maschio',
      'Female': 'Femmina',
      'Verified': 'Verificato',
      'Unverified': 'Non verificato',
      'Cancel': 'Annulla',
      'Confirm': 'Conferma',
      'Save': 'Salva',
      'Delete': 'Elimina',
      'Remove': 'Rimuovi',
      'Back': 'Indietro',
      'Next': 'Avanti',
      'Search': 'Cerca',
      'Notifications': 'Notifiche',
      'Requests': 'Richieste',
      'Accept': 'Accetta',
      'Decline': 'Rifiuta',
      'Badminton': 'Badminton',
      'Tennis': 'Tennis',
      'Table Tennis': 'Tennistavolo',
    },
    'bn': {
      'Settings': 'সেটিংস',
      'Rankings': 'র‍্যাঙ্কিং',
      'Clubs': 'ক্লাব',
      'Quick Match': 'দ্রুত ম্যাচ',
      'Tournaments': 'টুর্নামেন্ট',
      'Open Singles': 'ওপেন একক',
      'My Clubs': 'আমার ক্লাবসমূহ',
      'Create': 'তৈরি করুন',
      'Select Sport': 'খেলা নির্বাচন করুন',
      'Table Tennis Setup': 'টেবিল টেনিস সেটআপ',
      'Badminton Setup': 'ব্যাডমিন্টন সেটআপ',
      'Tennis Setup': 'টেনিস সেটআপ',
      'Game Type': 'গেমের ধরন',
      'Match Format': 'ম্যাচ ফরম্যাট',
      'Players': 'খেলোয়াড়গণ',
      'Timer Options': 'টাইমার বিকল্প',
      'Start Match': 'ম্যাচ শুরু করুন',
      'Home Side': 'হোম সাইড',
      'Away Side': 'অ্যাওয়ে সাইড',
      'Warmup': 'ওয়ার্মআপ',
      'Skip': 'এড়িয়ে যান',
      'Singles': 'একক',
      'Doubles': 'দ্বৈত',
      'Me': 'আমি',
      'Guest': 'অতিথি',
      'Invite': 'আমন্ত্রণ জানান',
      'Custom': 'কাস্টম',
      'Friends': 'বন্ধুরা',
      'Login': 'লগইন',
      'Sign Up': 'সাইন আপ',
      'Email': 'ইমেইল',
      'Password': 'পাসওয়ার্ড',
      'Cancel': 'বাতিল',
      'Confirm': 'নিশ্চিত করুন',
      'Save': 'সংরক্ষণ',
      'Delete': 'মুছে ফেলুন',
      'Search': 'অনুসন্ধান',
      'Notifications': 'বিজ্ঞপ্তি',
      'Accept': 'গ্রহণ করুন',
      'Decline': 'প্রত্যাখ্যান করুন',
      'Badminton': 'ব্যাডমিন্টন',
      'Tennis': 'টেনিস',
      'Table Tennis': 'টেবিল টেনিস',
    },
    'hi': {
      'Settings': 'सेटिंग्स',
      'Rankings': 'रैंकिंग',
      'Clubs': 'क्लब',
      'Quick Match': 'त्वरित मैच',
      'Tournaments': 'टूर्नामेंट',
      'Open Singles': 'ओपन सिंगल्स',
      'My Clubs': 'मेरे क्लब',
      'Create': 'बनाएं',
      'Select Sport': 'खेल चुनें',
      'Table Tennis Setup': 'टेबल टेनिस सेटअप',
      'Badminton Setup': 'बैडमिントン सेटअप',
      'Tennis Setup': 'टेनिस सेटअप',
      'Game Type': 'गेम प्रकार',
      'Match Format': 'मैच प्रारूप',
      'Players': 'खिलाड़ी',
      'Timer Options': 'टाइमर विकल्प',
      'Keep running timers when page not loaded': 'पेज लोड न होने पर भी timer चालू रखें',
      'Timer continues running even when you leave the match screen': 'मैच स्क्रीन छोड़ने पर भी 타이मर चलता रहेगा',
      'Start Match': 'मैच शुरू करें',
      'Home Side': 'होम साइड',
      'Away Side': 'अवे साइड',
      'Warmup': 'वार्मअप',
      'Skip': 'छोड़ें',
      'Singles': 'सिंगल्स',
      'Doubles': 'डबल्स',
      'Me': 'मैं',
      'Guest': 'अतिथि',
      'Invite': 'आमंत्रित करें',
      'Custom': 'कस्टम',
      'First to 4 sets': 'पहले 4 सेट',
      'First to 3 sets': 'पहले 3 सेट',
      'Friends': 'मित्र',
      'Login': 'लॉगिन',
      'Sign Up': 'साइन अप',
      'Email': 'ईमेल',
      'Password': 'पासवर्ड',
      'Remember Me': 'मुझे याद रखें',
      'Forgot Password?': 'पासवर्ड भूल गए?',
      'Send Link': 'लिंक भेजें',
      'OR': 'या',
      'Sign in with Google': 'Google से साइन इन करें',
      'Username': 'उपयोगकर्ता नाम',
      'Gender': 'लिंग',
      'Male': 'पुरुष',
      'Female': 'महिला',
      'Verified': 'सत्यापित',
      'Unverified': 'असत्यापित',
      'Cancel': 'रद्द करें',
      'Confirm': 'पुष्टि करें',
      'Save': 'सहेजें',
      'Delete': 'हटाएं',
      'Remove': 'निकालें',
      'Back': 'पीछे',
      'Next': 'अगला',
      'Search': 'खोजें',
      'Notifications': 'सूचनाएं',
      'Requests': 'अनुरोध',
      'Accept': 'स्वीकार करें',
      'Decline': 'अस्वीकार करें',
      'Badminton': 'बैडमिントン',
      'Tennis': 'टेनिस',
      'Table Tennis': 'टेबल टेनिस',
    },
  };

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

    // 1. Check static built-in translations first for INSTANT 0-latency translation
    final staticMap = _staticTranslations[langCode];
    if (staticMap != null) {
      if (staticMap.containsKey(text)) {
        return staticMap[text]!;
      }
      if (staticMap.containsKey(queryText)) {
        return staticMap[queryText]!;
      }
    }

    // Automatically track encountered UI strings
    if (!service._encounteredStrings.contains(text)) {
      service._encounteredStrings.add(text);
      service._saveEncounteredStrings();
    }

    // 2. Check auto-translation cache (instant O(1) lookup for original and queryText)
    final autoMap = service._autoCache[langCode];
    if (autoMap != null) {
      if (autoMap.containsKey(text)) {
        return autoMap[text]!;
      }
      if (autoMap.containsKey(queryText)) {
        return autoMap[queryText]!;
      }
    }

    // 3. Trigger silent background auto-translation fetch (no screen flashing)
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
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? translated = data['responseData']?['translatedText'];

        if (translated != null && translated.isNotEmpty && translated.toLowerCase() != text.toLowerCase()) {
          _autoCache.putIfAbsent(targetLang, () => {})[text] = translated;
          await _saveAutoCache();
          if (targetLang == currentLocale.value.languageCode) {
            appLanguageVersion.value++;
          }
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
