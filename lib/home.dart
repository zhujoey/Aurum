import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportsaccesories/profile.dart';
import 'package:sportsaccesories/auth_service.dart';
import 'package:sportsaccesories/new_match.dart';
import 'package:sportsaccesories/table_tennis/tt_scoreboard.dart';
import 'package:sportsaccesories/table_tennis/tt_setup.dart';
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
    final data = matchDoc.data() as Map<String, dynamic>;
    final String sport = data['sport'] ?? '';
    bool isHost = data['hostUid'] == _authService.currentUser?.uid;

    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 24),
      child: ListTile(
        leading: const Icon(Icons.sports_tennis, color: Colors.amber),
        title: const Text('Active Match in Progress', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(isHost ? 'You are hosting a match.' : 'You are participating in a match.'),
        onTap: () {
          if (sport == 'Table Tennis') {
             Navigator.push(context, MaterialPageRoute(builder: (context) => const TableTennisSetup()));
          }
        },
        trailing: isHost 
          ? const Icon(Icons.chevron_right)
          : ElevatedButton(
              onPressed: () => _authService.updateMatchStatus(matchDoc.id, 'forfeited'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Forfeit'),
            ),
      ),
    );
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
            title: const Text('Sports Tracker'),
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
                const SizedBox(height: 8),
                const Text(
                  'What would you like to do today?',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                      'Records',
                      Icons.emoji_events,
                      Colors.blue,
                      () {},
                    ),
                    _buildActionButton(
                      context,
                      'New Match',
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
                      'New Tournament',
                      Icons.military_tech,
                      Colors.purple,
                      () {},
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
