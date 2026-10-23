import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tt_scoreboard.dart';

class ITTFTeamMatchPage extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final String teamMatchId;
  final String team1Name;
  final String team2Name;
  final List<Map<String, dynamic>> team1Roster;
  final List<Map<String, dynamic>> team2Roster;
  final bool isOwnerOrManager;

  const ITTFTeamMatchPage({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.teamMatchId,
    required this.team1Name,
    required this.team2Name,
    required this.team1Roster,
    required this.team2Roster,
    required this.isOwnerOrManager,
  });

  @override
  State<ITTFTeamMatchPage> createState() => _ITTFTeamMatchPageState();
}

class _ITTFTeamMatchPageState extends State<ITTFTeamMatchPage> {
  String _selectedSystem = 'Olympic System (1 Doubles + 4 Singles)';

  // Designation for Team 1 (A, B, C) and Team 2 (X, Y, Z)
  Map<String, dynamic>? _t1PlayerA;
  Map<String, dynamic>? _t1PlayerB;
  Map<String, dynamic>? _t1PlayerC;

  Map<String, dynamic>? _t2PlayerX;
  Map<String, dynamic>? _t2PlayerY;
  Map<String, dynamic>? _t2PlayerZ;

  bool _isDesignationSubmitted = false;

  @override
  void initState() {
    super.initState();
    _loadExistingDesignations();
  }

