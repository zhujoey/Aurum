import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badminton_models.dart';
import 'badminton_scoreboard.dart';
import '../table_tennis/widgets/tt_invitation_waiting.dart';
import 'package:aurum/widgets/active_match_banner.dart';

class BadmintonSetup extends StatefulWidget {
  const BadmintonSetup({super.key});

  @override
  State<BadmintonSetup> createState() => _BadmintonSetupState();
}

class _BadmintonSetupState extends State<BadmintonSetup> {
  final TextEditingController _p1Controller = TextEditingController();
  final TextEditingController _p2Controller = TextEditingController();
  final TextEditingController _p3Controller = TextEditingController();
  final TextEditingController _p4Controller = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isDoubles = false;
  int _gamesToWin = 2; // Best of 3
  bool _keepRunningTimers = false;
  Map<String, dynamic>? _savedMatch;
  StreamSubscription? _matchSubscription;
  StreamSubscription? _friendsSubscription;
  List<Map<String, dynamic>> _friendsList = [];

  final List<bool> _isInviteMode = [false, false, false, false];

  void _loadMyUsername() {
    final user = _authService.currentUser;
    if (user == null) return;

    final String initialName = (user.displayName != null && user.displayName!.isNotEmpty)
        ? user.displayName!
        : 'Player 1';
    _p1Controller.text = initialName;

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
  }

  @override
  void initState() {
    super.initState();
    _loadMyUsername();
    _p2Controller.text = 'Guest 2';
    _p3Controller.text = 'Guest 2'; 
    _p4Controller.text = 'Guest 4';
    
    _authService.cleanupSentRequests();
    _authService.cleanupOldHostedMatches();

    _friendsSubscription = _authService.friendsStream.listen((snapshot) {
      if (mounted) {
        setState(() {
          _friendsList = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        });
      }
    });

    _checkSavedMatch();
    _startListeningToMatchStatus();
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _friendsSubscription?.cancel();
    _p1Controller.dispose();
    _p2Controller.dispose();
    _p3Controller.dispose();
    _p4Controller.dispose();
    super.dispose();
  }

  void _startListeningToMatchStatus() {
    _matchSubscription = _authService.myActiveMatches.listen((snapshot) {
      if (snapshot.docs.isEmpty) {
        _checkSavedMatch();
      }
    });
  }

