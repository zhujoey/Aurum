import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/club_requests.dart';
import 'package:aurum/tournaments.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/widgets/user_avatar.dart';
import 'package:aurum/widgets/user_profile_sheet.dart';

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

class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: Text('My Clubs'.tr),
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
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) return const Center(child: CircularProgressIndicator());
          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};

          final String? ownedClubId = userData['ownedClubId'] as String?;
          final List joinedClubIds = List.from(userData['joinedClubIds'] ?? []);
          final String? singleJoinedId = userData['joinedClubId'] as String?;

          final Set<String> allUserClubIds = {};
          if (ownedClubId != null && ownedClubId.isNotEmpty) {
            allUserClubIds.add(ownedClubId);
          }
          for (var id in joinedClubIds) {
            if (id != null && id.toString().isNotEmpty) allUserClubIds.add(id.toString());
          }
          if (singleJoinedId != null && singleJoinedId.isNotEmpty) {
            allUserClubIds.add(singleJoinedId);
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (ownedClubId == null) ...[
                  Card(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(Icons.add_business, size: 36, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Establish Your Club'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Text('Create and manage your own club (1 club limit)'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            onPressed: _showCreateClubDialog,
                            child: Text('Create'.tr),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (allUserClubIds.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(
                      child: Text(
                        'You are not part of any clubs yet.\nCreate your own club above or accept a club invitation!'.tr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ),
                  ),
                ] else ...[
                  ...allUserClubIds.map((cId) {
                    return StreamBuilder<DocumentSnapshot>(
                      stream: _db.collection('clubs').doc(cId).snapshots(),
                      builder: (context, clubSnap) {
                        if (!clubSnap.hasData || !clubSnap.data!.exists) return const SizedBox.shrink();
                        final clubData = clubSnap.data!.data() as Map<String, dynamic>;
                        final bool isOwner = (clubData['ownerUid'] == uid);

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isOwner ? Colors.purple.withValues(alpha: 0.15) : Colors.green.withValues(alpha: 0.15),
                              child: Icon(Icons.groups, color: isOwner ? Colors.purple : Colors.green),
                            ),
                            title: Text(clubData['name'] ?? 'Club', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${(clubData['sport'] as String? ?? "Sport").tr} • ${(isOwner ? "Owner" : "Member").tr}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Chip(
                                  label: Text(
                                    (isOwner ? 'Owner' : 'Member').tr,
                                    style: TextStyle(
                                      color: isOwner ? Colors.purple : Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.chevron_right, color: Colors.grey),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => StreamBuilder<DocumentSnapshot>(
                                    stream: _db.collection('clubs').doc(cId).snapshots(),
                                    builder: (context, clubStreamSnap) {
                                      if (!clubStreamSnap.hasData || !clubStreamSnap.data!.exists) {
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (Navigator.canPop(context)) {
                                            Navigator.pop(context);
                                          }
                                        });
                                        return Scaffold(
                                          appBar: AppBar(title: Text('Club Details'.tr)),
                                          body: Center(child: Text('Club has been disbanded.'.tr)),
                                        );
                                      }

                                      final freshClubDoc = clubStreamSnap.data!;
                                      final freshData = freshClubDoc.data() as Map<String, dynamic>? ?? {};
                                      final bool freshIsOwner = (freshData['ownerUid'] == uid);

                                      return Scaffold(
                                        appBar: AppBar(title: Text(freshData['name'] ?? 'Club Details')),
                                        body: freshIsOwner ? _buildClubManagementView(freshClubDoc) : _buildJoinedClubView(freshClubDoc),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  }),
                ],
              ],
            ),
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
              Text('${"Owned by".tr} $ownerName', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Chip(label: Text(sport.tr)),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showLeaveClubDialog(clubDoc.id, clubName),
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: Text('Leave'.tr),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Tournaments'.tr,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 110,
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
                        width: 160,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text('${(t['sport'] as String? ?? "Sport").tr} • ${t['rankingPoints'] ?? 1000} ${"pts".tr}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
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
          child: Text(
            'Members'.tr,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _authService.getClubMembers(clubDoc.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              final members = snapshot.data!.docs;

              return ListView.builder(
                padding: EdgeInsets.only(left: 8, right: 8, bottom: MediaQuery.of(context).padding.bottom + 40),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index].data() as Map<String, dynamic>;
                  final String role = m['role'] ?? 'member';
                  final bool isOwner = role == 'owner';
                  final bool isManager = role == 'manager';

                  final String mUid = m['uid'] as String? ?? '';

                  return ListTile(
                    leading: UserAvatar(
                      photoUrl: m['photoUrl'],
                      uid: mUid,
                      username: m['username'],
                    ),
                    title: Text(m['username'] ?? 'Unknown'),
                    subtitle: Text((isOwner ? 'Owner' : (isManager ? 'Manager' : 'Member')).tr),
                    onTap: () {
                      if (mUid.isNotEmpty) {
                        showUserProfileSheet(
                          context,
                          uid: mUid,
                          username: m['username'],
                          photoUrl: m['photoUrl'],
                        );
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
                    label: Text(sport.tr),
                    avatar: const Icon(Icons.sports, size: 16),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _showDeleteClubDialog(clubDoc.id, clubName),
                    icon: const Icon(Icons.delete_forever, size: 16),
                    label: Text('Disband'.tr),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            'Tournaments'.tr,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 110,
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
                        width: 160,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            Text('${(t['sport'] as String? ?? "Sport").tr} • ${t['rankingPoints'] ?? 1000} ${"pts".tr}', style: const TextStyle(color: Colors.blue, fontSize: 11)),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Members'.tr,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showAddRealMemberDialog(clubDoc.id),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add_alt_1, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Register Member'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showAddMemberDialog(clubDoc.id, clubName),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person_add, size: 16),
                          const SizedBox(width: 4),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Invite'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
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
                padding: EdgeInsets.only(left: 8, right: 8, bottom: MediaQuery.of(context).padding.bottom + 40),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final m = members[index].data() as Map<String, dynamic>;
                  final String role = m['role'] ?? 'member';
                  final bool isOwner = role == 'owner';
                  final bool isManager = role == 'manager';

                  final String mUid = m['uid'] as String? ?? '';
                  final bool isRegisteredMember = mUid.startsWith('member_');

                  return ListTile(
                    leading: UserAvatar(
                      photoUrl: m['photoUrl'],
                      uid: mUid,
                      username: m['username'],
                    ),
                    title: Text(m['username'] ?? 'Unknown'),
                    subtitle: Text((isOwner ? 'Owner' : (isManager ? 'Manager' : 'Member')).tr),
                    onTap: () {
                      if (mUid.isNotEmpty && !isRegisteredMember) {
                        showUserProfileSheet(
                          context,
                          uid: mUid,
                          username: m['username'],
                          photoUrl: m['photoUrl'],
                        );
                      }
                    },
                    trailing: isOwner
                        ? null
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isRegisteredMember)
                                PopupMenuButton<String>(
                                  onSelected: (val) async {
                                    try {
                                      if (val == 'promote') {
                                        await _authService.updateMemberRole(clubId: clubDoc.id, memberUid: mUid, newRole: 'manager');
                                        if (context.mounted) {
                                          _showAppSnackBar(context, SnackBar(content: Text('Promoted to Manager!'.tr)));
                                        }
                                      } else if (val == 'demote') {
                                        await _authService.updateMemberRole(clubId: clubDoc.id, memberUid: mUid, newRole: 'member');
                                        if (context.mounted) {
                                          _showAppSnackBar(context, SnackBar(content: Text('Demoted to Member'.tr)));
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        _showAppSnackBar(context, SnackBar(content: Text('$e')));
                                      }
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: isManager ? 'demote' : 'promote',
                                      child: Text((isManager ? 'Demote to Member' : 'Promote to Manager').tr),
                                    ),
                                  ],
                                ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () => _showKickMemberDialog(clubDoc.id, mUid, m['username'] ?? 'Unknown'),
                                tooltip: 'Remove from Club'.tr,
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
          title: Text('Establish Organization'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Club Name'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedSport,
                decoration: InputDecoration(
                  labelText: 'Sport'.tr,
                  border: const OutlineInputBorder(),
                ),
                items: sports.map((s) => DropdownMenuItem(value: s, child: Text(s.tr))).toList(),
                onChanged: (val) => setDialogState(() => selectedSport = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                try {
                  await _authService.createClub(name, selectedSport);
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    _showAppSnackBar(context, SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text('Establish'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddRealMemberDialog(String clubId) {
    final nameController = TextEditingController();
    String selectedGender = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Register Member Directly'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Member Name'.tr,
                  hintText: 'e.g. John Smith'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select Gender:'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.male, size: 18, color: selectedGender == 'Male' ? Colors.white : Colors.blue),
                      label: Text('Male'.tr),
                      selected: selectedGender == 'Male',
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: selectedGender == 'Male' ? Colors.white : null, fontWeight: FontWeight.bold),
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedGender = 'Male');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.female, size: 18, color: selectedGender == 'Female' ? Colors.white : Colors.pink),
                      label: Text('Female'.tr),
                      selected: selectedGender == 'Female',
                      selectedColor: Colors.pink,
                      labelStyle: TextStyle(color: selectedGender == 'Female' ? Colors.white : null, fontWeight: FontWeight.bold),
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedGender = 'Female');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  _showAppSnackBar(context, SnackBar(content: Text('Please enter member name.'.tr)));
                  return;
                }
                if (selectedGender.isEmpty) {
                  _showAppSnackBar(context, SnackBar(content: Text('Please select a gender (Male or Female).'.tr)));
                  return;
                }
                try {
                  await _authService.addRealMemberToClub(
                    clubId: clubId,
                    name: name,
                    gender: selectedGender,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showAppSnackBar(context, SnackBar(content: Text('$name ${"registered as a member!".tr}')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showAppSnackBar(context, SnackBar(content: Text('$e')));
                  }
                }
              },
              child: Text('Register'.tr),
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
        title: Text('Leave Club?'.tr),
        content: Text('${"Are you sure you want to leave".tr} "$clubName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Pop dialog first
              try {
                await _authService.leaveClub(clubId);
                if (context.mounted) {
                  Navigator.pop(context); // Pop club details page
                }
              } catch (e) {
                if (context.mounted) {
                  _showAppSnackBar(context, SnackBar(content: Text('$e')));
                }
              }
            },
            child: Text('Leave'.tr, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showKickMemberDialog(String clubId, String memberUid, String memberName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Member?'.tr),
        content: Text('${"Are you sure you want to remove".tr} "$memberName" ${"from the organization?".tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () async {
              try {
                await _authService.removeMemberFromClub(clubId, memberUid);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  _showAppSnackBar(context, SnackBar(content: Text('$e')));
                }
              }
            },
            child: Text('Remove'.tr, style: const TextStyle(color: Colors.red)),
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
        title: Text('Disband Club?'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${"This will permanently delete".tr} "$clubName" ${"and remove all members.".tr}'),
            const SizedBox(height: 16),
            Text('To confirm, type the club name below:'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          ElevatedButton(
            onPressed: () async {
              if (confirmController.text.trim() != clubName) {
                _showAppSnackBar(context, 
                  SnackBar(content: Text('Club name does not match.'.tr)),
                );
                return;
              }

              // Second Check
              bool? finalConfirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('FINAL WARNING'.tr),
                  content: Text('Are you absolutely sure? All data will be lost forever.'.tr),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text('I changed my mind'.tr)),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true), 
                      child: Text('Yes, Disband'.tr, style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (finalConfirm == true) {
                if (context.mounted) Navigator.pop(context); // Pop the disband dialog first
                try {
                  await _authService.deleteClub(clubId);
                  if (context.mounted) {
                    Navigator.pop(context); // Pop the club details page
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showAppSnackBar(context, SnackBar(content: Text('$e')));
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text('Confirm Disband'.tr),
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
              data['isFriend'] = true;
              data['uid'] = d.id;
              combined.add(data);
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
                  data['isFriend'] = false;
                  data['uid'] = d.id;
                  combined.add(data);
                }
              }
            }

            setDialogState(() {
              results = combined;
              isSearching = false;
            });
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Text('Invite Member'.tr),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              height: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Username'.tr,
                      hintText: 'Enter exact username'.tr,
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () => search(searchController.text),
                      ),
                    ),
                    onSubmitted: (query) => search(query),
                  ),
                  const SizedBox(height: 16),
                  if (isSearching)
                    const Center(child: CircularProgressIndicator())
                  else if (results.isEmpty)
                    Center(child: Text('Search by exact username above.'.tr))
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final item = results[index];
                          final targetUid = item['uid'];
                          final targetUsername = item['username'] ?? 'User';
                          final isFriend = item['isFriend'] ?? false;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            leading: UserAvatar(
                              photoUrl: item['photoUrl'],
                              uid: targetUid,
                              username: targetUsername,
                            ),
                            title: Text(
                              targetUsername,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(isFriend ? 'Friend'.tr : 'User'.tr),
                            onTap: () {
                              if (targetUid != null) {
                                showUserProfileSheet(
                                  context,
                                  uid: targetUid,
                                  username: targetUsername,
                                  photoUrl: item['photoUrl'],
                                );
                              }
                            },
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                try {
                                  await _authService.sendClubJoinRequest(
                                    clubId,
                                    clubName,
                                    targetUid,
                                    targetUsername,
                                  );
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    _showAppSnackBar(context, 
                                      SnackBar(content: Text('${"Invitation sent to".tr} $targetUsername!')),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    _showAppSnackBar(context, SnackBar(content: Text('$e')));
                                  }
                                }
                              },
                              child: Text('Invite'.tr),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'.tr),
              ),
            ],
          );
        },
      ),
    );
  }
}
