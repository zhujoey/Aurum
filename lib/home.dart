import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportspro/profile.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/new_match.dart';
import 'package:sportspro/clubs.dart';
import 'package:sportspro/table_tennis/tt_scoreboard.dart';
import 'package:sportspro/table_tennis/tt_setup.dart';
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
            final matchData = data['matchData'] ?? {};
            if (!isHost) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TableTennisMatch(
                    p1Name: matchData['p1Name'] ?? 'P1',
                    p2Name: matchData['p2Name'] ?? '',
                    p3Name: matchData['p3Name'] ?? 'P2',
                    p4Name: matchData['p4Name'] ?? '',
                    isDoubles: matchData['isDoubles'] ?? false,
                    setsToWin: matchData['setsToWin'] ?? 4,
                    matchId: matchDoc.id,
                    isHost: false,
                  ),
                ),
              );
            } else {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TableTennisSetup()));
            }
          }
        },
        trailing: isHost 
          ? const Icon(Icons.chevron_right)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () async {
                    bool? confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Forfeit Match?'),
                        content: const Text('You will be marked as forfeited and this match will end for everyone. This cannot be undone.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Forfeit', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _authService.updateMatchStatus(matchDoc.id, 'forfeited');
                    }
                  },
                  child: const Text('Forfeit', style: TextStyle(color: Colors.red, fontSize: 12)),
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    if (sport == 'Table Tennis') {
                      final matchData = data['matchData'] ?? {};
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TableTennisMatch(
                            p1Name: matchData['p1Name'] ?? 'P1',
                            p2Name: matchData['p2Name'] ?? '',
                            p3Name: matchData['p3Name'] ?? 'P2',
                            p4Name: matchData['p4Name'] ?? '',
                            isDoubles: matchData['isDoubles'] ?? false,
                            setsToWin: matchData['setsToWin'] ?? 4,
                            matchId: matchDoc.id,
                            isHost: false,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const Text('View Match', style: TextStyle(fontSize: 12)),
                ),
              ],
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
