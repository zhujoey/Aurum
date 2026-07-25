import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportsaccesories/auth_service.dart';
import 'tt_models.dart';
import 'tt_scoreboard.dart';

class TableTennisSetup extends StatefulWidget {
  const TableTennisSetup({super.key});

  @override
  State<TableTennisSetup> createState() => _TableTennisSetupState();
}

class _TableTennisSetupState extends State<TableTennisSetup> {
  final TextEditingController _p1Controller = TextEditingController();
  final TextEditingController _p2Controller = TextEditingController();
  final TextEditingController _p3Controller = TextEditingController();
  final TextEditingController _p4Controller = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isDoubles = false;
  int _setsToWin = 4;
  Map<String, dynamic>? _savedMatch;

  // Track if players are guests or invited users
  // index 0: P2, index 1: P3, index 2: P4
  final List<bool> _isInviteMode = [false, false, false];

  @override
  void initState() {
    super.initState();
    _p1Controller.text = _authService.currentUser?.displayName ?? 'Me';
    _p2Controller.text = 'Guest';
    _p3Controller.text = 'Guest';
    _p4Controller.text = 'Guest';
    _checkSavedMatch();
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _p3Controller.dispose();
    _p4Controller.dispose();
    super.dispose();
  }

  Future<void> _checkSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_tt_match');
    if (data != null) {
      setState(() {
        _savedMatch = jsonDecode(data);
      });
    }
  }

  Future<void> _clearSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_tt_match');
    setState(() {
      _savedMatch = null;
    });
  }

  void _resumeMatch() async {
    if (_savedMatch != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TableTennisMatch(
            p1Name: _savedMatch!['p1Name'] ?? 'P1',
            p2Name: _savedMatch!['p2Name'] ?? '',
            p3Name: _savedMatch!['p3Name'] ?? _savedMatch!['p2Name'] ?? 'P2',
            p4Name: _savedMatch!['p4Name'] ?? '',
            isDoubles: _savedMatch!['isDoubles'] ?? false,
            setsToWin: _savedMatch!['setsToWin'] ?? 4,
            initialP1Score: _savedMatch!['p1Score'] ?? 0,
            initialP2Score: _savedMatch!['p2Score'] ?? 0,
            initialP1Sets: _savedMatch!['p1Sets'] ?? 0,
            initialP2Sets: _savedMatch!['p2Sets'] ?? 0,
            initialIsSetOver: _savedMatch!['isSetOver'] ?? false,
            initialPointHistory: List<int>.from(_savedMatch!['pointHistory'] ?? []),
            initialSetSummaries: (_savedMatch!['setSummaries'] as List? ?? [])
                .map((s) => SetSummary.fromMap(s))
                .toList(),
            initialP1TimeoutUsed: _savedMatch!['p1TimeoutUsed'] ?? false,
            initialP2TimeoutUsed: _savedMatch!['p2TimeoutUsed'] ?? false,
            initialFirstServer: _savedMatch!['firstServer'] ?? 1,
            initialP1OnLeft: _savedMatch!['p1OnLeft'] ?? true,
            initialLogs: (_savedMatch!['logs'] as List? ?? [])
                .map((p) => MatchLogEntry.fromMap(p))
                .toList(),
            initialExpediteActive: _savedMatch!['expediteActive'] ?? false,
            initialGameTimeSeconds: _savedMatch!['gameTimeSeconds'] ?? 0,
            activeTimerSeconds: _savedMatch!['activeTimerSeconds'] ?? 0,
            activeTimerTitle: _savedMatch!['activeTimerTitle'] ?? '',
          ),
        ),
      );
      _checkSavedMatch();
    }
  }

  void _showCustomSetsDialog() {
    final controller = TextEditingController(text: _setsToWin.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Sets to Win'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Enter number of sets'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _setsToWin = val);
              }
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartMatch() async {
    String n1 = _p1Controller.text.trim(); if (n1.isEmpty) n1 = 'P1';
    String n2 = _p2Controller.text.trim(); if (n2.isEmpty) n2 = _isDoubles ? 'Partner' : '';
    String n3 = _p3Controller.text.trim(); if (n3.isEmpty) n3 = 'Opponent 1';
    String n4 = _p4Controller.text.trim(); if (n4.isEmpty) n4 = _isDoubles ? 'Opponent 2' : '';

    // Invitation logic
    List<String> namesToInvite = [];
    if (!_isDoubles) {
      if (_isInviteMode[1]) namesToInvite.add(n3);
    } else {
      if (_isInviteMode[0]) namesToInvite.add(n2);
      if (_isInviteMode[1]) namesToInvite.add(n3);
      if (_isInviteMode[2]) namesToInvite.add(n4);
    }

    String currentUsername = _authService.currentUser?.displayName ?? '';
    
    for (String name in namesToInvite) {
      if (name != currentUsername && name.isNotEmpty) {
        final user = await _authService.findUserByUsername(name);
        if (user != null) {
          await _authService.sendMatchRequest(
            targetUid: user['uid'],
            sport: 'Table Tennis',
            setsToWin: _setsToWin,
          );
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent to $name')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User $name not found! Playing as Guest.')));
        }
      }
    }

    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableTennisMatch(
          p1Name: n1, p2Name: n2, p3Name: n3, p4Name: n4,
          isDoubles: _isDoubles, setsToWin: _setsToWin,
        ),
      ),
    );
    _checkSavedMatch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Table Tennis Setup')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_savedMatch != null) ...[
                _buildActiveMatchCard(),
                const SizedBox(height: 20),
                const Divider(),
              ],
              const Text('Game Type', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _typeButton('Singles', false),
                  const SizedBox(width: 12),
                  _typeButton('Doubles', true),
                ],
              ),
              const Divider(height: 40),
              const Text('Match Format', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _formatButton('First to 4 sets', 4), const SizedBox(width: 8),
                _formatButton('First to 3 sets', 3), const SizedBox(width: 8),
                _customFormatButton(),
              ])),
              const Divider(height: 40),
              const Text('Players', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              if (!_isDoubles) ...[
                _buildPlayerField(_p1Controller, 'Player 1 Name', Icons.person),
                const SizedBox(height: 20),
                _buildDynamicPlayerSection(1, _p3Controller, 'Player 2', Icons.person_outline),
              ] else ...[
                const Text('TEAM 1', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                _buildPlayerField(_p1Controller, 'Player 1 Name', Icons.person),
                const SizedBox(height: 20),
                _buildDynamicPlayerSection(0, _p2Controller, 'Player 2', Icons.person),
                const Divider(height: 40),
                const Text('TEAM 2', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 8),
                _buildDynamicPlayerSection(1, _p3Controller, 'Player 3', Icons.person_outline),
                const SizedBox(height: 20),
                _buildDynamicPlayerSection(2, _p4Controller, 'Player 4', Icons.person_outline),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _handleStartMatch,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text('Start Match', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveMatchCard() {
    final bool savedIsDoubles = _savedMatch!['isDoubles'] ?? false;
    String p1Part = _savedMatch!['p1Name'] ?? 'P1';
    if (savedIsDoubles) p1Part += " & ${_savedMatch!['p2Name'] ?? 'P2'}";
    
    String p2Part = _savedMatch!['p3Name'] ?? _savedMatch!['p2Name'] ?? 'P2';
    if (savedIsDoubles) p2Part += " & ${_savedMatch!['p4Name'] ?? 'P4'}";

    return Card(
      color: Colors.blue.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text('Match in Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Text('$p1Part vs $p2Part', 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_savedMatch!['p1Sets']}', style: const TextStyle(color: Colors.blue, fontSize: 24, fontWeight: FontWeight.bold)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.0),
                  child: Text('-', style: TextStyle(fontSize: 24, color: Colors.grey)),
                ),
                Text('${_savedMatch!['p2Sets']}', style: const TextStyle(color: Colors.blue, fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            Text('Current: (${_savedMatch!['p1Score']} - ${_savedMatch!['p2Score']})', style: const TextStyle(color: Colors.grey, fontSize: 14)),
            
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton.icon(
                onPressed: _clearSavedMatch, 
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Discard', style: TextStyle(color: Colors.red))
              ),
              ElevatedButton.icon(
                onPressed: _resumeMatch, 
                icon: const Icon(Icons.play_arrow),
                label: const Text('Resume Match'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              ),
            ])
          ],
        ),
      ),
    );
  }

  Widget _typeButton(String label, bool value) {
    bool isSelected = _isDoubles == value;
    return ElevatedButton(
      onPressed: () => setState(() => _isDoubles = value),
      style: ElevatedButton.styleFrom(backgroundColor: isSelected ? Colors.blue : Colors.grey[800], foregroundColor: Colors.white),
      child: Text(label),
    );
  }

  Widget _buildDynamicPlayerSection(int index, TextEditingController controller, String label, IconData icon) {
    bool isInvite = _isInviteMode[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ToggleButtons(
              isSelected: [!isInvite, isInvite],
              onPressed: (i) {
                setState(() {
                  _isInviteMode[index] = i == 1;
                  if (i == 0) {
                    controller.text = 'Guest';
                  } else {
                    controller.clear();
                  }
                });
              },
              constraints: const BoxConstraints(minHeight: 30, minWidth: 60),
              borderRadius: BorderRadius.circular(8),
              children: const [
                Text('Guest', style: TextStyle(fontSize: 12)),
                Text('Invite', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: isInvite ? 'Username to Invite' : 'Temporary Guest Name',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(icon),
            hintText: isInvite ? 'Enter exact username' : 'e.g. Guest',
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label, 
        border: const OutlineInputBorder(), 
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          icon: const Icon(Icons.person_pin),
          tooltip: 'Set to Me',
          onPressed: () {
            setState(() {
              controller.text = _authService.currentUser?.displayName ?? 'Me';
            });
          },
        ),
      ),
    );
  }

  Widget _formatButton(String label, int value) {
    bool isSelected = _setsToWin == value;
    return ElevatedButton(
      onPressed: () => setState(() => _setsToWin = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(label),
    );
  }

  Widget _customFormatButton() {
    bool isCustom = _setsToWin != 3 && _setsToWin != 4;
    return ElevatedButton(
      onPressed: _showCustomSetsDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCustom ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(isCustom ? 'First to $_setsToWin sets' : 'Custom'),
    );
  }
}
