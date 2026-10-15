import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/club_requests.dart';
import 'package:sportspro/table_tennis/tt_scoreboard.dart';
import 'package:sportspro/badminton/badminton_scoreboard.dart';
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

              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).collection('members').doc(user.uid).snapshots(),
                builder: (context, memberSnapshot) {
                  final memberData = memberSnapshot.hasData && memberSnapshot.data!.exists
                      ? memberSnapshot.data!.data() as Map<String, dynamic>?
                      : null;
                  final String role = memberData?['role'] ?? 'member';
                  final bool isOwnerOrManager = role == 'owner' || role == 'manager';

                  return _ClubTournamentsView(clubId: clubId, isOwnerOrManager: isOwnerOrManager);
                },
              );
            },
          );
        }
    );
  }
}

class _ClubTournamentsView extends StatelessWidget {
  final String clubId;
  final bool isOwnerOrManager;

  const _ClubTournamentsView({required this.clubId, required this.isOwnerOrManager});

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
              StreamBuilder<QuerySnapshot>(
                stream: authService.incomingTournamentRequests,
                builder: (context, reqSnapshot) {
                  final hasPending = reqSnapshot.hasData && reqSnapshot.data!.docs.isNotEmpty;
                  final count = hasPending ? reqSnapshot.data!.docs.length : 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Tournament Invitations',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const ClubRequestsPage()),
                          );
                        },
                      ),
                      if (hasPending)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$count',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              if (isOwnerOrManager)
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
                  final description = data['description'] as String? ?? '';
                  final sport = data['sport'] ?? 'Multiple';
                  final int rankingPoints = data['rankingPoints'] ?? 1000;
                  final isOpen = data['isOpen'] ?? !(data['needsPermission'] ?? false);

                  final bool isStarted = data['isStarted'] ?? false;
                  final bool isCompleted = data['isCompleted'] ?? false;

                  String statusText = 'Upcoming';
                  Color statusColor = Colors.orange;
                  if (isCompleted) {
                    statusText = 'Completed';
                    statusColor = Colors.grey;
                  } else if (isStarted) {
                    statusText = 'In Progress';
                    statusColor = Colors.blue;
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: statusColor.withValues(alpha: 0.15),
                      child: Icon(Icons.emoji_events, color: statusColor),
                    ),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) ...[
                          Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                        ],
                        Text('$sport • $rankingPoints pts • $statusText'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isOpen) const Icon(Icons.lock_outline, size: 16),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentDetailsPage(
                            clubId: clubId,
                            tournamentId: t.id,
                            isOwnerOrManager: isOwnerOrManager,
                          ),
                        ),
                      );
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
    final descriptionController = TextEditingController();
    final pointsController = TextEditingController(text: '1000');
    String selectedStyle = 'Single Elimination';
    String selectedSinglesType = 'everyone';
    String selectedDoublesType = 'none';
    bool isOpen = false;
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
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description / Subheading',
                    hintText: 'Brief summary or details',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Ranking Points Value (ITTF System)',
                    hintText: 'e.g. 2000, 1000, 500, 250',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Tournament Style / Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Single Elimination', child: Text('Single Elimination (Knockout)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Double Elimination', child: Text('Double Elimination', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Round Robin', child: Text('Round Robin', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'Swiss System', child: Text('Swiss System', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'World Cup', child: Text('World Cup (Group Stage + KO)', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setDialogState(() => selectedStyle = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedSinglesType,
                  decoration: const InputDecoration(
                    labelText: 'Singles Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'everyone', child: Text('Everyone in Same Bracket (Open)', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'separate_gender', child: Text("Men's & Women's Singles (Separate)", overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setDialogState(() => selectedSinglesType = val!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: selectedDoublesType,
                  decoration: const InputDecoration(
                    labelText: 'Doubles Format',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'none', child: Text('No Doubles', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'open', child: Text('Open Doubles', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'gendered', child: Text("Men's and Women's Doubles only", overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'mixed_only', child: Text('Mixed Doubles only', overflow: TextOverflow.ellipsis)),
                    DropdownMenuItem(value: 'all', child: Text("Men's, Women's, and Mixed Doubles", overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) => setDialogState(() => selectedDoublesType = val!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.sports, color: Colors.blue),
                  title: const Text('Sport'),
                  subtitle: Text(clubSport),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Open Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('People can join without permission', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: isOpen,
                      onChanged: (val) => setDialogState(() => isOpen = val),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final description = descriptionController.text.trim();
                final points = int.tryParse(pointsController.text.trim()) ?? 1000;
                if (name.isEmpty) return;
                try {
                  await authService.createTournament(
                    clubId: clubId,
                    name: name,
                    description: description,
                    sport: clubSport,
                    isOpen: isOpen,
                    rankingPoints: points,
                    tournamentStyle: selectedStyle,
                    singlesType: selectedSinglesType,
                    doublesType: selectedDoublesType,
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


}

class TournamentDetailsPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final bool isOwnerOrManager;

  const TournamentDetailsPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.isOwnerOrManager,
  });

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final String currentUid = authService.currentUser?.uid ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: authService.getTournamentStream(clubId, tournamentId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text('Tournament Details')),
            body: const Center(
              child: Text('Tournament not found or deleted.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final String name = data['name'] ?? 'Tournament';
        final String description = data['description'] as String? ?? '';
        final String sport = data['sport'] ?? 'Multiple';
        final int rankingPoints = data['rankingPoints'] ?? 1000;
        final String tournamentStyle = data['tournamentStyle'] ?? 'Single Elimination';
        final bool isStarted = data['isStarted'] ?? false;
        final bool isOpen = data['isOpen'] ?? !(data['needsPermission'] ?? false);
        final List participantUids = List.from(data['participantUids'] ?? []);
        final List participants = List.from(data['participants'] ?? []);

        final bool isJoined = participantUids.contains(currentUid);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tournament Details'),
            actions: [
              if (isOwnerOrManager) ...[
                IconButton(
                  icon: const Icon(Icons.settings),
                  tooltip: 'Tournament Settings',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TournamentSettingsPage(
                          clubId: clubId,
                          tournamentId: tournamentId,
                          currentData: data,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tournament Header Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.amber,
                          child: Icon(Icons.emoji_events, size: 36, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.sports, size: 16),
                              label: Text(sport),
                            ),
                            Chip(
                              avatar: const Icon(Icons.account_tree, size: 16),
                              label: Text(tournamentStyle),
                            ),
                            Chip(
                              avatar: const Icon(Icons.stars, size: 16, color: Colors.amber),
                              label: Text(
                                '$rankingPoints Points',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              avatar: Icon(
                                isOpen ? Icons.lock_open : Icons.lock_outline,
                                size: 16,
                                color: isOpen ? Colors.green : Colors.orange,
                              ),
                              label: Text(
                                isOpen ? 'Open Tournament' : 'Closed / Invite Only',
                                style: TextStyle(
                                  color: isOpen ? Colors.green : Colors.orange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Join / Leave / Invite Actions Section
                if (isStarted) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.account_tree),
                    label: const Text('View Tournament Bracket', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentRunnerPage(
                            clubId: clubId,
                            tournamentId: tournamentId,
                            tournamentData: data,
                          ),
                        ),
                      );
                    },
                  ),
                ] else if (isOwnerOrManager) ...[
                  ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Tournament', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showStartTournamentDialog(context, authService, data, participantUids.length),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Members', style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showInviteMembersModal(context, authService, participantUids, name),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.smart_toy, color: Colors.purple),
                    label: const Text('Add Test Players (Testing Tool)', style: TextStyle(color: Colors.purple, fontSize: 15)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.purple),
                    ),
                    onPressed: () => _showAddTestPlayersDialog(context, authService),
                  ),
                ] else ...[
                  if (isOpen) ...[
                    if (isJoined) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Joined (Tap to Leave)', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () => _confirmLeaveTournament(context, authService),
                      ),
                    ] else ...[
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Join Tournament', style: TextStyle(fontSize: 16)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          try {
                            await authService.joinTournament(clubId: clubId, tournamentId: tournamentId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Successfully joined the tournament!')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                            }
                          }
                        },
                      ),
                    ],
                  ] else ...[
                    if (isJoined) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.check_circle, color: Colors.green),
                        label: const Text('Joined (Tap to Leave)', style: TextStyle(color: Colors.redAccent)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                        onPressed: () => _confirmLeaveTournament(context, authService),
                      ),
                    ] else ...[
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('tournament_requests')
                            .where('tournamentId', isEqualTo: tournamentId)
                            .where('toUid', isEqualTo: currentUid)
                            .where('status', isEqualTo: 'pending')
                            .snapshots(),
                        builder: (context, reqSnapshot) {
                          final hasInvite = reqSnapshot.hasData && reqSnapshot.data!.docs.isNotEmpty;
                          if (hasInvite) {
                            final reqDoc = reqSnapshot.data!.docs.first;
                            return ElevatedButton.icon(
                              icon: const Icon(Icons.check, color: Colors.white),
                              label: const Text('Accept Tournament Invitation', style: TextStyle(fontSize: 16)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () async {
                                try {
                                  await authService.acceptTournamentRequest(reqDoc.id, clubId, tournamentId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Accepted tournament invitation!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                  }
                                }
                              },
                            );
                          }

                          return Card(
                            color: Colors.orange.withValues(alpha: 0.1),
                            child: const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Icon(Icons.lock_outline, color: Colors.orange),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'This tournament is closed. Only an owner or manager can invite you.',
                                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ],

                _buildDoublesSection(context, authService, data, currentUid),
                _buildMatchHistorySection(context),

                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 12),

                // Participants List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Participants (${participants.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (participants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text('No participants yet.', style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: participants.length,
                    itemBuilder: (context, index) {
                      final p = participants[index] as Map<String, dynamic>;
                      final pUid = p['uid'] as String? ?? '';
                      final pName = p['username'] as String? ?? 'Member';

                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(pName, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: (isOwnerOrManager && pUid != currentUid)
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _confirmKickParticipant(context, authService, pUid, pName),
                                tooltip: 'Remove from tournament',
                              )
                            : null,
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

  void _confirmLeaveTournament(BuildContext context, AuthService authService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Tournament?'),
        content: const Text('Are you sure you want to leave this tournament?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await authService.leaveTournament(clubId: clubId, tournamentId: tournamentId);
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left tournament.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmKickParticipant(BuildContext context, AuthService authService, String pUid, String pName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Participant?'),
        content: Text('Are you sure you want to remove "$pName" from this tournament?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                await authService.removeParticipantFromTournament(
                  clubId: clubId,
                  tournamentId: tournamentId,
                  targetUid: pUid,
                );
                if (context.mounted) {
                  Navigator.pop(context); // Close dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed $pName from tournament.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHistorySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text('Tournament Match History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .collection('tournaments')
              .doc(tournamentId)
              .collection('matches')
              .orderBy('completedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No completed matches in history yet.', style: TextStyle(color: Colors.grey)),
              );
            }

            final matches = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                final match = matches[index];
                final data = match.data() as Map<String, dynamic>;
                final winnerUid = data['winnerUid'] ?? '';
                final loserUid = data['loserUid'] ?? '';
                final scoreText = data['scoreText'] ?? 'Completed';

                return FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(winnerUid).get(),
                  builder: (context, winnerSnap) {
                    final winnerName = winnerSnap.hasData && winnerSnap.data!.exists
                        ? (winnerSnap.data!.data() as Map<String, dynamic>)['username'] ?? 'Winner'
                        : 'Winner';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(loserUid).get(),
                      builder: (context, loserSnap) {
                        final loserName = loserSnap.hasData && loserSnap.data!.exists
                            ? (loserSnap.data!.data() as Map<String, dynamic>)['username'] ?? 'Loser'
                            : 'Loser';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.emoji_events, color: Colors.white, size: 20),
                            ),
                            title: Text('$winnerName vs $loserName', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Winner: $winnerName • Score: $scoreText'),
                            trailing: const Icon(Icons.check_circle_outline, color: Colors.green),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _confirmDeleteDoublesPair(BuildContext context, AuthService authService, String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Doubles Pair?'),
        content: const Text('Are you sure you want to remove this confirmed doubles partnership?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await authService.deleteDoublesPartnerRequest(
                  clubId: clubId,
                  tournamentId: tournamentId,
                  requestId: requestId,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Doubles pair removed.')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Widget _buildDoublesSection(BuildContext context, AuthService authService, Map<String, dynamic> data, String currentUid) {
    final String doublesType = data['doublesType'] ?? 'none';
    final bool hasMixed = data['hasMixedDoubles'] ?? (doublesType == 'mixed_only' || doublesType == 'all');
    final bool hasGender = data['hasGenderDoubles'] ?? (doublesType == 'gendered' || doublesType == 'all');
    final bool hasOpen = doublesType == 'open';
    final bool hasAnyDoubles = hasMixed || hasGender || hasOpen;

    if (!hasAnyDoubles) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Doubles Partnerships',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.group_add, size: 16),
              label: const Text('Request Partner'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () => _showRequestDoublesDialog(context, authService, data),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .collection('tournaments')
              .doc(tournamentId)
              .collection('doubles_requests')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No doubles partner requests or pairs yet.', style: TextStyle(color: Colors.grey)),
              );
            }

            final reqs = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reqs.length,
              itemBuilder: (context, index) {
                final req = reqs[index];
                final reqData = req.data() as Map<String, dynamic>;
                final eventType = reqData['eventType'] ?? 'doubles';
                String eventDisplay = 'Doubles';
                if (eventType == 'mixed') {
                  eventDisplay = 'Mixed Doubles';
                } else if (eventType == 'open_doubles') {
                  eventDisplay = 'Open Doubles';
                } else if (eventType == 'mens_doubles') {
                  eventDisplay = "Men's Doubles";
                } else if (eventType == 'womens_doubles') {
                  eventDisplay = "Women's Doubles";
                }
                final fromUid = reqData['fromUid'];
                final toUid = reqData['toUid'];
                final fromName = reqData['fromUsername'] ?? 'Player';
                final toName = reqData['toUsername'] ?? 'Player';
                final status = reqData['status'] ?? 'pending';

                final bool isRecipient = toUid == currentUid;
                final bool isSender = fromUid == currentUid;

                if (!isRecipient && !isSender && !isOwnerOrManager) {
                  return const SizedBox.shrink();
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: status == 'accepted' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      child: Icon(
                        status == 'accepted' ? Icons.handshake : Icons.hourglass_top,
                        color: status == 'accepted' ? Colors.green : Colors.orange,
                      ),
                    ),
                    title: Text('$fromName & $toName', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('Event: $eventDisplay • Status: $status', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: status == 'pending' && isRecipient
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.check, color: Colors.green),
                                onPressed: () async {
                                  try {
                                    await authService.acceptDoublesPartner(
                                      clubId: clubId,
                                      tournamentId: tournamentId,
                                      requestId: req.id,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Doubles partnership accepted!')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(6),
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () => authService.declineDoublesPartner(
                                  clubId: clubId,
                                  tournamentId: tournamentId,
                                  requestId: req.id,
                                ),
                              ),
                            ],
                          )
                        : (isSender || isOwnerOrManager)
                            ? IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                                onPressed: () => status == 'accepted'
                                    ? _confirmDeleteDoublesPair(context, authService, req.id)
                                    : authService.deleteDoublesPartnerRequest(clubId: clubId, tournamentId: tournamentId, requestId: req.id),
                                tooltip: 'Cancel / Remove pair',
                              )
                            : null,
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  void _showRequestDoublesDialog(BuildContext context, AuthService authService, Map<String, dynamic> data) {
    String? selectedPartnerUid;
    String? selectedPartnerUsername;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request Doubles Partner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Partner from Club Members', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  width: double.maxFinite,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: authService.getClubMembers(clubId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final members = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final m = members[index].data() as Map<String, dynamic>;
                          final mUid = m['uid'] ?? '';
                          final mName = m['username'] ?? 'Member';
                          if (mUid == authService.currentUser?.uid) return const SizedBox.shrink();

                          final isSelected = selectedPartnerUid == mUid;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(mUid).get(),
                            builder: (context, userSnap) {
                              final userData = userSnap.hasData && userSnap.data!.exists
                                  ? userSnap.data!.data() as Map<String, dynamic>?
                                  : null;
                              final gender = userData?['gender'] ?? m['gender'] ?? 'Not set';

                              return ListTile(
                                leading: CircleAvatar(child: Text(mName.isNotEmpty ? mName[0].toUpperCase() : 'M')),
                                title: Text(mName),
                                subtitle: Text('Gender: $gender'),
                                trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.radio_button_unchecked),
                                onTap: () => setDialogState(() {
                                  selectedPartnerUid = mUid;
                                  selectedPartnerUsername = mName;
                                }),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: selectedPartnerUid == null ? null : () async {
                try {
                  final user = authService.currentUser;
                  if (user == null) return;

                  final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
                  final partnerDoc = await FirebaseFirestore.instance.collection('users').doc(selectedPartnerUid).get();

                  final userGender = userDoc.data()?['gender'] ?? 'Not set';
                  final partnerGender = partnerDoc.data()?['gender'] ?? 'Not set';

                  if (userGender == 'Not set' || partnerGender == 'Not set') {
                    throw 'Both you and your partner must have your gender set in Settings before pairing in doubles.';
                  }

                  final String doublesType = data['doublesType'] ?? 'none';
                  final bool hasMixed = data['hasMixedDoubles'] ?? (doublesType == 'mixed_only' || doublesType == 'all');
                  final bool hasGender = data['hasGenderDoubles'] ?? (doublesType == 'gendered' || doublesType == 'all');
                  final bool hasOpen = doublesType == 'open';

                  String? deducedEvent;
                  if (hasMixed && userGender != partnerGender) {
                    deducedEvent = 'mixed';
                  } else if (hasGender && userGender == 'Male' && partnerGender == 'Male') {
                    deducedEvent = 'mens_doubles';
                  } else if (hasGender && userGender == 'Female' && partnerGender == 'Female') {
                    deducedEvent = 'womens_doubles';
                  } else if (hasOpen) {
                    deducedEvent = 'open_doubles';
                  }

                  if (deducedEvent == null) {
                    throw 'No eligible doubles event matches both players\' genders for this tournament.';
                  }

                  await authService.requestDoublesPartner(
                    clubId: clubId,
                    tournamentId: tournamentId,
                    eventType: deducedEvent,
                    partnerUid: selectedPartnerUid!,
                    partnerUsername: selectedPartnerUsername!,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Doubles partner request sent to $selectedPartnerUsername!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Send Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTestPlayersDialog(BuildContext context, AuthService authService) {
    int botCount = 7;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Test Participants'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Generate test players with configured genders and ratings to test brackets, matchmaking, and rankings without creating real accounts.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Text('Number of test players to add: $botCount', style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: botCount.toDouble(),
                min: 1,
                max: 15,
                divisions: 14,
                label: '$botCount Players',
                onChanged: (val) => setDialogState(() => botCount = val.toInt()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await authService.addTestParticipantsToTournament(
                    clubId: clubId,
                    tournamentId: tournamentId,
                    count: botCount,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Added $botCount test players to the tournament!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Add Players'),
            ),
          ],
        ),
      ),
    );
  }

  void _showStartTournamentDialog(BuildContext context, AuthService authService, Map<String, dynamic> data, int participantCount) {
    int step = 0; // 0 = Review, 1 = Final Confirmation
    final List participants = List.from(data['participants'] ?? []);
    final String seedingMethod = data['seedingMethod'] ?? 'ITTF Seeded';
    final bool hasThirdPlacePlayoff = data['hasThirdPlacePlayoff'] ?? true;
    final String tournamentStyle = data['tournamentStyle'] ?? 'Single Elimination';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(step == 0 ? 'Start Tournament (Step 1 of 2: Review)' : 'Start Tournament (Step 2 of 2: Confirm)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step == 0) ...[
                  Text('Participants Ready: $participantCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (participantCount < 2)
                    const Padding(
                      padding: EdgeInsets.only(top: 8.0),
                      child: Text('Warning: At least 2 participants are required to start.', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  const SizedBox(height: 12),
                  Text('Style: $tournamentStyle'),
                  Text('Seeding: $seedingMethod'),
                  Text('3rd Place Playoff: ${hasThirdPlacePlayoff ? "Enabled" : "Disabled"}'),
                  const SizedBox(height: 16),
                  const Text('Participants:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 120,
                    width: double.maxFinite,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: participants.length,
                      itemBuilder: (context, index) {
                        final p = participants[index] as Map<String, dynamic>;
                        return Text('• ${p['username'] ?? 'Member'}', style: const TextStyle(fontSize: 13));
                      },
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
                  const SizedBox(height: 12),
                  const Text(
                    'Final Confirmation',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Starting this tournament will lock in the participant list and generate the tournament bracket. This action cannot be undone.',
                    style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (step == 1)
              TextButton(
                onPressed: () => setDialogState(() => step = 0),
                child: const Text('Back'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: participantCount < 2 ? null : () async {
                if (step == 0) {
                  setDialogState(() => step = 1);
                } else {
                  try {
                    await authService.startTournament(
                      clubId: clubId,
                      tournamentId: tournamentId,
                      seedingMethod: seedingMethod,
                      hasThirdPlacePlayoff: hasThirdPlacePlayoff,
                    );
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tournament started successfully!')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                }
              },
              child: Text(step == 0 ? 'Next' : 'Confirm & Launch'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteMembersModal(BuildContext context, AuthService authService, List existingParticipantUids, String tournamentName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Invite Club Members', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tournament_requests').where('tournamentId', isEqualTo: tournamentId).snapshots(),
                    builder: (context, requestSnapshot) {
                      final requestDocs = requestSnapshot.hasData ? requestSnapshot.data!.docs : [];
                      final Set<String> pendingUids = {};
                      for (var doc in requestDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['status'] == 'pending') {
                          pendingUids.add(data['toUid']);
                        }
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: authService.getClubMembers(clubId),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                          final members = snapshot.data!.docs;

                          if (members.isEmpty) {
                            return const Center(child: Text('No members in club.', style: TextStyle(color: Colors.grey)));
                          }

                          return ListView.builder(
                            controller: scrollController,
                            itemCount: members.length,
                            itemBuilder: (context, index) {
                              final m = members[index].data() as Map<String, dynamic>;
                              final mUid = m['uid'] as String? ?? '';
                              final mName = m['username'] as String? ?? 'Member';
                              final bool isAlreadyIn = existingParticipantUids.contains(mUid);
                              final bool isInvited = pendingUids.contains(mUid);

                              Widget trailingWidget;
                              if (isAlreadyIn) {
                                trailingWidget = const Text('Joined ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold));
                              } else if (isInvited) {
                                trailingWidget = OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                  child: const Text('Retract'),
                                  onPressed: () async {
                                    try {
                                      await authService.retractTournamentInvitation(
                                        tournamentId: tournamentId,
                                        targetUid: mUid,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Invitation retracted.')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                );
                              } else {
                                trailingWidget = ElevatedButton(
                                  child: const Text('Invite'),
                                  onPressed: () async {
                                    try {
                                      await authService.inviteMemberToTournament(
                                        clubId: clubId,
                                        tournamentId: tournamentId,
                                        tournamentName: tournamentName,
                                        targetUid: mUid,
                                        targetUsername: mName,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Invitation sent to $mName!')),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                );
                              }

                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(mName),
                                subtitle: Text(m['role'] ?? 'member'),
                                trailing: trailingWidget,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class TournamentSettingsPage extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> currentData;

  const TournamentSettingsPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.currentData,
  });

  @override
  State<TournamentSettingsPage> createState() => _TournamentSettingsPageState();
}

class _TournamentSettingsPageState extends State<TournamentSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _pointsController;
  late String _tournamentStyle;
  late String _seedingMethod;
  late bool _hasThirdPlacePlayoff;
  late String _singlesType;
  late String _doublesType;
  late bool _isOpen;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentData['name'] ?? '');
    _descriptionController = TextEditingController(text: widget.currentData['description'] ?? '');
    _pointsController = TextEditingController(text: (widget.currentData['rankingPoints'] ?? 1000).toString());
    _tournamentStyle = widget.currentData['tournamentStyle'] ?? 'Single Elimination';
    _seedingMethod = widget.currentData['seedingMethod'] ?? 'ITTF Seeded';
    _hasThirdPlacePlayoff = widget.currentData['hasThirdPlacePlayoff'] ?? true;
    _singlesType = widget.currentData['singlesType'] ?? 'everyone';
    _doublesType = widget.currentData['doublesType'] ?? 'none';
    _isOpen = widget.currentData['isOpen'] ?? !(widget.currentData['needsPermission'] ?? false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tournament name cannot be empty.')),
      );
      return;
    }

    final points = int.tryParse(_pointsController.text.trim()) ?? 1000;

    // Check if any existing doubles pairs will become invalid
    final doublesSnap = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('doubles_requests')
        .get();

    List<DocumentSnapshot> invalidRequests = [];
    for (var doc in doublesSnap.docs) {
      final reqData = doc.data();
      final eventType = reqData['eventType'] ?? '';

      bool isInvalid = false;
      if (_doublesType == 'none') {
        isInvalid = true;
      } else if (_doublesType == 'gendered' && (eventType == 'mixed' || eventType == 'open_doubles')) {
        isInvalid = true;
      } else if (_doublesType == 'mixed_only' && (eventType == 'mens_doubles' || eventType == 'womens_doubles' || eventType == 'open_doubles')) {
        isInvalid = true;
      } else if (_doublesType == 'open' && (eventType == 'mixed' || eventType == 'mens_doubles' || eventType == 'womens_doubles')) {
        isInvalid = true;
      }

      if (isInvalid) {
        invalidRequests.add(doc);
      }
    }

    if (invalidRequests.isNotEmpty) {
      if (!mounted) return;
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Disband Invalid Doubles Pairs?'),
          content: Text(
            'Changing the doubles format will invalidate and disband ${invalidRequests.length} existing doubles pair(s) or request(s) that do not match the new rules. Do you wish to proceed?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disband & Save'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Delete the invalid doubles requests
      for (var doc in invalidRequests) {
        await doc.reference.delete();
      }
    }

    setState(() => _isSaving = true);
    final authService = AuthService();

    try {
      await authService.updateTournamentSettings(
        clubId: widget.clubId,
        tournamentId: widget.tournamentId,
        name: name,
        description: _descriptionController.text.trim(),
        isOpen: _isOpen,
        rankingPoints: points,
        tournamentStyle: _tournamentStyle,
        seedingMethod: _seedingMethod,
        hasThirdPlacePlayoff: _hasThirdPlacePlayoff,
        singlesType: _singlesType,
        doublesType: _doublesType,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _confirmDelete() {
    int step = 0; // 0 = Warning, 1 = Final Confirmation
    final authService = AuthService();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(step == 0 ? 'Delete Tournament (Step 1 of 2)' : 'Delete Tournament (Step 2 of 2: Final)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (step == 0) ...[
                const Text(
                  'Warning: Deleting this tournament will permanently erase all tournament data, participant lists, and match brackets. This action is irreversible.',
                  style: TextStyle(fontSize: 14, height: 1.3),
                ),
              ] else ...[
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Final Confirmation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Are you 100% sure you want to permanently delete this tournament?',
                  style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.3),
                ),
              ],
            ],
          ),
          actions: [
            if (step == 1)
              TextButton(
                onPressed: () => setDialogState(() => step = 0),
                child: const Text('Back'),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (step == 0) {
                  setDialogState(() => step = 1);
                } else {
                  try {
                    await authService.deleteTournament(widget.clubId, widget.tournamentId);
                    if (context.mounted) {
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Pop settings page
                      Navigator.pop(context); // Pop details page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tournament deleted permanently.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                }
              },
              child: Text(step == 0 ? 'Next' : 'Delete Permanently'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tournament Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isSaving ? null : _saveSettings,
            tooltip: 'Save Settings',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'General Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tournament Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description / Subheading',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Ranking Points Value (ITTF System)',
                hintText: 'Points awarded for this tournament',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _tournamentStyle,
              decoration: const InputDecoration(
                labelText: 'Tournament Style / Format',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'Single Elimination', child: Text('Single Elimination (Knockout)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'Double Elimination', child: Text('Double Elimination', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'Round Robin', child: Text('Round Robin', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'Swiss System', child: Text('Swiss System', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'World Cup', child: Text('World Cup (Group Stage + KO)', overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _tournamentStyle = val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _singlesType,
              decoration: const InputDecoration(
                labelText: 'Singles Format',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'everyone', child: Text('Everyone in Same Bracket (Open)', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'separate_gender', child: Text("Men's & Women's Singles (Separate)", overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _singlesType = val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _doublesType,
              decoration: const InputDecoration(
                labelText: 'Doubles Format',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No Doubles', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'open', child: Text('Open Doubles', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'gendered', child: Text("Men's and Women's Doubles only", overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'mixed_only', child: Text('Mixed Doubles only', overflow: TextOverflow.ellipsis)),
                DropdownMenuItem(value: 'all', child: Text("Men's, Women's, and Mixed Doubles", overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _doublesType = val);
              },
            ),
            const SizedBox(height: 16),
            if (_tournamentStyle == 'Single Elimination') ...[
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _seedingMethod,
                decoration: const InputDecoration(
                  labelText: 'Seeding Method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ITTF Seeded', child: Text('ITTF Seeded (Top seeds meet in final)', overflow: TextOverflow.ellipsis)),
                  DropdownMenuItem(value: 'Random', child: Text('Random Draw', overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _seedingMethod = val);
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Include 3rd Place Playoff', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Bronze medal match between semifinal losers', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _hasThirdPlacePlayoff,
                    onChanged: (val) => setState(() => _hasThirdPlacePlayoff = val),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'Access',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Open Tournament', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Allow members to join directly without requiring an invite', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: _isOpen,
                  onChanged: (val) => setState(() => _isOpen = val),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Danger Zone',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever),
                label: const Text('Delete Tournament'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _confirmDelete,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class TournamentRunnerPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const TournamentRunnerPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentData,
  });

  @override
  Widget build(BuildContext context) {
    final String style = tournamentData['tournamentStyle'] ?? 'Single Elimination';

    switch (style) {
      case 'Double Elimination':
        return DoubleEliminationPage(clubId: clubId, tournamentId: tournamentId, tournamentData: tournamentData);
      case 'Round Robin':
        return RoundRobinPage(clubId: clubId, tournamentId: tournamentId, tournamentData: tournamentData);
      case 'Swiss System':
        return SwissSystemPage(clubId: clubId, tournamentId: tournamentId, tournamentData: tournamentData);
      case 'World Cup':
        return WorldCupPage(clubId: clubId, tournamentId: tournamentId, tournamentData: tournamentData);
      case 'Single Elimination':
      default:
        return TournamentBracketPage(clubId: clubId, tournamentId: tournamentId, tournamentData: tournamentData);
    }
  }
}

class RoundRobinPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const RoundRobinPage({super.key, required this.clubId, required this.tournamentId, required this.tournamentData});

  @override
  Widget build(BuildContext context) {
    final name = tournamentData['name'] ?? 'Tournament';
    List participants = List.from(tournamentData['participants'] ?? []);

    return Scaffold(
      appBar: AppBar(title: Text('$name - Round Robin')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Format: Round Robin (Every participant plays every other participant)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Match Fixtures (All-Play-All)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._buildRoundRobinFixtures(context, participants),
            const SizedBox(height: 24),
            const Text('Live Standings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildStandingsTable(participants),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRoundRobinFixtures(BuildContext context, List participants) {
    List<Widget> fixtures = [];
    int matchNum = 1;
    final sport = tournamentData['sport'] ?? 'Table Tennis';

    for (int i = 0; i < participants.length; i++) {
      for (int j = i + 1; j < participants.length; j++) {
        final p1Uid = participants[i]['uid'] ?? '';
        final p2Uid = participants[j]['uid'] ?? '';
        final p1 = participants[i]['username'] ?? 'Player 1';
        final p2 = participants[j]['username'] ?? 'Player 2';
        final String mId = 'rr_match_${i}_$j';

        fixtures.add(
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(child: Text('$matchNum')),
              title: Text('$p1 vs $p2'),
              subtitle: const Text('Tap to record result or play live match'),
              trailing: const Icon(Icons.sports_tennis, color: Colors.blue),
              onTap: () {
                showMatchActionModal(
                  context: context,
                  clubId: clubId,
                  tournamentId: tournamentId,
                  matchId: mId,
                  p1Uid: p1Uid,
                  p1Name: p1,
                  p2Uid: p2Uid,
                  p2Name: p2,
                  sport: sport,
                  isOwnerOrManager: true,
                );
              },
            ),
          ),
        );
        matchNum++;
      }
    }
    return fixtures.isEmpty ? [const Text('Need at least 2 participants for fixtures.')] : fixtures;
  }

  Widget _buildStandingsTable(List participants) {
    return Table(
      border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3)),
      columnWidths: const {
        0: FlexColumnWidth(1),
        1: FlexColumnWidth(4),
        2: FlexColumnWidth(2),
        3: FlexColumnWidth(2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Colors.blueGrey),
          children: [
            Padding(padding: EdgeInsets.all(8.0), child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('Player', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('Played', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
            Padding(padding: EdgeInsets.all(8.0), child: Text('Pts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white))),
          ],
        ),
        ...participants.asMap().entries.map((entry) {
          final idx = entry.key;
          final p = entry.value;
          final name = p['username'] ?? 'Player';
          return TableRow(
            children: [
              Padding(padding: const EdgeInsets.all(8.0), child: Text('#${idx + 1}')),
              Padding(padding: const EdgeInsets.all(8.0), child: Text(name)),
              const Padding(padding: EdgeInsets.all(8.0), child: Text('0')),
              const Padding(padding: EdgeInsets.all(8.0), child: Text('0')),
            ],
          );
        }),
      ],
    );
  }
}

class DoubleEliminationPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const DoubleEliminationPage({super.key, required this.clubId, required this.tournamentId, required this.tournamentData});

  @override
  Widget build(BuildContext context) {
    final name = tournamentData['name'] ?? 'Tournament';
    return Scaffold(
      appBar: AppBar(title: Text('$name - Double Elimination')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Format: Double Elimination (Participants must lose two matches to be eliminated)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
            Text('Winners Bracket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Card(child: ListTile(title: Text('Winners Round 1 Fixtures'), subtitle: Text('Standard Double Elimination pairing tree'))),
            SizedBox(height: 20),
            Text('Losers Bracket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
            SizedBox(height: 12),
            Card(child: ListTile(title: Text('Losers Round 1 Fixtures'), subtitle: Text('Elimination matching tree'))),
          ],
        ),
      ),
    );
  }
}

class SwissSystemPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const SwissSystemPage({super.key, required this.clubId, required this.tournamentId, required this.tournamentData});

  @override
  Widget build(BuildContext context) {
    final name = tournamentData['name'] ?? 'Tournament';
    return Scaffold(
      appBar: AppBar(title: Text('$name - Swiss System')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Format: Swiss System (Non-elimination rounds pairing players with similar records)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
            Text('Round 1 Pairings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Card(child: ListTile(title: Text('Swiss Round 1'), subtitle: Text('Initial pairings generated'))),
          ],
        ),
      ),
    );
  }
}

class WorldCupPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const WorldCupPage({super.key, required this.clubId, required this.tournamentId, required this.tournamentData});

  @override
  Widget build(BuildContext context) {
    final name = tournamentData['name'] ?? 'Tournament';
    return Scaffold(
      appBar: AppBar(title: Text('$name - World Cup (Groups + KO)')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Format: World Cup Style (Group Stage followed by Knockout Stage)', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 20),
            Text('Group Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Card(child: ListTile(title: Text('Group A & Group B Standings'), subtitle: Text('Top 2 from each group advance to Knockout'))),
            SizedBox(height: 20),
            Text('Knockout Stage', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            SizedBox(height: 12),
            Card(child: ListTile(title: Text('Quarterfinals / Semifinals'), subtitle: Text('Single elimination bracket for group qualifiers'))),
          ],
        ),
      ),
    );
  }
}

class TournamentBracketPage extends StatelessWidget {
  final String clubId;
  final String tournamentId;
  final Map<String, dynamic> tournamentData;

  const TournamentBracketPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentData,
  });

  String _getRoundTitle(int bracketSize) {
    switch (bracketSize) {
      case 2:
        return 'Finals';
      case 4:
        return 'Semifinals';
      case 8:
        return 'Quarterfinals';
      case 16:
        return 'Round of 16';
      case 32:
        return 'Round of 32';
      case 64:
        return 'Round of 64';
      default:
        return 'Knockout Bracket ($bracketSize Players)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String name = tournamentData['name'] ?? 'Tournament';
    final List participants = List.from(tournamentData['participants'] ?? []);
    final String seedingMethod = tournamentData['seedingMethod'] ?? 'ITTF Seeded';
    final bool hasThirdPlace = tournamentData['hasThirdPlacePlayoff'] ?? true;
    final String style = tournamentData['tournamentStyle'] ?? 'Single Elimination';

    List matchedParticipants = List.from(participants);
    if (seedingMethod == 'Random') {
      matchedParticipants.shuffle();
    }

    // Calculate bracket size M = next power of 2
    int m = 2;
    while (m < matchedParticipants.length) {
      m *= 2;
    }
    final int numByes = m - matchedParticipants.length;
    final String roundTitle = _getRoundTitle(m);

    return Scaffold(
      appBar: AppBar(
        title: Text('$name - Bracket'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.blue.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Format: $style', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Seeding Method: $seedingMethod'),
                    Text('3rd Place Playoff: ${hasThirdPlace ? "Enabled" : "Disabled"}'),
                    Text('Total Participants: ${participants.length} ($numByes BYE${numByes == 1 ? "" : "s"})'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(roundTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (numByes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                child: Text(
                  'ITTF Guidelines Applied: Top $numByes seed(s) received a Round 1 BYE.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              )
            else
              const SizedBox(height: 12),
            ..._buildMatchups(context, matchedParticipants, m),
            if (hasThirdPlace && participants.length >= 4) ...[
              const SizedBox(height: 24),
              const Text('3rd Place Playoff (Bronze Match)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 8),
              const Card(
                child: ListTile(
                  leading: Icon(Icons.military_tech, color: Colors.amber),
                  title: Text('Bronze Medal Match'),
                  subtitle: Text('Loser of Semi-Final 1 vs Loser of Semi-Final 2'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMatchups(BuildContext context, List participants, int m) {
    List<Widget> widgets = [];
    int matchNum = 1;
    final sport = tournamentData['sport'] ?? 'Table Tennis';

    List<Map<String, dynamic>> slots = List.generate(m, (i) => {});
    for (int i = 0; i < participants.length; i++) {
      slots[i] = Map<String, dynamic>.from(participants[i]);
    }

    for (int i = 0; i < m; i += 2) {
      final p1 = slots[i];
      final p2 = slots[i + 1];

      final String p1Name = p1['username'] ?? 'BYE';
      final String p2Name = p2['username'] ?? 'BYE';
      final String p1Uid = p1['uid'] ?? '';
      final String p2Uid = p2['uid'] ?? '';

      final bool isByeMatch = p1Name == 'BYE' || p2Name == 'BYE';
      final String mId = 'ko_match_$matchNum';

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: isByeMatch
                ? null
                : () {
                    showMatchActionModal(
                      context: context,
                      clubId: clubId,
                      tournamentId: tournamentId,
                      matchId: mId,
                      p1Uid: p1Uid,
                      p1Name: p1Name,
                      p2Uid: p2Uid,
                      p2Name: p2Name,
                      sport: sport,
                      isOwnerOrManager: true,
                    );
                  },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Match $matchNum', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p1Name, style: TextStyle(fontSize: 16, fontWeight: p1Name != 'BYE' ? FontWeight.bold : FontWeight.normal)),
                            if (p1Name != 'BYE' && p2Name == 'BYE')
                              const Text(' (Advances via BYE)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(p2Name, style: TextStyle(fontSize: 16, fontWeight: p2Name != 'BYE' ? FontWeight.bold : FontWeight.normal)),
                            if (p2Name != 'BYE' && p1Name == 'BYE')
                              const Text(' (Advances via BYE)', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isByeMatch) const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        ),
      );
      matchNum++;
    }
    return widgets;
  }
}

void showMatchActionModal({
  required BuildContext context,
  required String clubId,
  required String tournamentId,
  required String matchId,
  required String p1Uid,
  required String p1Name,
  required String p2Uid,
  required String p2Name,
  required String sport,
  required bool isOwnerOrManager,
}) {
  final authService = AuthService();
  final scoreController = TextEditingController(text: '3-0');
  String selectedWinnerUid = p1Uid;
  String selectedWinnerName = p1Name;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$p1Name vs $p2Name', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Sport: $sport • Tournament Match', style: const TextStyle(color: Colors.grey)),
                  const Divider(height: 24),
                  const Text('Record Result (Quick Input)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Select Winner:'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: Text(p1Name),
                          selected: selectedWinnerUid == p1Uid,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                selectedWinnerUid = p1Uid;
                                selectedWinnerName = p1Name;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(p2Name),
                          selected: selectedWinnerUid == p2Uid,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                selectedWinnerUid = p2Uid;
                                selectedWinnerName = p2Name;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoreController,
                    decoration: const InputDecoration(
                      labelText: 'Score Summary / Set Score',
                      hintText: 'e.g. 3-1 or 11-9, 9-11, 11-8',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm & Save Result'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () async {
                        final String loserUid = selectedWinnerUid == p1Uid ? p2Uid : p1Uid;
                        try {
                          await authService.recordTournamentMatchResult(
                            clubId: clubId,
                            tournamentId: tournamentId,
                            matchId: matchId,
                            winnerUid: selectedWinnerUid,
                            loserUid: loserUid,
                            scoreText: scoreController.text.trim(),
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Match result saved! Winner: $selectedWinnerName')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent));
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text('Live Match Option', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  const Text('Start an interactive live scoreboard for this match.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.sports_tennis),
                      label: const Text('Play Match Live'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                      onPressed: () {
                        Navigator.pop(context);
                        if (sport == 'Table Tennis') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TableTennisMatch(
                                p1Name: p1Name,
                                p2Name: p2Name,
                                p3Name: '',
                                p4Name: '',
                                isDoubles: false,
                                setsToWin: 3,
                              ),
                            ),
                          );
                        } else if (sport == 'Badminton') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BadmintonMatch(
                                p1Name: p1Name,
                                p2Name: p2Name,
                                p3Name: '',
                                p4Name: '',
                                isDoubles: false,
                                gamesToWin: 2,
                              ),
                            ),
                          );
                        }
                      },
                    ),
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