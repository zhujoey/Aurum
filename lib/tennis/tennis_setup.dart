import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/widgets/active_match_banner.dart';
import 'tennis_scoreboard.dart';

class TennisSetup extends StatefulWidget {
  const TennisSetup({super.key});

  @override
  State<TennisSetup> createState() => _TennisSetupState();
}

class _TennisSetupState extends State<TennisSetup> {
  final AuthService _authService = AuthService();
  final TextEditingController _p1Controller = TextEditingController();
  final TextEditingController _p2Controller = TextEditingController();
  final TextEditingController _p3Controller = TextEditingController();
  final TextEditingController _p4Controller = TextEditingController();

  bool _isDoubles = false;
  int _setsToWin = 2; // Best of 3 by default
  bool _keepRunningTimers = false;

  final List<bool> _isInviteMode = [false, false, false, false];
  List<Map<String, dynamic>> _friendsList = [];
  Map<String, dynamic>? _savedMatch;

  @override
  void initState() {
    super.initState();
    _loadMyUsername();
    _loadFriends();
    _checkSavedMatch();
  }

  void _loadMyUsername() {
    final user = _authService.currentUser;
    if (user == null) return;

    _p1Controller.text = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : 'Player 1';

    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
      if (doc.exists && mounted) {
        final username = doc.data()?['username'] as String?;
        if (username != null && username.isNotEmpty) {
          setState(() {
            _p1Controller.text = username;
          });
        }
      }
    });

    _p2Controller.text = _isDoubles ? 'Guest 2' : 'Guest 2';
    _p3Controller.text = 'Guest 3';
    _p4Controller.text = 'Guest 4';
  }

  void _loadFriends() async {
    final user = _authService.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .get();

    if (mounted) {
      setState(() {
        _friendsList = snapshot.docs.map((doc) => doc.data()).toList();
      });
    }
  }

  Future<void> _checkSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final String? matchJson = prefs.getString('active_tennis_match');
    if (matchJson != null) {
      final saved = jsonDecode(matchJson);
      final String? matchId = saved['matchId'];

      if (matchId != null && matchId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('active_matches')
              .doc(matchId)
              .get();

          if (doc.exists) {
            final data = doc.data();
            final String status = data?['status'] ?? 'active';
            if (status == 'completed' || status == 'forfeited') {
              await prefs.remove('active_tennis_match');
              setState(() => _savedMatch = null);
              return;
            }
          } else {
            await prefs.remove('active_tennis_match');
            setState(() => _savedMatch = null);
            return;
          }
        } catch (e) {
          debugPrint("TennisSetup: Error verifying saved match status: $e");
        }
      }

      setState(() {
        _savedMatch = saved;
      });
    }
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _p3Controller.dispose();
    _p4Controller.dispose();
    super.dispose();
  }

  Future<void> _startLocalMatch() async {
    String p1 = _p1Controller.text.trim(); if (p1.isEmpty) p1 = 'Player 1';
    String p2 = _p2Controller.text.trim(); if (p2.isEmpty) p2 = 'Player 2';
    String p3 = _p3Controller.text.trim(); if (p3.isEmpty) p3 = 'Player 3';
    String p4 = _p4Controller.text.trim(); if (p4.isEmpty) p4 = 'Player 4';

    final navigator = Navigator.of(context);

    // End any old matches hosted by this user before starting a new one
    final oldMatches = await FirebaseFirestore.instance
        .collection('active_matches')
        .where('hostUid', isEqualTo: _authService.currentUser!.uid)
        .get();
    for (var doc in oldMatches.docs) {
      await _authService.deleteActiveMatch(doc.id);
    }

    String matchId = await _authService.createActiveMatch(
      sport: 'Tennis',
      participantUids: [_authService.currentUser!.uid],
      hostUid: _authService.currentUser!.uid,
      initialData: {
        'p1Name': p1, 'p2Name': p2, 'p3Name': p3, 'p4Name': p4,
        'isDoubles': _isDoubles, 'setsToWin': _setsToWin,
        'keepRunningTimers': _keepRunningTimers,
        'lastSavedTimestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    if (!mounted) return;
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => TennisMatch(
          p1Name: p1,
          p2Name: p2,
          p3Name: p3,
          p4Name: p4,
          isDoubles: _isDoubles,
          setsToWin: _setsToWin,
          matchId: matchId,
          isHost: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _authService.myActiveMatches,
      builder: (context, snapshot) {
        DocumentSnapshot? activeMatchDoc;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          activeMatchDoc = snapshot.data!.docs.first;
        }

        return Scaffold(
          appBar: AppBar(title: Text('Tennis Setup'.tr)),
          body: SafeArea(
            child: _buildSetupForm(activeMatchDoc),
          ),
        );
      },
    );
  }

  Widget _buildSetupForm(DocumentSnapshot? activeMatchDoc) {
    bool inMatch = activeMatchDoc != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inMatch)
            ActiveMatchBanner(matchDoc: activeMatchDoc)
          else if (_savedMatch != null && (_savedMatch!['matchId'] ?? '').isEmpty) ...[
            _buildActiveMatchCard(),
            const SizedBox(height: 20),
            const Divider(),
          ],

          AbsorbPointer(
            absorbing: inMatch,
            child: Opacity(
              opacity: inMatch ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Game Type'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
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
                  Text('Match Format'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _formatButton('Best of 3 sets', 2),
                          const SizedBox(width: 8),
                          _formatButton('Best of 5 sets', 3),
                          const SizedBox(width: 8),
                          _customFormatButton(),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  Text('Players'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  if (!_isDoubles) ...[
                    _buildPlayerSection(0, _p1Controller, 'Player 1'.tr, Icons.person),
                    const SizedBox(height: 20),
                    _buildPlayerSection(2, _p2Controller, 'Player 2'.tr, Icons.person_outline),
                  ] else ...[
                    Text('TEAM 1'.tr, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildPlayerSection(0, _p1Controller, 'Player 1'.tr, Icons.person),
                    const SizedBox(height: 20),
                    _buildPlayerSection(1, _p2Controller, 'Player 2'.tr, Icons.person),
                    const Divider(height: 40),
                    Text('TEAM 2'.tr, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildPlayerSection(2, _p3Controller, 'Player 3'.tr, Icons.person_outline),
                    const SizedBox(height: 20),
                    _buildPlayerSection(3, _p4Controller, 'Player 4'.tr, Icons.person_outline),
                  ],
                  const Divider(height: 40),
                  Text('Timer Options'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Keep running timers when page not loaded'.tr),
                    subtitle: Text('Timer continues running even when you leave the match screen'.tr),
                    value: _keepRunningTimers,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) => setState(() => _keepRunningTimers = val),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: inMatch ? null : _startLocalMatch,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Start Match'.tr, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveMatchCard() {
    return Card(color: Colors.blue.withValues(alpha: 0.1), child: ListTile(title: Text('Local Match Saved'.tr), trailing: ElevatedButton(onPressed: _startLocalMatch, child: Text('Resume'.tr))));
  }

  Widget _typeButton(String label, bool value) {
    bool isSelected = _isDoubles == value;
    return ElevatedButton(
      onPressed: () {
        if (_isDoubles != value) {
          setState(() {
            _isDoubles = value;
            _loadMyUsername();
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(label.tr),
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
      child: Text(label.tr),
    );
  }

  Widget _customFormatButton() {
    bool isCustom = _setsToWin != 2 && _setsToWin != 3;
    return ElevatedButton(
      onPressed: _showCustomSetsDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCustom ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(isCustom ? 'First to $_setsToWin'.tr : 'Custom'.tr),
    );
  }

  void _showCustomSetsDialog() {
    final controller = TextEditingController(text: _setsToWin.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom Sets to Win'.tr),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Enter number of sets'.tr),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _setsToWin = val);
              }
              Navigator.pop(context);
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSection(int index, TextEditingController controller, String label, IconData icon) {
    bool isInvite = _isInviteMode[index];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
        ToggleButtons(
          isSelected: [!isInvite, isInvite],
          onPressed: (i) => setState(() { _isInviteMode[index] = i == 1; if (i == 1) controller.clear(); }),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(index == 0 ? 'Me'.tr : 'Guest'.tr)),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Invite'.tr)),
          ],
        ),
      ]),
      const SizedBox(height: 8),
      if (isInvite) DropdownMenu<String>(
        width: MediaQuery.of(context).size.width - 48,
        label: Text('Select Friend'.tr),
        dropdownMenuEntries: _friendsList.map((f) => DropdownMenuEntry<String>(
          value: f['username'] as String, 
          label: f['username'] as String
        )).toList(),
        onSelected: (val) => controller.text = val ?? '',
      ) else TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
    ]);
  }
}