  void _loadExistingDesignations() async {
    final doc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('team_matches')
        .doc(widget.teamMatchId)
        .get();

    if (doc.exists && mounted) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isDesignationSubmitted'] == true) {
        setState(() {
          _isDesignationSubmitted = true;
          _selectedSystem = data['selectedSystem'] ?? _selectedSystem;
          _t1PlayerA = data['t1PlayerA'];
          _t1PlayerB = data['t1PlayerB'];
          _t1PlayerC = data['t1PlayerC'];
          _t2PlayerX = data['t2PlayerX'];
          _t2PlayerY = data['t2PlayerY'];
          _t2PlayerZ = data['t2PlayerZ'];
        });
      }
    }
  }

  void _submitDesignations() async {
    if (_t1PlayerA == null || _t1PlayerB == null ||
        _t2PlayerX == null || _t2PlayerY == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please designate players for both team captains.')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('team_matches')
        .doc(widget.teamMatchId);

    List<Map<String, dynamic>> subMatches = [];

    if (_selectedSystem.startsWith('Olympic')) {
      // Olympic System (5 Matches: 1 Doubles + 4 Singles)
      subMatches = [
        {'matchNum': 1, 'type': 'Doubles', 'p1Name': '${_t1PlayerB!['username']} & ${_t1PlayerC?['username'] ?? _t1PlayerA!['username']}', 'p2Name': '${_t2PlayerY!['username']} & ${_t2PlayerZ?['username'] ?? _t2PlayerX!['username']}', 'winner': null, 'score': null},
        {'matchNum': 2, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
        {'matchNum': 3, 'type': 'Singles', 'p1Name': _t1PlayerC?['username'] ?? _t1PlayerB!['username'], 'p2Name': _t2PlayerZ?['username'] ?? _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 4, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 5, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
      ];
    } else if (_selectedSystem.startsWith('Swaythling')) {
      // Swaythling Cup System (5 Singles)
      subMatches = [
        {'matchNum': 1, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
        {'matchNum': 2, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 3, 'type': 'Singles', 'p1Name': _t1PlayerC?['username'] ?? _t1PlayerA!['username'], 'p2Name': _t2PlayerZ?['username'] ?? _t2PlayerX!['username'], 'winner': null, 'score': null},
        {'matchNum': 4, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 5, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
      ];
    } else if (_selectedSystem.startsWith('Corbillon')) {
      // Corbillon Cup System (4 Singles + 1 Doubles)
      subMatches = [
        {'matchNum': 1, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
        {'matchNum': 2, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 3, 'type': 'Doubles', 'p1Name': '${_t1PlayerA!['username']} & ${_t1PlayerB!['username']}', 'p2Name': '${_t2PlayerX!['username']} & ${_t2PlayerY!['username']}', 'winner': null, 'score': null},
        {'matchNum': 4, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 5, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
      ];
    } else {
      // 3-Match Club System (2 Singles + 1 Doubles)
      subMatches = [
        {'matchNum': 1, 'type': 'Singles', 'p1Name': _t1PlayerA!['username'], 'p2Name': _t2PlayerX!['username'], 'winner': null, 'score': null},
        {'matchNum': 2, 'type': 'Singles', 'p1Name': _t1PlayerB!['username'], 'p2Name': _t2PlayerY!['username'], 'winner': null, 'score': null},
        {'matchNum': 3, 'type': 'Doubles', 'p1Name': '${_t1PlayerA!['username']} & ${_t1PlayerB!['username']}', 'p2Name': '${_t2PlayerX!['username']} & ${_t2PlayerY!['username']}', 'winner': null, 'score': null},
      ];
    }

    await docRef.set({
      'team1Name': widget.team1Name,
      'team2Name': widget.team2Name,
      'isDesignationSubmitted': true,
      'selectedSystem': _selectedSystem,
      't1PlayerA': _t1PlayerA,
      't1PlayerB': _t1PlayerB,
      't1PlayerC': _t1PlayerC,
      't2PlayerX': _t2PlayerX,
      't2PlayerY': _t2PlayerY,
      't2PlayerZ': _t2PlayerZ,
      'team1Wins': 0,
      'team2Wins': 0,
      'isCompleted': false,
      'subMatches': subMatches,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    setState(() {
      _isDesignationSubmitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.team1Name} vs ${widget.team2Name}'),
      ),
      body: _isDesignationSubmitted
          ? _buildTeamMatchDashboard()
          : _buildPlayerDesignationScreen(),
    );
  }

  Widget _buildPlayerDesignationScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.blue.withValues(alpha: 0.1),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ITTF Team Captain Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 6),
                  Text(
                    'Select the ITTF Team System and nominate players A, B, C for Team 1 and X, Y, Z for Team 2.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedSystem,
            decoration: const InputDecoration(
              labelText: 'ITTF Team System Format',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'Olympic System (1 Doubles + 4 Singles)', child: Text('Olympic System (1 Doubles + 4 Singles)', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Swaythling Cup System (5 Singles)', child: Text('Swaythling Cup (5 Singles)', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: 'Corbillon Cup System (4 Singles + 1 Doubles)', child: Text('Corbillon Cup (4 Singles + 1 Doubles)', overflow: TextOverflow.ellipsis)),
              DropdownMenuItem(value: '3-Match Club System (2 Singles + 1 Doubles)', child: Text('3-Match Club System (2 Singles + 1 Doubles)', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedSystem = val);
            },
          ),
          const SizedBox(height: 20),
          Text('${widget.team1Name} Captain Designation (A, B, C)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position A (Lead Singles)', widget.team1Roster, _t1PlayerA, (val) => setState(() => _t1PlayerA = val)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position B (Singles/Doubles)', widget.team1Roster, _t1PlayerB, (val) => setState(() => _t1PlayerB = val)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position C (Singles/Doubles)', widget.team1Roster, _t1PlayerC, (val) => setState(() => _t1PlayerC = val)),

          const SizedBox(height: 24),
          Text('${widget.team2Name} Captain Designation (X, Y, Z)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position X (Lead Singles)', widget.team2Roster, _t2PlayerX, (val) => setState(() => _t2PlayerX = val)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position Y (Singles/Doubles)', widget.team2Roster, _t2PlayerY, (val) => setState(() => _t2PlayerY = val)),
          const SizedBox(height: 8),
          _buildPlayerDropdown('Position Z (Singles/Doubles)', widget.team2Roster, _t2PlayerZ, (val) => setState(() => _t2PlayerZ = val)),

          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm Designation & Start Team Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _submitDesignations,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerDropdown(
    String label,
    List<Map<String, dynamic>> roster,
    Map<String, dynamic>? selected,
    ValueChanged<Map<String, dynamic>?> onChanged,
  ) {
    return DropdownButtonFormField<Map<String, dynamic>>(
      isExpanded: true,
      initialValue: selected,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: roster.map((player) {
        return DropdownMenuItem<Map<String, dynamic>>(
          value: player,
          child: Text(player['username'] ?? 'Player'),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildTeamMatchDashboard() {
    final docRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('team_matches')
        .doc(widget.teamMatchId);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final int t1Wins = data['team1Wins'] ?? 0;
        final int t2Wins = data['team2Wins'] ?? 0;
        final bool isCompleted = data['isCompleted'] ?? false;
        final List subMatches = List.from(data['subMatches'] ?? []);
        final String systemName = data['selectedSystem'] ?? 'ITTF Team Match';

        final int targetWins = systemName.startsWith('3-Match') ? 2 : 3;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(systemName.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                Text(widget.team1Name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                Text('$t1Wins', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: t1Wins >= targetWins ? Colors.green : Colors.blue)),
                              ],
                            ),
                          ),
                          const Text('VS', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey)),
                          Expanded(
                            child: Column(
                              children: [
                                Text(widget.team2Name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), textAlign: TextAlign.center),
                                const SizedBox(height: 8),
                                Text('$t2Wins', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: t2Wins >= targetWins ? Colors.green : Colors.blue)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isCompleted) ...[
                        const SizedBox(height: 12),
                        Chip(
                          avatar: const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                          label: Text(
                            'WINNER: ${t1Wins >= targetWins ? widget.team1Name : widget.team2Name}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('ITTF Order of Play', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              ...subMatches.map((m) {
                final int matchNum = m['matchNum'];
                final String type = m['type'];
                final String p1 = m['p1Name'];
                final String p2 = m['p2Name'];
                final String? winner = m['winner'];
                final String? score = m['score'];

                final bool matchDone = winner != null;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: matchDone ? Colors.green.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                      child: Text('M$matchNum', style: TextStyle(fontWeight: FontWeight.bold, color: matchDone ? Colors.green : Colors.blue)),
                    ),
                    title: Text('$p1 vs $p2', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    subtitle: Text('Format: $type ${score != null ? "• Score: $score" : ""}'),
                    trailing: matchDone
                        ? Chip(label: Text('$winner ✓', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11)))
                        : ElevatedButton.icon(
                            icon: const Icon(Icons.sports_tennis, size: 14),
                            label: const Text('Play Live'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TableTennisMatch(
                                    p1Name: p1,
                                    p2Name: p2,
                                    p3Name: '',
                                    p4Name: '',
                                    isDoubles: type == 'Doubles',
                                    setsToWin: 3,
                                    matchId: 'team_${widget.teamMatchId}_m$matchNum',
                                    isHost: true,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