  Future<void> _checkSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_badminton_match');
    if (data != null) {
      final Map<String, dynamic> saved = jsonDecode(data);
      final String? mId = saved['matchId'];
      
      if (mId != null && mId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('active_matches').doc(mId).get();
          if (doc.exists) {
            final String status = doc.get('status') ?? 'playing';
            if (status != 'playing') {
              if (doc.get('hostUid') == _authService.currentUser?.uid) {
                await _authService.deleteActiveMatch(mId);
              }
              await prefs.remove('active_badminton_match');
              setState(() => _savedMatch = null);
              return;
            }
          } else {
            await prefs.remove('active_badminton_match');
            setState(() => _savedMatch = null);
            return;
          }
        } catch (e) {
          debugPrint("Setup: Error verifying saved match status: $e");
        }
      }
      setState(() => _savedMatch = saved);
    }
  }

  void _resumeMatch({DocumentSnapshot? cloudDoc}) async {
    Map<String, dynamic>? data = _savedMatch;
    
    if (cloudDoc != null) {
      final cloudData = cloudDoc.data() as Map<String, dynamic>;
      data = cloudData['matchData'];
      if (data != null) {
        data['matchId'] = cloudDoc.id;
      }
    }

    if (data != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BadmintonMatch(
            p1Name: data!['p1Name'] ?? 'P1',
            p2Name: data['p2Name'] ?? '',
            p3Name: data['p3Name'] ?? 'P2',
            p4Name: data['p4Name'] ?? '',
            isDoubles: data['isDoubles'] ?? false,
            gamesToWin: data['gamesToWin'] ?? 2,
            initialP1Score: data['p1Score'] ?? 0,
            initialP2Score: data['p2Score'] ?? 0,
            initialP1Games: data['p1Games'] ?? 0,
            initialP2Games: data['p2Games'] ?? 0,
            initialIsGameOver: data['isGameOver'] ?? false,
            initialPointHistory: List<int>.from(data['pointHistory'] ?? []),
            initialGameSummaries: (data['gameSummaries'] as List? ?? [])
                .map((s) => BadmintonGameSummary.fromMap(s))
                .toList(),
            initialFirstServerOfMatch: data['firstServerOfMatch'] ?? 0,
            initialFirstServerOfGame: data['firstServerOfGame'] ?? 0,
            initialP1OnLeft: data['p1OnLeft'] ?? true,
            initialLogs: (data['logs'] as List? ?? [])
                .map((p) => BadmintonLogEntry.fromMap(p))
                .toList(),
            initialMatchTimeSeconds: data['matchTimeSeconds'] ?? 0,
            activeTimerEndTime: data['timerEndTime'],
            activeTimerTitle: data['timerTitle'] ?? '',
            initialKeepRunningTimers: data['keepRunningTimers'] ?? false,
            initialLastSavedTimestamp: data['lastSavedTimestamp'],
            matchId: data['matchId'] ?? '',
            isHost: true,
          ),
        ),
      );
      _checkSavedMatch();
    }
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'.tr),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'.tr))],
      ),
    );
  }

  Future<void> _handleStartMatch() async {
    if (!_isDoubles) {
      if (_isInviteMode[0] && _p1Controller.text.isEmpty) { _showError('Please select a friend for Player 1.'); return; }
      if (_isInviteMode[2] && _p3Controller.text.isEmpty) { _showError('Please select a friend for Player 2.'); return; }
    } else {
      if (_isInviteMode[0] && _p1Controller.text.isEmpty) { _showError('Please select a friend for Player 1.'); return; }
      if (_isInviteMode[1] && _p2Controller.text.isEmpty) { _showError('Please select a friend for Partner.'); return; }
      if (_isInviteMode[2] && _p3Controller.text.isEmpty) { _showError('Please select a friend for Opponent 1.'); return; }
      if (_isInviteMode[3] && _p4Controller.text.isEmpty) { _showError('Please select a friend for Opponent 2.'); return; }
    }

    String n1 = _p1Controller.text.trim(); if (n1.isEmpty) n1 = 'P1';
    String n2 = _p2Controller.text.trim(); if (n2.isEmpty) n2 = _isDoubles ? 'Partner' : '';
    String n3 = _p3Controller.text.trim(); if (n3.isEmpty) n3 = 'Opponent 1';
    String n4 = _p4Controller.text.trim(); if (n4.isEmpty) n4 = _isDoubles ? 'Opponent 2' : '';

    List<Map<String, dynamic>> invitations = [];
    List<String> namesToInvite = [];
    if (!_isDoubles) {
      if (_isInviteMode[0]) namesToInvite.add(n1);
      if (_isInviteMode[2]) namesToInvite.add(n3);
    } else {
      if (_isInviteMode[0]) namesToInvite.add(n1);
      if (_isInviteMode[1]) namesToInvite.add(n2);
      if (_isInviteMode[2]) namesToInvite.add(n3);
      if (_isInviteMode[3]) namesToInvite.add(n4);
    }

    String currentUsername = _authService.currentUser?.displayName ?? '';
    List<String> activeNames = _isDoubles ? [n1, n2, n3, n4] : [n1, n3];
    if (Set.from(activeNames).length != activeNames.length) { _showError('All player names must be unique.'.tr); return; }

    List<String> invalidNames = [];
    List<String> inMatchNames = [];
    for (String name in namesToInvite) {
      if (name.toLowerCase() == currentUsername.toLowerCase()) { invalidNames.add("$name (You)"); continue; }
      final user = await _authService.findUserByUsername(name);
      if (user != null) {
        if (await _authService.isUserInMatch(user['uid'])) { inMatchNames.add(name); continue; }
        String requestId = await _authService.sendMatchRequest(
          targetUid: user['uid'], sport: 'Badminton', isDoubles: _isDoubles,
          p1Name: n1, p2Name: n2, p3Name: n3, p4Name: n4, setsToWin: _gamesToWin,
        );
        invitations.add({'name': name, 'id': requestId, 'uid': user['uid']});
      } else { invalidNames.add(name); }
    }

    if (invalidNames.isNotEmpty || inMatchNames.isNotEmpty) {
      String errorMsg = invalidNames.isNotEmpty ? "Not found: ${invalidNames.join(", ")}. " : "";
      if (inMatchNames.isNotEmpty) errorMsg += "Already in match: ${inMatchNames.join(", ")}";
      _showError(errorMsg);
      return;
    }

    if (invitations.isNotEmpty) {
      if (!mounted) return;
      bool? proceed = await showDialog<bool>(
        context: context, barrierDismissible: false,
        builder: (context) => InvitationWaitingDialog(invitations: invitations, authService: _authService),
      );
      if (!mounted) return;
      if (proceed != true) {
        for (var invite in invitations) { _authService.deleteMatchRequest(invite['id']); }
        return;
      }
    }

    List<String> uids = [_authService.currentUser!.uid];
    uids.addAll(invitations.map((i) => i['uid'] as String));
    String matchId = await _authService.createActiveMatch(
      sport: 'Badminton', participantUids: uids, hostUid: _authService.currentUser!.uid,
      initialData: {
        'p1Name': n1, 'p2Name': n2, 'p3Name': n3, 'p4Name': n4,
        'isDoubles': _isDoubles, 'gamesToWin': _gamesToWin,
        'keepRunningTimers': _keepRunningTimers,
        'lastSavedTimestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );

    for (var invite in invitations) { _authService.deleteMatchRequest(invite['id']); }

    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (context) => BadmintonMatch(
      p1Name: n1, p2Name: n2, p3Name: n3, p4Name: n4, isDoubles: _isDoubles, gamesToWin: _gamesToWin,
      initialKeepRunningTimers: _keepRunningTimers,
      initialLastSavedTimestamp: DateTime.now().millisecondsSinceEpoch,
      matchId: matchId, isHost: true,
    )));
    _checkSavedMatch();
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
          appBar: AppBar(title: Text('Badminton Setup'.tr)),
          body: SafeArea(child: _buildSetupForm(activeMatchDoc)),
        );
      }
    );
  }

  Widget _buildSetupForm(DocumentSnapshot? activeMatchDoc) {
    bool inMatch = activeMatchDoc != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (inMatch) ActiveMatchBanner(matchDoc: activeMatchDoc)
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
                children: [
                  Text('Game Type'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _typeButton('Singles', false),
                    const SizedBox(width: 12),
                    _typeButton('Doubles', true),
                  ]),
                  const Divider(height: 40),
                  Text('Match Format'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _formatButton('Best of 3', 2),
                          const SizedBox(width: 8),
                          _formatButton('Best of 1', 1),
                          const SizedBox(width: 8),
                          _customFormatButton(),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 40),
                  Text('Players'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (!_isDoubles) ...[
                    _buildPlayerSection(0, _p1Controller, 'Player 1'.tr, Icons.person),
                    const SizedBox(height: 20),
                    _buildPlayerSection(2, _p3Controller, 'Player 2'.tr, Icons.person_outline),
                  ] else ...[
                    _buildPlayerSection(0, _p1Controller, 'Team 1 - P1'.tr, Icons.person),
                    const SizedBox(height: 12),
                    _buildPlayerSection(1, _p2Controller, 'Team 1 - P2'.tr, Icons.person),
                    const Divider(height: 30),
                    _buildPlayerSection(2, _p3Controller, 'Team 2 - P1'.tr, Icons.person_outline),
                    const SizedBox(height: 12),
                    _buildPlayerSection(3, _p4Controller, 'Team 2 - P2'.tr, Icons.person_outline),
                  ],
                  const Divider(height: 40),
                  Text('Timer Options'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Keep running timers when page not loaded'.tr),
                    subtitle: Text('Timers will continue running even when you leave the match screen'.tr),
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
            onPressed: inMatch ? null : _handleStartMatch,
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: Colors.blue, foregroundColor: Colors.white),
            child: Text(inMatch ? 'Match In Progress'.tr : 'Start Match'.tr, style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }



  Widget _buildActiveMatchCard() {
    return Card(color: Colors.blue.withValues(alpha: 0.1), child: ListTile(title: Text('Local Match Saved'.tr), trailing: ElevatedButton(onPressed: _resumeMatch, child: Text('Resume'.tr))));
  }

  Widget _typeButton(String label, bool value) {
    bool isSelected = _isDoubles == value;
    return ElevatedButton(
      onPressed: () {
        if (_isDoubles != value) {
          setState(() {
            _isDoubles = value;
            _loadMyUsername();
            if (_isDoubles) {
              _p2Controller.text = 'Guest 2';
              _p3Controller.text = 'Guest 3';
              _p4Controller.text = 'Guest 4';
            } else {
              _p2Controller.text = 'Guest 2';
              _p3Controller.text = 'Guest 2';
              _p4Controller.text = 'Guest 4';
            }
            
            for (int i = 0; i < 4; i++) {
              _isInviteMode[i] = false;
            }
          });
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: isSelected ? Colors.blue : Colors.grey[800], foregroundColor: Colors.white),
      child: Text(label.tr),
    );
  }

  Widget _formatButton(String label, int value) {
    bool isSelected = _gamesToWin == value;
    return ElevatedButton(
      onPressed: () => setState(() => _gamesToWin = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(label.tr),
    );
  }

  Widget _customFormatButton() {
    bool isCustom = _gamesToWin != 1 && _gamesToWin != 2;
    return ElevatedButton(
      onPressed: _showCustomGamesDialog,
      style: ElevatedButton.styleFrom(
        backgroundColor: isCustom ? Colors.blue : Colors.grey[800],
        foregroundColor: Colors.white,
      ),
      child: Text(isCustom ? '${'First to'.tr} $_gamesToWin ${'games'.tr}' : 'Custom'.tr),
    );
  }

  void _showCustomGamesDialog() {
    final controller = TextEditingController(text: _gamesToWin.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Custom Games to Win'.tr),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'Enter number of games'.tr),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                setState(() => _gamesToWin = val);
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
          children: [Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Guest'.tr)), Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('Invite'.tr))],
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
