import 'package:flutter/material.dart';
import 'package:sportspro/auth_service.dart';
import 'tennis_scoreboard.dart';

class TennisSetup extends StatefulWidget {
  const TennisSetup({super.key});

  @override
  State<TennisSetup> createState() => _TennisSetupState();
}

class _TennisSetupState extends State<TennisSetup> {
  final _authService = AuthService();
  final _p1Controller = TextEditingController();
  final _p2Controller = TextEditingController();
  int _setsToWin = 2; // Best of 3 by default

  @override
  void initState() {
    super.initState();
    _p1Controller.text = _authService.currentUser?.displayName ?? 'Player 1';
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    super.dispose();
  }

  void _startLocalMatch() {
    final p1 = _p1Controller.text.trim();
    final p2 = _p2Controller.text.trim();
    if (p1.isEmpty || p2.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TennisMatch(
          p1Name: p1,
          p2Name: p2,
          setsToWin: _setsToWin,
          isHost: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ITF Tennis Quick Match'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ITF Tennis Official Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('Includes 0/15/30/40/AD scoring, deuce rules, 6-6 tie-breaks, 90s changeover rest, and 5-min warmup.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _p1Controller,
              decoration: const InputDecoration(
                labelText: 'Player 1 Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _p2Controller,
              decoration: const InputDecoration(
                labelText: 'Player 2 Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Match Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Best of 3 Sets (First to 2)'),
                    selected: _setsToWin == 2,
                    onSelected: (val) {
                      if (val) setState(() => _setsToWin = 2);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Best of 5 Sets (First to 3)'),
                    selected: _setsToWin == 3,
                    onSelected: (val) {
                      if (val) setState(() => _setsToWin = 3);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Tennis Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _startLocalMatch,
            ),
          ],
        ),
      ),
    );
  }
}
