import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClubRequestsPage extends StatelessWidget {
  const ClubRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

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
            final bool inAClub = ownedClubId != null || joinedClubId != null;
            final bool isOwner = ownedClubId != null;

            return Scaffold(
              appBar: AppBar(
                title: Text(isOwner ? 'Outgoing Invitations' : 'Club Invitations'),
              ),
              body: _buildList(authService, inAClub, isOwner, ownedClubId),
            );
          },
        );
      }
    );
  }

  Widget _buildList(AuthService authService, bool inAClub, bool isOwner, String? ownedClubId) {
    // 1. If User is a Club Owner: Show invitations they sent
    if (isOwner) {
      return StreamBuilder<QuerySnapshot>(
        stream: authService.getSentClubRequests(ownedClubId!),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(child: Text('No outgoing invitations.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final toUsername = data['toUsername'] ?? 'Unknown User';
              final status = data['status'] ?? 'pending';

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_search)),
                title: Text(toUsername),
                subtitle: Text('Status: $status'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.grey),
                  onPressed: () => authService.deleteClubRequest(req.id),
                  tooltip: 'Discard record',
                ),
              );
            },
          );
        },
      );
    }

    // 2. If User is NOT in a club: Show invitations they received
    if (!inAClub) {
      return StreamBuilder<QuerySnapshot>(
        stream: authService.incomingClubRequests,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(child: Text('No club invitations.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final clubName = data['clubName'] ?? 'Unknown Club';
              final clubId = data['clubId'];
              final status = data['status'] ?? 'pending';

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.groups)),
                title: Text(clubName),
                subtitle: const Text('Invited you to join their club'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        try {
                          await authService.acceptClubRequest(req.id, clubId, clubName);
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => authService.declineClubRequest(req.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    // 3. If User is already a Member: Show nothing (they can't join another)
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Text(
          'You are already a member of a club. You must leave it to see new invitations.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
