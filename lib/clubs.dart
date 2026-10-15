import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/main.dart';
import 'package:sportspro/club_requests.dart';
import 'package:sportspro/tournaments.dart';


class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  StreamSubscription? _membershipSubscription;
  bool _initialized = false;
  bool _wasInAClub = false;

  @override
  void initState() {
    super.initState();
    _startMembershipListener();
  }

  @override
  void dispose() {
    _membershipSubscription?.cancel();
    super.dispose();
  }

  void _startMembershipListener() {
    // Listen to combined status (owned or joined)
    _membershipSubscription = _db.collection('users').doc(_authService.currentUser?.uid).snapshots().listen((snap) {
      if (!snap.exists || !mounted) return;
      
      final data = snap.data() as Map<String, dynamic>;
      final bool currentlyInAClub = data['ownedClubId'] != null || data['joinedClubId'] != null;

      if (!_initialized) {
        _wasInAClub = currentlyInAClub;
        _initialized = true;
        return;
      }

      // If they were in a club and now they aren't, exit the page
      if (_wasInAClub && !currentlyInAClub) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are no longer part of that organization.')),
        );
      }

      _wasInAClub = currentlyInAClub;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clubs'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ClubRequestsPage()),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _authService.incomingClubRequests,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final int pendingCount = snapshot.data!.docs
                        .where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'pending')
                        .length;
                    
                    if (pendingCount == 0) return const SizedBox.shrink();

                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          '$pendingCount',
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _authService.myOwnedClubs,
        builder: (context, ownedSnapshot) {
          if (ownedSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Case 1: User owns a club
          if (ownedSnapshot.hasData && ownedSnapshot.data!.docs.isNotEmpty) {
            final clubDoc = ownedSnapshot.data!.docs.first;
            return _buildClubManagementView(clubDoc);
          }

          // Case 2: User doesn't own a club, check if they joined one
          return StreamBuilder<DocumentSnapshot>(
            stream: _authService.myJoinedClub,
            builder: (context, joinedSnapshot) {
              if (joinedSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (joinedSnapshot.hasData && joinedSnapshot.data!.exists && joinedSnapshot.data!.reference.parent.id == 'clubs') {
                 // The stream above returns the club document if it exists
                 return _buildJoinedClubView(joinedSnapshot.data!);
              }

              // Case 3: User is free
              return _buildNoClubView();
            },
          );
        },
      ),
    );
  }

  Widget _buildJoinedClubView(DocumentSnapshot clubDoc) {
    final data = clubDoc.data() as Map<String, dynamic>;
    final String clubName = data['name'] ?? 'Joined Club';
    final String sport = data['sport'] ?? 'Multiple';
    final String ownerName = data['ownerName'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Colors.green.withValues(alpha: 0.1),
          child: Column(
            children: [
              const Icon(Icons.verified_user, color: Colors.green, size: 40),
              const SizedBox(height: 16),
              Text(
                clubName,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text('Owned by $ownerName', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(label: Text(sport)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showLeaveClubDialog(clubDoc.id, clubName),
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('Leave'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Tournaments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 150,
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getClubTournaments(clubDoc.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No active tournaments', style: TextStyle(color: Colors.grey)));
              }
              final tournaments = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tDoc = tournaments[index];
                  final t = tDoc.data() as Map<String, dynamic>;
                  return Card(
                    child: InkWell(
                      onTap: () async {
                        final user = _authService.currentUser;
                        bool isManager = false;
                        if (user != null) {
                          final memberDoc = await FirebaseFirestore.instance
                              .collection('clubs')
                              .doc(clubDoc.id)
                              .collection('members')
                              .doc(user.uid)
                              .get();
                          final role = memberDoc.data()?['role'] ?? 'member';
                          isManager = role == 'owner' || role == 'manager';
                        }
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournamentDetailsPage(
                              clubId: clubDoc.id,
                              tournamentId: tDoc.id,
                              isOwnerOrManager: isManager,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text('${t['sport'] ?? "Sport"} • ${t['rankingPoints'] ?? 1000} pts', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Members',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getClubMembers(clubDoc.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final members = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index].data() as Map<String, dynamic>;
                  final String role = m['role'] ?? 'member';
                  final bool isOwner = role == 'owner';
                  final bool isManager = role == 'manager';

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(m['username'] ?? 'Unknown'),
                    subtitle: Text(isOwner ? 'Owner' : (isManager ? 'Manager' : 'Member')),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoClubView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_add, size: 80, color: Colors.grey),
          const SizedBox(height: 24),
          const Text(
            'You haven\'t created a club yet.',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _showCreateClubDialog,
            icon: const Icon(Icons.add),
            label: const Text('Create My Club'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClubManagementView(DocumentSnapshot clubDoc) {
    final data = clubDoc.data() as Map<String, dynamic>;
    final String clubName = data['name'] ?? 'My Club';
    final String sport = data['sport'] ?? 'Multiple';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          child: Column(
            children: [
              Text(
                clubName,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(
                    label: Text(sport),
                    avatar: const Icon(Icons.sports, size: 16),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteClubDialog(clubDoc.id, clubName),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: const Text('Disband'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Tournaments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 150,
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getClubTournaments(clubDoc.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No active tournaments', style: TextStyle(color: Colors.grey)));
              }
              final tournaments = snapshot.data!.docs;
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tournaments.length,
                itemBuilder: (context, index) {
                  final tDoc = tournaments[index];
                  final data = tDoc.data() as Map<String, dynamic>;
                  return Card(
                    child: InkWell(
                      onTap: () async {
                        final user = _authService.currentUser;
                        bool isManager = false;
                        if (user != null) {
                          final memberDoc = await FirebaseFirestore.instance
                              .collection('clubs')
                              .doc(clubDoc.id)
                              .collection('members')
                              .doc(user.uid)
                              .get();
                          final role = memberDoc.data()?['role'] ?? 'member';
                          isManager = role == 'owner' || role == 'manager';
                        }
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TournamentDetailsPage(
                              clubId: clubDoc.id,
                              tournamentId: tDoc.id,
                              isOwnerOrManager: isManager,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 200,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text('${data['sport'] ?? "Sport"} • ${data['rankingPoints'] ?? 1000} pts', style: const TextStyle(color: Colors.blue, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Members',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: () => _showAddMemberDialog(clubDoc.id, clubName),
                icon: const Icon(Icons.person_add),
                label: const Text('Invite'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getClubMembers(clubDoc.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final members = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index].data() as Map<String, dynamic>;
                  final String role = m['role'] ?? 'member';
                  final bool isOwner = role == 'owner';
                  final bool isManager = role == 'manager';

                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(m['username'] ?? 'Unknown'),
                    subtitle: Text(isOwner ? 'Owner' : (isManager ? 'Manager' : 'Member')),
                    trailing: isOwner
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PopupMenuButton<String>(
                                onSelected: (val) async {
                                  try {
                                    if (val == 'promote') {
                                      await _authService.updateMemberRole(clubId: clubDoc.id, memberUid: m['uid'], newRole: 'manager');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Promoted to Manager!')));
                                      }
                                    } else if (val == 'demote') {
                                      await _authService.updateMemberRole(clubId: clubDoc.id, memberUid: m['uid'], newRole: 'member');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demoted to Member')));
                                      }
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: isManager ? 'demote' : 'promote',
                                    child: Text(isManager ? 'Demote to Member' : 'Promote to Manager'),
                                  ),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _showKickMemberDialog(clubDoc.id, m['uid'], m['username'] ?? 'Unknown'),
                                tooltip: 'Remove from Club',
                              ),
                            ],
                          ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showCreateClubDialog() {
    final nameController = TextEditingController();
    String selectedSport = 'Table Tennis';
    final List<String> sports = ['Table Tennis', 'Tennis', 'Badminton'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Establish Organization'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Club Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedSport,
                decoration: const InputDecoration(
                  labelText: 'Sport',
                  border: OutlineInputBorder(),
                ),
                items: sports.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setDialogState(() => selectedSport = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await _authService.createClub(name, selectedSport);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Establish'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLeaveClubDialog(String clubId, String clubName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Club?'),
        content: Text('Are you sure you want to leave "$clubName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Pop dialog first
              try {
                await _authService.leaveClub(clubId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showKickMemberDialog(String clubId, String memberUid, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Member?'),
        content: Text('Are you sure you want to remove "$memberName" from the organization?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              try {
                await _authService.removeMemberFromClub(clubId, memberUid);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteClubDialog(String clubId, String clubName) {
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disband Club?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently delete "$clubName" and remove all members.'),
            const SizedBox(height: 16),
            const Text('To confirm, type the club name below:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              decoration: InputDecoration(
                hintText: clubName,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text.trim() != clubName) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Club name does not match.')),
                );
                return;
              }

              // Second Check
              bool? finalConfirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('FINAL WARNING'),
                  content: const Text('Are you absolutely sure? All data will be lost forever.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('I changed my mind')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: const Text('Yes, Disband', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (finalConfirm == true) {
                if (context.mounted) Navigator.pop(context); // Pop the disband dialog first
                try {
                  await _authService.deleteClub(clubId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Confirm Disband'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(String clubId, String clubName) {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search(String query) async {
            if (query.trim().isEmpty) return;
            setDialogState(() => isSearching = true);
            
            // 1. Search Friends first (Priority)
            final friendsSnap = await _db
                .collection('users')
                .doc(_authService.currentUser?.uid)
                .collection('friends')
                .where('username', isEqualTo: query.trim())
                .get();
            
            List<Map<String, dynamic>> combined = [];
            for (var d in friendsSnap.docs) {
              final data = d.data();
              // Check if user is in a club
              final userDoc = await _db.collection('users').doc(d.id).get();
              final userData = userDoc.data();
              bool inClub = userData?['ownedClubId'] != null || userData?['joinedClubId'] != null;
              
              if (!inClub) {
                data['isFriend'] = true;
                data['uid'] = d.id;
                combined.add(data);
              }
            }

            // 2. Search Global if no friend found
            if (combined.isEmpty) {
              final globalSnap = await _db
                  .collection('users')
                  .where('username_search', isEqualTo: query.trim().toLowerCase())
                  .limit(1)
                  .get();
              
              for (var d in globalSnap.docs) {
                if (d.id != _authService.currentUser?.uid) {
                  final data = d.data();
                  bool inClub = data['ownedClubId'] != null || data['joinedClubId'] != null;
                  
                  if (!inClub) {
                    data['isFriend'] = false;
                    data['uid'] = d.id;
                    combined.add(data);
                  }
                }
              }
            }

            setDialogState(() {
              results = combined;
              isSearching = false;
            });
          }

          return AlertDialog(
            title: const Text('Invite Member'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Enter exact username',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => search(searchController.text),
                      ),
                    ),
                    onSubmitted: search,
                  ),
                  if (isSearching) const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  if (results.isNotEmpty)
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final user = results[index];
                          final bool isFriend = user['isFriend'] ?? false;
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(user['username']),
                            subtitle: isFriend ? const Text('Friend', style: TextStyle(color: Colors.green, fontSize: 12)) : null,
                            trailing: IconButton(
                              icon: const Icon(Icons.send, color: Colors.blue),
                              onPressed: () async {
                                try {
                                  await _authService.sendClubJoinRequest(clubId, clubName, user['uid'], user['username']);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
                                    SnackBar(content: Text('Invitation sent to ${user['username']}!')),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                                }
                              },
                            ),
                          );
                        },
                      ),
                    )
                  else if (searchController.text.isNotEmpty && !isSearching)
                    const Text('No user found.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          );
        }
      ),
    );
  }
}
