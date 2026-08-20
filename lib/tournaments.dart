import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TournamentsPage extends StatelessWidget {
  const TournamentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<User?>(
        stream: authService.userStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          final user = userSnapshot.data!;

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, profileSnapshot) {
              if (!profileSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

              final profileData = profileSnapshot.data!.data() as Map<String, dynamic>?;
              final String? ownedClubId = profileData?['ownedClubId'];
              final String? joinedClubId = profileData?['joinedClubId'];
              final String? clubId = ownedClubId ?? joinedClubId;

              if (clubId == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text('Tournaments')),
                  body: const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text(
                        'You must be in a club to view or create tournaments.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    ),
                  ),
                );
              }

              return _ClubTournamentsView(clubId: clubId, isOwner: ownedClubId != null);
            },
          );
        }
    );
  }
}

class _ClubTournamentsView extends StatelessWidget {
  final String clubId;
  final bool isOwner;

  const _ClubTournamentsView({required this.clubId, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
      builder: (context, clubSnapshot) {
        if (!clubSnapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final clubData = clubSnapshot.data!.data() as Map<String, dynamic>?;
        final String clubSport = clubData?['sport'] ?? 'Multiple';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tournaments'),
            actions: [
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _showCreateTournamentDialog(context, clubId, clubSport),
                ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: authService.getClubTournaments(clubId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text('No active tournaments.', style: TextStyle(color: Colors.grey)),
                );
              }

              final tournaments = snapshot.data!.docs;

              return ListView.builder(
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final t = tournaments[index];
                  final data = t.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Tournament';
                  final sport = data['sport'] ?? 'Multiple';
                  final status = data['status'] ?? 'upcoming';
                  final needsPermission = data['needsPermission'] ?? false;

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.emoji_events)),
                    title: Text(name),
                    subtitle: Text('$sport • $status'),
                    trailing: isOwner
                        ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteTournamentDialog(context, clubId, t.id, name),
                    )
                        : (needsPermission ? const Icon(Icons.lock_outline, size: 16) : null),
                    onTap: () {
                      // Navigate to tournament details
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _showCreateTournamentDialog(BuildContext context, String clubId, String clubSport) {
    final nameController = TextEditingController();
    bool needsPermission = false;
    final authService = AuthService();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Tournament'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tournament Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.sports, color: Colors.blue),
                  title: const Text('Sport'),
                  subtitle: Text(clubSport),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Require Permission to Join'),
                  subtitle: const Text('Members must be approved by you'),
                  value: needsPermission,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setDialogState(() => needsPermission = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await authService.createTournament(
                    clubId: clubId,
                    name: name,
                    sport: clubSport,
                    needsPermission: needsPermission,
                  );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteTournamentDialog(BuildContext context, String clubId, String tournamentId, String name) {
    final authService = AuthService();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tournament?'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await authService.deleteTournament(clubId, tournamentId);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}