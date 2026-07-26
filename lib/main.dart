import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sportsaccesories/firebase_options.dart';
import 'package:sportsaccesories/login.dart';
import 'package:sportsaccesories/home.dart';
import 'package:sportsaccesories/auth_service.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:sportsaccesories/table_tennis/tt_scoreboard.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sports Accessories',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  StreamSubscription? _requestSubscription;
  final Set<String> _activeDialogRequestIds = {};

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    _requestSubscription = _authService.incomingMatchRequests.listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showMatchPrompt(change.doc);
        }
      }
    });
  }

  void _showMatchPrompt(DocumentSnapshot doc) {
    if (_activeDialogRequestIds.contains(doc.id)) return;

    final data = doc.data() as Map<String, dynamic>;
    final String fromUser = data['fromUsername'] ?? 'Unknown';
    final String sport = data['sport'] ?? 'Match';
    final int setsToWin = data['setsToWin'] ?? 3;
    final bool isDoubles = data['isDoubles'] ?? false;
    final String p1Name = data['p1Name'] ?? '';
    final String p2Name = data['p2Name'] ?? '';
    final String p3Name = data['p3Name'] ?? '';
    final String p4Name = data['p4Name'] ?? '';

    String currentUsername = _authService.currentUser?.displayName ?? '';
    String teamInfo = "";
    if (isDoubles) {
      if (currentUsername == p2Name) {
        teamInfo = "\nYou will be on Team 1 with $p1Name.";
      } else if (currentUsername == p3Name) {
        teamInfo = "\nYou will be on Team 2 with $p4Name.";
      } else if (currentUsername == p4Name) {
        teamInfo = "\nYou will be on Team 2 with $p3Name.";
      }
    } else {
      teamInfo = "\nYou will be playing against $p1Name.";
    }

    _activeDialogRequestIds.add(doc.id);

    showDialog(
      context: navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$sport Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$fromUser invited you to a ${isDoubles ? "Doubles" : "Singles"} match (First to $setsToWin sets).'),
            const SizedBox(height: 12),
            Text(teamInfo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _authService.respondToRequest(doc.id, 'rejected');
              if (mounted) {
                setState(() => _activeDialogRequestIds.remove(doc.id));
              }
              Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.respondToRequest(doc.id, 'accepted');
              if (mounted) {
                setState(() => _activeDialogRequestIds.remove(doc.id));
              }
              Navigator.of(context, rootNavigator: true).pop();
              ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                const SnackBar(content: Text('Accepted! Waiting for host to start.')),
              );
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.userStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
