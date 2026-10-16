import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RankingsPage extends StatelessWidget {
  const RankingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Club Rankings'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tournament Points'),
              Tab(text: 'Elo Rating System'),
              Tab(text: 'Glicko Rating System'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SportCategoryRankingsView(sportPrefix: 'points', defaultScore: 0),
            _SportCategoryRankingsView(sportPrefix: 'elo', defaultScore: 800),
            _SportCategoryRankingsView(sportPrefix: 'glicko', defaultScore: 800),
          ],
        ),
      ),
    );
  }
}

class _SportCategoryRankingsView extends StatelessWidget {
  final String sportPrefix;
  final int defaultScore;

  const _SportCategoryRankingsView({
    required this.sportPrefix,
    required this.defaultScore,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 9,
      child: Column(
        children: [
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: "Men's Singles"),
                Tab(text: "Women's Singles"),
                Tab(text: "Open Singles"),
                Tab(text: "Men's Doubles Pairs"),
                Tab(text: "Women's Doubles Pairs"),
                Tab(text: "Mixed Doubles Pairs"),
                Tab(text: "Men's Doubles (Indiv.)"),
                Tab(text: "Women's Doubles (Indiv.)"),
                Tab(text: "Mixed Doubles (Indiv.)"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _RankingList(field: '${sportPrefix}_mens_singles', filterGender: 'Male', defaultVal: defaultScore),
                _RankingList(field: '${sportPrefix}_womens_singles', filterGender: 'Female', defaultVal: defaultScore),
                _RankingList(field: '${sportPrefix}_open_singles', filterGender: null, defaultVal: defaultScore),
                _PairsRankingList(eventType: 'mens_doubles', field: sportPrefix, defaultVal: defaultScore),
                _PairsRankingList(eventType: 'womens_doubles', field: sportPrefix, defaultVal: defaultScore),
                _PairsRankingList(eventType: 'mixed', field: sportPrefix, defaultVal: defaultScore),
                _RankingList(field: '${sportPrefix}_mens_doubles_indiv', filterGender: 'Male', defaultVal: defaultScore),
                _RankingList(field: '${sportPrefix}_womens_doubles_indiv', filterGender: 'Female', defaultVal: defaultScore),
                _RankingList(field: '${sportPrefix}_mixed_doubles_indiv', filterGender: null, defaultVal: defaultScore),
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

  const _RankingList({
    required this.field,
    required this.filterGender,
    required this.defaultVal,
  });

  @override
  Widget build(BuildContext context) {
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
          final scoreA = dataA[field] ?? defaultVal;
          final scoreB = dataB[field] ?? defaultVal;
          return scoreB.compareTo(scoreA);
        });

        if (users.isEmpty) {
          return const Center(child: Text('No players match this category.', style: TextStyle(color: Colors.grey)));
        }

        // Calculate standard competition ranks (ties share same rank)
        List<Map<String, dynamic>> rankedUsers = [];
        int currentRank = 1;
        for (int i = 0; i < users.length; i++) {
          final data = users[i].data() as Map<String, dynamic>;
          final score = data[field] ?? defaultVal;

          if (i > 0) {
            final prevData = users[i - 1].data() as Map<String, dynamic>;
            final prevScore = prevData[field] ?? defaultVal;
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
                subtitle: Text('Wins: $wins • Gender: ${data['gender'] ?? 'Not set'}'),
                trailing: Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
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

  const _PairsRankingList({
    required this.eventType,
    required this.field,
    required this.defaultVal,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collectionGroup('doubles_requests')
          .where('eventType', isEqualTo: eventType)
          .where('status', isEqualTo: 'accepted')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No confirmed doubles pairs found.', style: TextStyle(color: Colors.grey)));
        }

        final pairs = snapshot.data!.docs;

        List<Map<String, dynamic>> rankedPairs = [];
        for (var doc in pairs) {
          final data = doc.data() as Map<String, dynamic>;
          final teamName = '${data['fromUsername']} & ${data['toUsername']}';
          final score = data[field] ?? defaultVal;
          final wins = data['wins'] ?? 0;

          rankedPairs.add({
            'teamName': teamName,
            'score': score,
            'wins': wins,
            'data': data,
          });
        }

        rankedPairs.sort((a, b) => (b['score'] as num).compareTo(a['score'] as num));

        List<Map<String, dynamic>> finalRanked = [];
        int currentRank = 1;
        for (int i = 0; i < rankedPairs.length; i++) {
          final item = rankedPairs[i];
          final score = item['score'];

          if (i > 0) {
            final prevScore = rankedPairs[i - 1]['score'];
            if (score != prevScore) {
              currentRank = i + 1;
            }
          } else {
            currentRank = 1;
          }

          final copy = Map<String, dynamic>.from(item);
          copy['rank'] = currentRank;
          finalRanked.add(copy);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: finalRanked.length,
          itemBuilder: (context, index) {
            final item = finalRanked[index];
            final teamName = item['teamName'];
            final score = item['score'];
            final wins = item['wins'];
            final rank = item['rank'];

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
                title: Text(teamName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Wins: $wins'),
                trailing: Text(
                  '$score pts',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
