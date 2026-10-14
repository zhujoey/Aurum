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
                  final description = data['description'] as String? ?? '';
                  final sport = data['sport'] ?? 'Multiple';
                  final int rankingPoints = data['rankingPoints'] ?? 1000;
                  final isOpen = data['isOpen'] ?? !(data['needsPermission'] ?? false);

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.emoji_events)),
                    title: Text(name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) ...[
                          Text(description, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          const SizedBox(height: 2),
                        ],
                        Text('$sport • $rankingPoints pts'),
                      ],
                    ),
                    trailing: isOwner
                        ? IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _showDeleteTournamentDialog(context, clubId, t.id, name),
                    )
                        : (!isOpen ? const Icon(Icons.lock_outline, size: 16) : null),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TournamentDetailsPage(
                            clubId: clubId,
                            tournamentId: t.id,
                            isOwnerOrManager: isOwner,
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
                          builder: (context) => TournamentBracketPage(
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
                    onPressed: () => _showInviteMembersModal(context, authService, participantUids),
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
                        onPressed: () async {
                          try {
                            await authService.leaveTournament(clubId: clubId, tournamentId: tournamentId);
                            if (context.mounted) {
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
                        onPressed: () async {
                          try {
                            await authService.leaveTournament(clubId: clubId, tournamentId: tournamentId);
                            if (context.mounted) {
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
                      ),
                    ] else ...[
                      Card(
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
                      ),
                    ],
                  ],
                ],

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
                        title: Text(pName),
                        trailing: (isOwnerOrManager && pUid != currentUid)
                            ? IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _confirmKickParticipant(context, authService, pUid, pName),
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

  void _showInviteMembersModal(BuildContext context, AuthService authService, List existingParticipantUids) {
    final Set<String> invitingUids = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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
                              final bool isInviting = invitingUids.contains(mUid);

                              return ListTile(
                                leading: const CircleAvatar(child: Icon(Icons.person)),
                                title: Text(mName),
                                subtitle: Text(m['role'] ?? 'member'),
                                trailing: isAlreadyIn
                                    ? const Text('Joined ✓', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                    : ElevatedButton(
                                        onPressed: isInviting
                                            ? null
                                            : () async {
                                                setModalState(() {
                                                  invitingUids.add(mUid);
                                                });
                                                try {
                                                  await authService.inviteMemberToTournament(
                                                    clubId: clubId,
                                                    tournamentId: tournamentId,
                                                    targetUid: mUid,
                                                    targetUsername: mName,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Added $mName to tournament!')),
                                                    );
                                                  }
                                                } catch (e) {
                                                  setModalState(() {
                                                    invitingUids.remove(mUid);
                                                  });
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                                  }
                                                }
                                              },
                                        child: isInviting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2),
                                              )
                                            : const Text('Invite / Add'),
                                      ),
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
                    Text('Total Participants: ${participants.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Knockout Round 1 (Quarterfinals / Semifinals)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._buildMatchups(matchedParticipants),
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

  List<Widget> _buildMatchups(List participants) {
    List<Widget> widgets = [];
    int matchNum = 1;
    for (int i = 0; i < participants.length; i += 2) {
      final p1 = participants[i]['username'] ?? 'TBD';
      final p2 = (i + 1 < participants.length) ? (participants[i + 1]['username'] ?? 'TBD') : 'BYE';

      widgets.add(
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Match $matchNum', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Expanded(
                  child: Column(
                    children: [
                      Text(p1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const Divider(),
                      Text(p2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      matchNum++;
    }
    return widgets;
  }
}