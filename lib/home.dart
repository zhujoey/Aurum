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

  final List<String> _quoteTemplates = [
    "Ready to make today count, {name}?",
    "Small daily wins add up, {name}.",
    "Focus on progress, not perfection.",
    "Your next personal best starts right now.",
    "Keep pushing your limits today, {name}.",
    "Every match makes you sharper.",
    "Time to put in the work, {name}.",
    "Stay sharp, stay hungry.",
    "Consistency is your superpower.",
    "One step closer to your goals, {name}.",
    "Let's make today productive, {name}.",
    "Trust the process and play your game.",
    "Discipline beats motivation, {name}.",
    "Own your momentum today.",
    "Greatness is built one step at a time, {name}.",
    "Keep moving forward, {name}.",
    "Chasing excellence, one day at a time.",
    "Your potential is endless, {name}.",
  ];

  @override
  void initState() {
    super.initState();
    _initialSync();
    _quoteIndex = Random().nextInt(_quoteTemplates.length);
  }

  Future<void> _initialSync() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (user.displayName == null || user.displayName!.isEmpty) {
        await user.reload();
      }
      await _authService.syncUserData(_authService.currentUser);
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
    return StreamBuilder<User?>(
      stream: _authService.userStream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final String displayName = user?.displayName?.isNotEmpty == true
            ? user!.displayName!
            : (user?.email?.split('@').first ?? 'Player');

        final quoteTemplate = _quoteTemplates[_quoteIndex];
        final quote = quoteTemplate.tr.replaceAll('{name}', displayName);

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
