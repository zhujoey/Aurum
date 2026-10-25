import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurum/firebase_options.dart';
import 'package:aurum/login.dart';
import 'package:aurum/home.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/theme_service.dart';
import 'package:aurum/language_service.dart';

import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Run Firebase initialization and SharedPreferences loading in parallel for blazing fast boot time
  final results = await Future.wait([
    if (Firebase.apps.isEmpty)
      Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      )
    else
      Future.value(null),
    SharedPreferences.getInstance(),
  ]);

  final prefs = results[1] as SharedPreferences;

  // Enable Firestore offline persistence for Web (IndexedDB) and Mobile (SQLite)
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint("Firestore settings notice: $e");
  }

  // Fast parallel/sync memory initialization from pre-fetched SharedPreferences
  await Future.wait([
    AuthService().init(prefs),
    ThemeService().init(prefs),
    LanguageService().init(prefs),
  ]);

  FlutterNativeSplash.remove();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        LanguageService().currentLocale,
        LanguageService().appLanguageVersion,
        ThemeService().themeMode,
        ThemeService().seedColor,
      ]),
      builder: (context, child) {
        final locale = LanguageService().currentLocale.value;
        final mode = ThemeService().themeMode.value;
        final color = ThemeService().seedColor.value;

        return MaterialApp(
          title: 'Aurum'.tr,
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: color,
              brightness: Brightness.dark,
              surface: Colors.black,
            ),
            scaffoldBackgroundColor: Colors.black,
            cardColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.black,
              surfaceTintColor: Colors.black,
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF121212)),
            useMaterial3: true,
          ),
          themeMode: mode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  StreamSubscription? _requestSubscription;
  StreamSubscription? _sessionSubscription;
  final Set<String> _activeDialogRequestIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startListening();
    _startSessionMonitor();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _requestSubscription?.cancel();
    _sessionSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh everything when the app comes back to foreground
      // This is crucial for iOS and Android to re-establish Firestore streams
      _authService.syncUserData(_authService.currentUser);
      _startListening();
      _startSessionMonitor();
    }
  }

  void _startSessionMonitor() {
    _sessionSubscription?.cancel();
    _sessionSubscription = _authService.sessionValidStream.listen((isValid) {
      if (!isValid) {
        _handleInvalidSession();
      }
    });
  }

  void _handleInvalidSession() async {
    // Prevent multiple calls
    _sessionSubscription?.cancel();
    
    // Check if we still have a user and it's actually invalid
    if (_authService.currentUser == null) return;
    
    await _authService.signOut();
    
    // Ensure we have a context to show the dialog
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Session Ended'.tr),
        content: Text('Your account has been logged in on another device. You have been signed out from this instance.'.tr),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              _startSessionMonitor(); // Re-start monitoring for the next login
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  void _startListening() {
    _requestSubscription?.cancel();
    _requestSubscription = _authService.incomingMatchRequests.listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showMatchPrompt(change.doc);
        }
      }
    });
  }

  void _showMatchPrompt(DocumentSnapshot doc) async {
    if (_activeDialogRequestIds.contains(doc.id)) return;

    // Small delay to ensure navigator context and user profile are ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint("Warning: Could not show match prompt, navigator context is null");
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final String fromUser = data['fromUsername'] ?? 'Unknown';
    final String sport = data['sport'] ?? 'Match';
    final int setsToWin = data['setsToWin'] ?? 3;
    final bool isDoubles = data['isDoubles'] ?? false;
    final String p1Name = data['p1Name'] ?? '';
    final String p2Name = data['p2Name'] ?? '';
    final String p3Name = data['p3Name'] ?? '';
    final String p4Name = data['p4Name'] ?? '';

    // Try to get displayName, reload if necessary
    User? user = _authService.currentUser;
    if (user != null && (user.displayName == null || user.displayName!.isEmpty)) {
      await user.reload();
      user = _authService.currentUser;
    }
    
    String currentUsername = user?.displayName ?? '';
    String teamInfo = "";
    
    if (isDoubles) {
      if (currentUsername.toLowerCase() == p2Name.toLowerCase()) {
        teamInfo = "\n${"You will be on Team 1 with".tr} $p1Name.";
      } else if (currentUsername.toLowerCase() == p3Name.toLowerCase()) {
        teamInfo = "\n${"You will be on Team 2 with".tr} $p4Name.";
      } else if (currentUsername.toLowerCase() == p4Name.toLowerCase()) {
        teamInfo = "\n${"You will be on Team 2 with".tr} $p3Name.";
      }
    } else {
      teamInfo = "\n${"You will be playing against".tr} $p1Name.";
    }

    _activeDialogRequestIds.add(doc.id);
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        // Listen to the request status to auto-close if host cancels
        return StreamBuilder<DocumentSnapshot>(
          stream: _authService.listenToRequest(doc.id),
          builder: (context, snapshot) {
            // If the document is deleted (status becomes 'cancelled' or doc vanishes)
            if (snapshot.hasData && !snapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (Navigator.canPop(dialogContext)) {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                }
                setState(() => _activeDialogRequestIds.remove(doc.id));
              });
            }

            return AlertDialog(
              title: Text('${sport.tr} ${"Request".tr}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$fromUser ${"invited you to a".tr} ${(isDoubles ? "Doubles" : "Singles").tr} ${"match".tr} (${("First to $setsToWin sets").tr}).'),
                  const SizedBox(height: 12),
                  if (teamInfo.isNotEmpty)
                    Text(teamInfo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    try {
                      await _authService.respondToRequest(doc.id, 'rejected');
                    } finally {
                      if (mounted) {
                        setState(() => _activeDialogRequestIds.remove(doc.id));
                      }
                      if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }
                    }
                  },
                  child: Text('Decline'.tr, style: const TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await _authService.respondToRequest(doc.id, 'accepted');
                    } finally {
                      if (mounted) {
                        setState(() => _activeDialogRequestIds.remove(doc.id));
                      }
                      if (dialogContext.mounted && Navigator.canPop(dialogContext)) {
                        Navigator.of(dialogContext, rootNavigator: true).pop();
                      }
                      final scaffoldCtx = navigatorKey.currentContext;
                      if (scaffoldCtx != null && scaffoldCtx.mounted) {
                        ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                          SnackBar(content: Text('Accepted! Waiting for host to start.'.tr)),
                        );
                      }
                    }
                  },
                  child: Text('Accept'.tr),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userStream,
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(backgroundColor: Colors.black);
        }
        if (snapshot.hasData && snapshot.data != null) {
          return const Home();
        } else {
          return const Login();
        }
      },
    );
  }
}
