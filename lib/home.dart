import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:aurum/settings.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/new_match.dart';
import 'package:aurum/clubs.dart';
import 'package:aurum/tournaments.dart';
import 'package:aurum/rankings.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/widgets/active_match_banner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  late final int _quoteIndex;
  static const int _totalQuotes = 18;

  String _getQuote(int index, String displayName) {
    switch (index) {
      case 0:
        return "${"Ready to make today count".tr}, $displayName?";
      case 1:
        return "${"Small daily wins add up".tr}, $displayName.";
      case 2:
        return "Focus on progress, not perfection.".tr;
      case 3:
        return "Your next personal best starts right now.".tr;
      case 4:
        return "${"Keep pushing your limits today".tr}, $displayName.";
      case 5:
        return "Every match makes you sharper.".tr;
      case 6:
        return "${"Time to put in the work".tr}, $displayName.";
      case 7:
        return "Stay sharp, stay hungry.".tr;
      case 8:
        return "Consistency is your superpower.".tr;
      case 9:
        return "${"One step closer to your goals".tr}, $displayName.";
      case 10:
        return "${"Let's make today productive".tr}, $displayName.";
      case 11:
        return "Trust the process and play your game.".tr;
      case 12:
        return "${"Discipline beats motivation".tr}, $displayName.";
      case 13:
        return "Own your momentum today.".tr;
      case 14:
        return "${"Greatness is built one step at a time".tr}, $displayName.";
      case 15:
        return "${"Keep moving forward".tr}, $displayName.";
      case 16:
        return "Chasing excellence, one day at a time.".tr;
      case 17:
        return "${"Your potential is endless".tr}, $displayName.";
      default:
        return "Focus on progress, not perfection.".tr;
    }
  }

  @override
  void initState() {
    super.initState();
    _initialSync();
    _quoteIndex = Random().nextInt(_totalQuotes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prewarmQuoteTranslations();
    });
  }

  void _prewarmQuoteTranslations() {
    final lang = LanguageService().currentLocale.value.languageCode;
    if (lang == 'en') return;
    const phrases = [
      "Ready to make today count",
      "Small daily wins add up",
      "Focus on progress, not perfection.",
      "Your next personal best starts right now.",
      "Keep pushing your limits today",
      "Every match makes you sharper.",
      "Time to put in the work",
      "Stay sharp, stay hungry.",
      "Consistency is your superpower.",
      "One step closer to your goals",
      "Let's make today productive",
      "Trust the process and play your game.",
      "Discipline beats motivation",
      "Own your momentum today.",
      "Greatness is built one step at a time",
      "Keep moving forward",
      "Chasing excellence, one day at a time.",
      "Your potential is endless",
    ];
    for (final p in phrases) {
      p.tr;
    }
  }

  Future<void> _initialSync() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (user.displayName == null || user.displayName!.isEmpty) {
        user.reload().then((_) {
          _authService.syncUserData(_authService.currentUser);
        }).catchError((e) {
          debugPrint("Error reloading user on startup: $e");
        });
      } else {
        _authService.syncUserData(user);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Widget _buildActiveMatchBanner(DocumentSnapshot matchDoc) {
    return ActiveMatchBanner(matchDoc: matchDoc);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: LanguageService().appLanguageVersion,
      builder: (context, version, child) {
        return StreamBuilder<User?>(
          stream: _authService.userStream,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final String displayName = user?.displayName?.isNotEmpty == true
                ? user!.displayName!
                : (user?.email?.split('@').first ?? 'Player');

            final quote = _getQuote(_quoteIndex, displayName);

            return Scaffold(
              appBar: AppBar(
            title: const Icon(Icons.home),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<QuerySnapshot>(
                  stream: _authService.myActiveMatches,
                  builder: (context, matchSnapshot) {
                    if (matchSnapshot.hasData && matchSnapshot.data!.docs.isNotEmpty) {
                      return _buildActiveMatchBanner(matchSnapshot.data!.docs.first);
                    }
                    return const SizedBox.shrink();
                  }
                ),
                Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildActionButton(
                      context,
                      'Rankings'.tr,
                      Icons.leaderboard,
                      Colors.orange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RankingsPage()),
                        );
                      },
                    ),
                    _buildActionButton(
                      context,
                      'Clubs'.tr,
                      Icons.groups,
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ClubsPage()),
                        );
                      },
                    ),
                    _buildActionButton(
                      context,
                      'Quick Match'.tr,
                      Icons.sports_tennis,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const NewMatch()),
                        );
                      },
                    ),
                    _buildActionButton(
                      context,
                      'Tournaments'.tr,
                      Icons.military_tech,
                      Colors.purple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TournamentsPage()),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
