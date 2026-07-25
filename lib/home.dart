import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sportsaccesories/profile.dart';
import 'package:sportsaccesories/auth_service.dart';
import 'package:sportsaccesories/new_match.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  StreamSubscription? _requestSubscription;

  @override
  void initState() {
    super.initState();
    _startListeningForRequests();
  }

  @override
  void dispose() {
    _requestSubscription?.cancel();
    super.dispose();
  }

  void _startListeningForRequests() {
    _requestSubscription = _authService.incomingMatchRequests.listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          _showMatchPrompt(change.doc);
        }
      }
    });
  }

  void _showMatchPrompt(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String fromUser = data['fromUsername'];
    final String sport = data['sport'];
    final int setsToWin = data['setsToWin'] ?? 3;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Match Request'),
        content: Text('$fromUser wants to play $sport (First to $setsToWin) with you!'),
        actions: [
          TextButton(
            onPressed: () {
              _authService.respondToRequest(doc.id, 'rejected');
              Navigator.pop(context);
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              _authService.respondToRequest(doc.id, 'accepted');
              Navigator.pop(context);
              
              // Navigate to the match screen
              if (sport == 'Table Tennis') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TableTennisMatch(
                      p1Name: fromUser,
                      p2Name: _authService.currentUser?.displayName ?? 'Me',
                      setsToWin: setsToWin,
                    ),
                  ),
                );
              }
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
                Text(
                  'Welcome back, $displayName!',
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
