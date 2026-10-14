import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportspro/profile.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/new_match.dart';
import 'package:sportspro/clubs.dart';
import 'package:sportspro/tournaments.dart';
import 'package:sportspro/widgets/active_match_banner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initialSync();
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
        final String displayName = user?.displayName ?? 'Player';

        return Scaffold(
          appBar: AppBar(
            title: const Icon(Icons.home),
            actions: [
              IconButton(
                icon: const Icon(Icons.account_circle),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const Profile()),
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
                  'Welcome, $displayName!',
                  style: const TextStyle(
                    fontSize: 28,
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
                      'Rankings',
                      Icons.leaderboard,
                      Colors.orange,
                      () {},
                    ),
                    _buildActionButton(
                      context,
                      'Clubs',
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
                      'Quick Match',
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
                      'Tournament',
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
      }
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
