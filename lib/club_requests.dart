import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

void _showAppSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: snackBar.backgroundColor,
      duration: snackBar.duration,
      behavior: SnackBarBehavior.floating,
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Container(
          color: Colors.transparent,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: snackBar.content,
        ),
      ),
    ),
  );
}

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

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Notifications & Requests'),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'Clubs'),
                  Tab(text: 'Tournaments'),
                  Tab(text: 'Doubles'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _buildIncomingClubRequests(authService),
                _buildIncomingTournamentRequests(authService),
                _buildIncomingDoublesRequests(authService, user.uid),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIncomingClubRequests(AuthService authService) {
    return StreamBuilder<QuerySnapshot>(
      stream: authService.incomingClubRequests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No incoming club invitations.'));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final data = req.data() as Map<String, dynamic>;
            final clubName = data['clubName'] ?? 'Unknown Club';
            final clubId = data['clubId'];

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
                        if (context.mounted) {
                          _showAppSnackBar(context, 
                            SnackBar(content: Text('Joined $clubName!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showAppSnackBar(context, 
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

  Widget _buildIncomingTournamentRequests(AuthService authService) {
    return StreamBuilder<QuerySnapshot>(
      stream: authService.incomingTournamentRequests,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No incoming tournament invitations.'));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final data = req.data() as Map<String, dynamic>;
            final tournamentName = data['tournamentName'] ?? 'Tournament';
            final clubId = data['clubId'];
            final tournamentId = data['tournamentId'];

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.emoji_events, color: Colors.amber)),
              title: Text(tournamentName),
              subtitle: const Text('Invited you to join tournament'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      try {
                        await authService.acceptTournamentRequest(req.id, clubId, tournamentId);
                        if (context.mounted) {
                          _showAppSnackBar(context, 
                            const SnackBar(content: Text('Accepted tournament invitation!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showAppSnackBar(context, 
                            SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => authService.declineTournamentRequest(req.id),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildIncomingDoublesRequests(AuthService authService, String currentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('doubles_requests')
          .where('toUid', isEqualTo: currentUid)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No incoming doubles partner requests.'));
        }

        final requests = snapshot.data!.docs;

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final req = requests[index];
            final data = req.data() as Map<String, dynamic>;
            final fromName = data['fromUsername'] ?? 'Player';
            final eventType = data['eventType'] ?? 'Doubles';

            String eventDisplay = 'Doubles';
            if (eventType == 'mixed') eventDisplay = 'Mixed Doubles';
            if (eventType == 'open_doubles') eventDisplay = 'Open Doubles';
            if (eventType == 'mens_doubles') eventDisplay = "Men's Doubles";
            if (eventType == 'womens_doubles') eventDisplay = "Women's Doubles";

            final String clubId = req.reference.parent.parent!.parent.parent!.id;
            final String tournamentId = req.reference.parent.parent!.id;

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.handshake, color: Colors.blue)),
              title: Text('$fromName requested to partner with you'),
              subtitle: Text('Event: $eventDisplay'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      try {
                        await authService.acceptDoublesPartner(
                          clubId: clubId,
                          tournamentId: tournamentId,
                          requestId: req.id,
                        );
                        if (context.mounted) {
                          _showAppSnackBar(context, 
                            const SnackBar(content: Text('Accepted doubles partner request!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showAppSnackBar(context, 
                            SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => authService.declineDoublesPartner(
                      clubId: clubId,
                      tournamentId: tournamentId,
                      requestId: req.id,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
