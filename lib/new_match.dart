import 'package:flutter/material.dart';
import 'package:sportsaccesories/auth_service.dart';

class NewMatch extends StatelessWidget {
  const NewMatch({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Sport'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSportCard(
            context,
            'Table Tennis',
            Icons.sports_tennis,
            Colors.blue,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TableTennisSetup()),
              );
            },
          ),
          _buildSportCard(
            context,
            'Tennis (Coming Soon)',
            Icons.sports_tennis_outlined,
            Colors.grey,
            null,
          ),
          _buildSportCard(
            context,
            'Badminton (Coming Soon)',
            Icons.sports,
            Colors.grey,
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildSportCard(BuildContext context, String title, IconData icon, Color color, VoidCallback? onTap) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(icon, size: 40, color: color),
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        enabled: onTap != null,
      ),
    );
  }
}

class TableTennisSetup extends StatefulWidget {
  const TableTennisSetup({super.key});

  @override
  State<TableTennisSetup> createState() => _TableTennisSetupState();
}

class _TableTennisSetupState extends State<TableTennisSetup> {
  String player1Name = '';
  String player2Name = '';
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    // Default Player 1 to the current logged in user
    player1Name = _authService.currentUser?.displayName ?? 'Player 1';
    player2Name = 'Player 2';
  }

  void _selectPlayer(int playerNum) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Player $playerNum',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Use My Account'),
              onTap: () {
                setState(() {
                  if (playerNum == 1) {
                    player1Name = _authService.currentUser?.displayName ?? 'Me';
                  } else {
                    player2Name = _authService.currentUser?.displayName ?? 'Me';
                  }
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: const Text('Other Account (Search)'),
              subtitle: const Text('Feature coming soon with Firestore'),
              onTap: () {
                // Placeholder for searching other users
                Navigator.pop(context);
              },
            ),
            const Divider(),
            const Text('Play as Guest', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Enter guest name (leave empty for "Guest")',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) {
                setState(() {
                  String name = value.trim().isEmpty ? 'Guest' : value.trim();
                  if (playerNum == 1) {
                    player1Name = name;
                  } else {
                    player2Name = name;
                  }
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text(
              'Who is playing?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _buildPlayerSelector(1, player1Name),
            const SizedBox(height: 20),
            const Text('VS', style: TextStyle(fontSize: 20, color: Colors.grey)),
            const SizedBox(height: 20),
            _buildPlayerSelector(2, player2Name),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TableTennisMatch(
                      p1Name: player1Name,
                      p2Name: player2Name,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Start Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerSelector(int num, String name) {
    return InkWell(
      onTap: () => _selectPlayer(num),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
          color: Colors.blue.withValues(alpha: 0.05),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text('$num', style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Player $num', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Icon(Icons.edit, color: Colors.blue),
          ],
        ),
      ),
    );
  }
}

class TableTennisMatch extends StatefulWidget {
  final String p1Name;
  final String p2Name;

  const TableTennisMatch({super.key, required this.p1Name, required this.p2Name});

  @override
  State<TableTennisMatch> createState() => _TableTennisMatchState();
}

class MatchState {
  final int p1Score;
  final int p2Score;
  final int p1Sets;
  final int p2Sets;

  MatchState({required this.p1Score, required this.p2Score, required this.p1Sets, required this.p2Sets});
}

class _TableTennisMatchState extends State<TableTennisMatch> {
  int player1Score = 0;
  int player2Score = 0;
  int player1Sets = 0;
  int player2Sets = 0;
  
  final List<MatchState> _history = [];

  void _saveState() {
    _history.add(MatchState(
      p1Score: player1Score,
      p2Score: player2Score,
      p1Sets: player1Sets,
      p2Sets: player2Sets,
    ));
    // Keep history reasonable
    if (_history.length > 50) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        final lastState = _history.removeLast();
        player1Score = lastState.p1Score;
        player2Score = lastState.p2Score;
        player1Sets = lastState.p1Sets;
        player2Sets = lastState.p2Sets;
      });
    }
  }

  void _resetMatch() {
    _saveState();
    setState(() {
      player1Score = 0;
      player2Score = 0;
      player1Sets = 0;
      player2Sets = 0;
    });
  }

  void _updateScore(int player, int delta) {
    _saveState();
    setState(() {
      if (player == 1) {
        player1Score = (player1Score + delta).clamp(0, 99);
      } else {
        player2Score = (player2Score + delta).clamp(0, 99);
      }
      if (delta > 0) _checkSetWinner();
    });
  }

  void _updateSets(int player, int delta) {
    _saveState();
    setState(() {
      if (player == 1) {
        player1Sets = (player1Sets + delta).clamp(0, 9);
      } else {
        player2Sets = (player2Sets + delta).clamp(0, 9);
      }
    });
  }

  void _checkSetWinner() {
    if ((player1Score >= 11 || player2Score >= 11) && (player1Score - player2Score).abs() >= 2) {
      if (player1Score > player2Score) {
        player1Sets++;
      } else {
        player2Sets++;
      }
      player1Score = 0;
      player2Score = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Tennis Match'),
        actions: [
          IconButton(
            onPressed: _history.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last action',
          ),
          IconButton(
            onPressed: _resetMatch, 
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset match',
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPlayerColumn(widget.p1Name, player1Score, player1Sets, 1),
              _buildPlayerColumn(widget.p2Name, player2Score, player2Sets, 2),
            ],
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Match finished!')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Finish Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildPlayerColumn(String name, int score, int sets, int playerNum) {
    return Column(
      children: [
        SizedBox(
          width: 150,
          child: Text(
            name, 
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 15),
        // Sets control
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _updateSets(playerNum, -1),
              icon: const Icon(Icons.remove_circle_outline, size: 24),
              color: Colors.red[300],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Sets: $sets', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
            IconButton(
              onPressed: () => _updateSets(playerNum, 1),
              icon: const Icon(Icons.add_circle_outline, size: 24),
              color: Colors.blue,
            ),
          ],
        ),
        const SizedBox(height: 25),
        // Score control
        Column(
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.withValues(alpha: 0.5), width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$score',
                  style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _updateScore(playerNum, -1),
                  icon: const Icon(Icons.remove_circle, size: 36),
                  color: Colors.red[400],
                ),
                const SizedBox(width: 20),
                IconButton(
                  onPressed: () => _updateScore(playerNum, 1),
                  icon: const Icon(Icons.add_circle, size: 36),
                  color: Colors.green[400],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 15),
        const Text('Use buttons to adjust', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
