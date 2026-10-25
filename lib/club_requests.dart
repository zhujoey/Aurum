import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/widgets/user_avatar.dart';
import 'package:aurum/widgets/user_profile_sheet.dart';
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
              title: Text('Notifications & Requests'.tr),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Clubs'.tr),
                  Tab(text: 'Tournaments'.tr),
                  Tab(text: 'Doubles'.tr),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _KeepAliveStreamTabView(
                  stream: authService.incomingClubRequests,
                  emptyMessage: 'No incoming club invitations.'.tr,
                  itemBuilder: (context, req) {
                    final data = req.data() as Map<String, dynamic>;
                    final clubName = data['clubName'] ?? 'Unknown Club';
                    final clubId = data['clubId'];

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.groups)),
                      title: Text(clubName),
                      subtitle: Text('Invited you to join their club'.tr),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              try {
                                await authService.acceptClubRequest(req.id, clubId, clubName);
                                if (context.mounted) {
                                  _showAppSnackBar(context, SnackBar(content: Text('${'Joined'.tr} $clubName!')));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showAppSnackBar(context, SnackBar(content: Text(e.toString().tr), backgroundColor: Colors.redAccent));
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
                ),
                _KeepAliveStreamTabView(
                  stream: authService.incomingTournamentRequests,
                  emptyMessage: 'No incoming tournament invitations.'.tr,
                  itemBuilder: (context, req) {
                    final data = req.data() as Map<String, dynamic>;
                    final tournamentName = data['tournamentName'] ?? 'Tournament';
                    final clubId = data['clubId'];
                    final tournamentId = data['tournamentId'];

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.emoji_events, color: Colors.amber)),
                      title: Text(tournamentName),
                      subtitle: Text('Invited you to join tournament'.tr),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              try {
                                await authService.acceptTournamentRequest(req.id, clubId, tournamentId);
                                if (context.mounted) {
                                  _showAppSnackBar(context, SnackBar(content: Text('Accepted tournament invitation!'.tr)));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showAppSnackBar(context, SnackBar(content: Text(e.toString().tr), backgroundColor: Colors.redAccent));
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
                ),
                _KeepAliveStreamTabView(
                  stream: FirebaseFirestore.instance
                      .collectionGroup('doubles_requests')
                      .where('toUid', isEqualTo: user.uid)
                      .where('status', isEqualTo: 'pending')
                      .snapshots(),
                  emptyMessage: 'No incoming doubles partner requests.'.tr,
                  itemBuilder: (context, req) {
                    final data = req.data() as Map<String, dynamic>;
                    final fromName = data['fromUsername'] ?? 'Player';
                    final eventType = data['eventType'] ?? 'Doubles';

                    String eventDisplay = 'Doubles Event'.tr;
                    if (eventType == 'mixed') eventDisplay = 'Mixed Doubles (1 Male + 1 Female)'.tr;
                    if (eventType == 'open_doubles') eventDisplay = 'Open Doubles (2 Players)'.tr;
                    if (eventType == 'mens_doubles') eventDisplay = "Men's Doubles (2 Players)".tr;
                    if (eventType == 'womens_doubles') eventDisplay = "Women's Doubles (2 Players)".tr;
                    if (eventType == 'open_team') eventDisplay = 'Open Team (5 Players)'.tr;
                    if (eventType == 'mens_team') eventDisplay = "Men's Team (5 Male Players)".tr;
                    if (eventType == 'womens_team') eventDisplay = "Women's Team (5 Female Players)".tr;
                    if (eventType == 'mixed_team') eventDisplay = 'Mixed Team (4 Males + 4 Females)'.tr;

                    final String clubId = req.reference.parent.parent!.parent.parent!.id;
                    final String tournamentId = req.reference.parent.parent!.id;

                    final String fromUid = data['fromUid'] as String? ?? '';

                    return ListTile(
                      leading: UserAvatar(
                        photoUrl: data['fromPhotoUrl'] ?? data['photoUrl'],
                        uid: fromUid,
                        username: fromName,
                      ),
                      title: Text('$fromName ${"requested to partner with you".tr}'),
                      subtitle: Text('${'Event'.tr}: $eventDisplay'),
                      onTap: () {
                        if (fromUid.isNotEmpty) {
                          showUserProfileSheet(
                            context,
                            uid: fromUid,
                            username: fromName,
                            photoUrl: data['fromPhotoUrl'] ?? data['photoUrl'],
                          );
                        }
                      },
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
                                  _showAppSnackBar(context, SnackBar(content: Text('Accepted doubles partner request!'.tr)));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  _showAppSnackBar(context, SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent));
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KeepAliveStreamTabView extends StatefulWidget {
  final Stream<QuerySnapshot> stream;
  final String emptyMessage;
  final Widget Function(BuildContext, QueryDocumentSnapshot) itemBuilder;

  const _KeepAliveStreamTabView({
    required this.stream,
    required this.emptyMessage,
    required this.itemBuilder,
  });

  @override
  State<_KeepAliveStreamTabView> createState() => _KeepAliveStreamTabViewState();
}

class _KeepAliveStreamTabViewState extends State<_KeepAliveStreamTabView> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: widget.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text(widget.emptyMessage));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) => widget.itemBuilder(context, docs[index]),
        );
      },
    );
  }
}
