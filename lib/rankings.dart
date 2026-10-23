import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurum/language_service.dart';

class RankingsPage extends StatefulWidget {
  const RankingsPage({super.key});

  @override
  State<RankingsPage> createState() => _RankingsPageState();
}

class _RankingsPageState extends State<RankingsPage> {
  String? _selectedClubId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: uid != null
          ? FirebaseFirestore.instance.collection('users').doc(uid).snapshots()
          : const Stream.empty(),
      builder: (context, userSnap) {
        final userData = userSnap.hasData ? userSnap.data!.data() as Map<String, dynamic>? ?? {} : {};
        final String? ownedClubId = userData['ownedClubId'];
        final List joinedClubIds = List.from(userData['joinedClubIds'] ?? []);
        final String? singleJoinedId = userData['joinedClubId'];

        final Set<String> userClubIds = {};
        if (ownedClubId != null && ownedClubId.isNotEmpty) userClubIds.add(ownedClubId);
        for (var id in joinedClubIds) {
          if (id != null && id.toString().isNotEmpty) userClubIds.add(id.toString());
        }
        if (singleJoinedId != null && singleJoinedId.isNotEmpty) userClubIds.add(singleJoinedId);

        if (userClubIds.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text('Club Rankings'.tr)),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'You must create or join a club to view rankings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 18),
                ),
              ),
            ),
          );
        }

        if (_selectedClubId == null || !userClubIds.contains(_selectedClubId)) {
          _selectedClubId = userClubIds.first;
        }

        return DefaultTabController(
          length: 4,
          child: Scaffold(
            appBar: AppBar(
              title: Text('Club Rankings'.tr),
              actions: [
                if (userClubIds.length > 1)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
                    builder: (context, clubsSnap) {
                      final Map<String, String> clubNames = {};
                      if (clubsSnap.hasData) {
                        for (var doc in clubsSnap.data!.docs) {
                          if (userClubIds.contains(doc.id)) {
                            final data = doc.data() as Map<String, dynamic>;
                            clubNames[doc.id] = data['name'] ?? 'Club';
                          }
                        }
                      }

                      final List<DropdownMenuItem<String>> items = userClubIds.map((cId) {
                        final String name = clubNames[cId] ?? 'Club';
                        final bool isOwner = cId == ownedClubId;
                        return DropdownMenuItem<String>(
                          value: cId,
                          child: Text('$name ${isOwner ? "(Owner)" : "(Member)"}', overflow: TextOverflow.ellipsis),
                        );
                      }).toList();

                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedClubId,
                            icon: const Icon(Icons.filter_list, color: Colors.blue),
                            items: items,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedClubId = val;
                                });
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabs: [
                  Tab(text: 'Tournament Points'.tr),
                  Tab(text: 'Elo Rating System'.tr),
                  Tab(text: 'Glicko Rating System'.tr),
                  Tab(text: 'Glicko-2 Rating System'.tr),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SportCategoryRankingsView(sportPrefix: 'points', defaultScore: 0, clubIdFilter: _selectedClubId!),
                _SportCategoryRankingsView(sportPrefix: 'elo', defaultScore: 800, clubIdFilter: _selectedClubId!),
                _SportCategoryRankingsView(sportPrefix: 'glicko1', defaultScore: 800, clubIdFilter: _selectedClubId!),
                _SportCategoryRankingsView(sportPrefix: 'glicko', defaultScore: 800, clubIdFilter: _selectedClubId!),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SportCategoryRankingsView extends StatelessWidget {
  final String sportPrefix;
  final int defaultScore;
  final String? clubIdFilter;

  const _SportCategoryRankingsView({
    required this.sportPrefix,
    required this.defaultScore,
    this.clubIdFilter,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 11,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: "Open Singles".tr),
                Tab(text: "Men's Singles".tr),
                Tab(text: "Women's Singles".tr),
                Tab(text: "Open Doubles Pairs".tr),
                Tab(text: "Men's Doubles Pairs".tr),
                Tab(text: "Women's Doubles Pairs".tr),
                Tab(text: "Mixed Doubles Pairs".tr),
                Tab(text: "Open Doubles (Indiv.)".tr),
                Tab(text: "Men's Doubles (Indiv.)".tr),
                Tab(text: "Women's Doubles (Indiv.)".tr),
                Tab(text: "Mixed Doubles (Indiv.)".tr),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RankingList(field: '${sportPrefix}_open_singles', filterGender: null, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_mens_singles', filterGender: 'Male', defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_womens_singles', filterGender: 'Female', defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _PairsRankingList(eventType: 'open_doubles', field: sportPrefix, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _PairsRankingList(eventType: 'mens_doubles', field: sportPrefix, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _PairsRankingList(eventType: 'womens_doubles', field: sportPrefix, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _PairsRankingList(eventType: 'mixed', field: sportPrefix, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_open_doubles_indiv', filterGender: null, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_mens_doubles_indiv', filterGender: 'Male', defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_womens_doubles_indiv', filterGender: 'Female', defaultVal: defaultScore, clubIdFilter: clubIdFilter),
                _RankingList(field: '${sportPrefix}_mixed_doubles_indiv', filterGender: null, defaultVal: defaultScore, clubIdFilter: clubIdFilter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String field;
  final String? filterGender;
  final int defaultVal;
  final String? clubIdFilter;

  const _RankingList({
    required this.field,
    required this.filterGender,
    required this.defaultVal,
    this.clubIdFilter,
  });

  @override
  Widget build(BuildContext context) {
    if (clubIdFilter != null) {
      return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubIdFilter)
            .collection('members')
            .snapshots(),
        builder: (context, membersSnap) {
          if (!membersSnap.hasData) return const Center(child: CircularProgressIndicator());
          final memberUids = membersSnap.data!.docs.map((d) => d.id).toSet();

          return _buildUsersList(context, memberUidsFilter: memberUids);
        },
      );
    } else {
      return _buildUsersList(context, memberUidsFilter: null);
    }
  }

  Widget _buildUsersList(BuildContext context, {Set<String>? memberUidsFilter}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No ranked players found in this category.', style: TextStyle(color: Colors.grey)));
        }

        var users = snapshot.data!.docs;

        if (memberUidsFilter != null) {
          users = users.where((doc) => memberUidsFilter.contains(doc.id)).toList();
        }

        if (filterGender != null) {
          users = users.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['gender'] == filterGender;
          }).toList();
        }

        // Sort by score descending
        users.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final scoreA = dataA[field] ?? (field.startsWith('glicko') ? (dataA['glickoRating'] ?? dataA['glicko']) : null) ?? defaultVal;
          final scoreB = dataB[field] ?? (field.startsWith('glicko') ? (dataB['glickoRating'] ?? dataB['glicko']) : null) ?? defaultVal;
          return scoreB.compareTo(scoreA);
        });

        if (users.isEmpty) {
          return const Center(child: Text('No players match this category for this club.', style: TextStyle(color: Colors.grey)));
        }

        // Calculate standard competition ranks (ties share same rank)
        List<Map<String, dynamic>> rankedUsers = [];
        int currentRank = 1;
        for (int i = 0; i < users.length; i++) {
          final data = users[i].data() as Map<String, dynamic>;
          final score = data[field] ?? (field.startsWith('glicko') ? (data['glickoRating'] ?? data['glicko']) : null) ?? defaultVal;

          if (i > 0) {
            final prevData = users[i - 1].data() as Map<String, dynamic>;
            final prevScore = prevData[field] ?? (field.startsWith('glicko') ? (prevData['glickoRating'] ?? prevData['glicko']) : null) ?? defaultVal;
            if (score != prevScore) {
              currentRank = i + 1;
            }
          } else {
            currentRank = 1;
          }

          rankedUsers.add({
            'data': data,
            'rank': currentRank,
            'score': score,
          });
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: rankedUsers.length,
          itemBuilder: (context, index) {
            final item = rankedUsers[index];
            final data = item['data'] as Map<String, dynamic>;
            final username = data['username'] ?? data['displayName'] ?? 'Player';
            final score = item['score'];
            final rank = item['rank'];
            final wins = data['wins'] ?? 0;

            Color? rankColor;
            if (rank == 1) {
              rankColor = Colors.amber;
            } else if (rank == 2) {
              rankColor = Colors.grey.shade400;
            } else if (rank == 3) {
              rankColor = Colors.brown.shade300;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rankColor ?? Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rankColor != null ? Colors.white : Colors.blue,
                    ),
                  ),
                ),
                title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  field.startsWith('glicko')
                      ? '${"Wins".tr}: $wins • RD: ±${((data["${field}_rd"] ?? data["glicko_rd"] ?? data["glicko1_rd"] ?? 350) as num).round()} • ${"Gender".tr}: ${(data['gender'] as String? ?? "Not set").tr}'
                      : '${"Wins".tr}: $wins • ${"Gender".tr}: ${(data['gender'] as String? ?? "Not set").tr}',
                ),
                trailing: Text(
                  field.startsWith('points') ? '$score ${"pts".tr}' : '$score',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PairsRankingList extends StatelessWidget {
  final String eventType;
  final String field;
  final int defaultVal;
  final String? clubIdFilter;

  const _PairsRankingList({
    required this.eventType,
    required this.field,
    required this.defaultVal,
    this.clubIdFilter,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('doubles_pairs').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No ranked pairs found in this category.', style: TextStyle(color: Colors.grey)));
        }

        var pairs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['eventType'] == eventType;
        }).toList();

        if (clubIdFilter != null) {
          pairs = pairs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data['clubId'] == clubIdFilter;
          }).toList();
        }

        // Sort by score descending
        pairs.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;
          final scoreA = dataA[field] ?? defaultVal;
          final scoreB = dataB[field] ?? defaultVal;
          return scoreB.compareTo(scoreA);
        });

        if (pairs.isEmpty) {
          return const Center(child: Text('No doubles pairs match this category.', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: pairs.length,
          itemBuilder: (context, index) {
            final data = pairs[index].data() as Map<String, dynamic>;
            final p1Name = data['p1Name'] ?? 'Player 1';
            final p2Name = data['p2Name'] ?? 'Player 2';
            final score = data[field] ?? defaultVal;
            final rank = index + 1;

            Color? rankColor;
            if (rank == 1) {
              rankColor = Colors.amber;
            } else if (rank == 2) {
              rankColor = Colors.grey.shade400;
            } else if (rank == 3) {
              rankColor = Colors.brown.shade300;
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: rankColor ?? Colors.blue.withValues(alpha: 0.1),
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: rankColor != null ? Colors.white : Colors.blue,
                    ),
                  ),
                ),
                title: Text('$p1Name & $p2Name', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Pair • ${data['clubName'] ?? "Club"}'),
                trailing: Text(
                  '$score pts',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
