import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sportsaccesories/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'tt_models.dart';
import 'tt_scoreboard.dart';
import 'widgets/tt_invitation_waiting.dart';

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
  StreamSubscription? _matchSubscription;
  StreamSubscription? _friendsSubscription;
  List<Map<String, dynamic>> _friendsList = [];

  // Track if players are guests or invited users
  // index 0: P1, index 1: P2, index 2: P3, index 3: P4
  final List<bool> _isInviteMode = [false, false, false, false];

  @override
  void initState() {
    super.initState();
    _p1Controller.text = _authService.currentUser?.displayName ?? 'Me';
    _p2Controller.text = 'Guest 2';
    _p3Controller.text = 'Guest 2'; // Default for Singles Opponent
    _p4Controller.text = 'Guest 4';
    
    // Global Firebase Cleanup
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
        _checkSavedMatch(); // Verify if local save should also be cleared
      }
    });
  }

  Future<void> _checkSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('active_tt_match');
    if (data != null) {
      final Map<String, dynamic> saved = jsonDecode(data);
      final String? mId = saved['matchId'];
      
      // Sanity check: If this is a cloud match, verify it's still active
      if (mId != null && mId.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('active_matches').doc(mId).get();
          if (doc.exists) {
            final String status = doc.get('status') ?? 'playing';
            if (status != 'playing') {
              // Match was forfeited or ended elsewhere
              // If we are the host, delete the cloud doc too
              if (doc.get('hostUid') == _authService.currentUser?.uid) {
                await _authService.deleteActiveMatch(mId);
              }
              await prefs.remove('active_tt_match');
              setState(() => _savedMatch = null);
              return;
            }
          } else {
            // Document was deleted
            await prefs.remove('active_tt_match');
            setState(() => _savedMatch = null);
            return;
          }
        } catch (e) {
          print("Setup: Error verifying saved match status: $e");
        }
      }

      setState(() {
        _savedMatch = saved;
      });
    }
  }

  Future<void> _clearSavedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    if (_savedMatch != null && _savedMatch!['matchId'] != null && _savedMatch!['matchId'].isNotEmpty) {
      await _authService.deleteActiveMatch(_savedMatch!['matchId']);
    }
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
            initialFirstServerOfMatch: _savedMatch!['firstServerOfMatch'] ?? 0,
            initialFirstServerOfSet: _savedMatch!['firstServerOfSet'] ?? 0,
            initialFirstReceiverOfSet: _savedMatch!['firstReceiverOfSet'] ?? 0,
            initialP1OnLeft: _savedMatch!['p1OnLeft'] ?? true,
            initialLogs: (_savedMatch!['logs'] as List? ?? [])
                .map((p) => MatchLogEntry.fromMap(p))
                .toList(),
            initialExpediteActive: _savedMatch!['expediteActive'] ?? false,
            initialGameTimeSeconds: _savedMatch!['gameTimeSeconds'] ?? 0,
            activeTimerSeconds: _savedMatch!['activeTimerSeconds'] ?? 0,
            activeTimerTitle: _savedMatch!['activeTimerTitle'] ?? '',
            matchId: _savedMatch!['matchId'] ?? '',
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

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _handleStartMatch() async {
    // Basic validation: ensure all Invite modes have a friend selected
    if (!_isDoubles) {
      if (_isInviteMode[0] && _p1Controller.text.isEmpty) {
        _showError('Please select a friend for Player 1.');
        return;
      }
      if (_isInviteMode[2] && _p3Controller.text.isEmpty) {
        _showError('Please select a friend for Player 2.');
        return;
      }
    } else {
      if (_isInviteMode[0] && _p1Controller.text.isEmpty) {
        _showError('Please select a friend for Player 1.');
        return;
      }
      if (_isInviteMode[1] && _p2Controller.text.isEmpty) {
        _showError('Please select a friend for Partner.');
        return;
      }
      if (_isInviteMode[2] && _p3Controller.text.isEmpty) {
        _showError('Please select a friend for Opponent 1.');
        return;
      }
      if (_isInviteMode[3] && _p4Controller.text.isEmpty) {
        _showError('Please select a friend for Opponent 2.');
        return;
      }
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
    
    // Final duplicate check for ALL players (Guests and Invites)
    List<String> activeNames = [];
    if (!_isDoubles) {
      activeNames = [n1, n3];
    } else {
      activeNames = [n1, n2, n3, n4];
    }

    if (Set.from(activeNames).length != activeNames.length) {
      _showError('All player names must be unique.');
      return;
    }

    List<String> invalidNames = [];
    List<String> inMatchNames = [];
    
    for (String name in namesToInvite) {
      if (name.isEmpty) continue;
      
      if (name.toLowerCase() == currentUsername.toLowerCase()) {
        invalidNames.add("$name (You cannot invite yourself)");
        continue;
      }

      final user = await _authService.findUserByUsername(name);
      if (user != null) {
        // Check if this user is already in an active match
        final inMatch = await _authService.isUserInMatch(user['uid']);
        if (inMatch) {
          inMatchNames.add(name);
          continue;
        }

        String requestId = await _authService.sendMatchRequest(
          targetUid: user['uid'],
          sport: 'Table Tennis',
          isDoubles: _isDoubles,
          p1Name: n1,
          p2Name: n2,
          p3Name: n3,
          p4Name: n4,
          setsToWin: _setsToWin,
        );
        invitations.add({'name': name, 'id': requestId, 'uid': user['uid']});
      } else {
        invalidNames.add(name);
      }
    }

    if (invalidNames.isNotEmpty || inMatchNames.isNotEmpty) {
      if (!mounted) return;
      String errorMsg = "";
      if (invalidNames.isNotEmpty) {
        errorMsg += "Not found: ${invalidNames.join(", ")}. ";
      }
      if (inMatchNames.isNotEmpty) {
        errorMsg += "Already in a match: ${inMatchNames.join(", ")}.";
      }

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Invite Players'),
          content: Text(errorMsg.trim()),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    if (invitations.isNotEmpty) {
      bool? proceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => InvitationWaitingDialog(
          invitations: invitations,
          authService: _authService,
        ),
      );
      
      if (proceed != true) {
        // Clean up requests if cancelled
        for (var invite in invitations) {
          _authService.deleteMatchRequest(invite['id']);
        }
        return; 
      }
    }

    if (!mounted) return;

    // End any old matches hosted by this user before starting a new one
    final oldMatches = await FirebaseFirestore.instance
        .collection('active_matches')
        .where('hostUid', isEqualTo: _authService.currentUser!.uid)
        .get();
    for (var doc in oldMatches.docs) {
      await _authService.deleteActiveMatch(doc.id);
    }

    // Always create a cloud record for the match to mark the host and participants as "busy"
    List<String> uids = [_authService.currentUser!.uid];
    uids.addAll(invitations.map((i) => i['uid'] as String));
    
    String matchId = await _authService.createActiveMatch(
      sport: 'Table Tennis',
      participantUids: uids,
      hostUid: _authService.currentUser!.uid,
      initialData: {
        'p1Name': n1, 'p2Name': n2, 'p3Name': n3, 'p4Name': n4,
        'isDoubles': _isDoubles, 'setsToWin': _setsToWin,
      },
    );
    
    // Clean up requests now that match is created
    for (var invite in invitations) {
      _authService.deleteMatchRequest(invite['id']);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TableTennisMatch(
          p1Name: n1, p2Name: n2, p3Name: n3, p4Name: n4,
          isDoubles: _isDoubles, setsToWin: _setsToWin,
          matchId: matchId, // Pass the match ID
        ),
      ),
    );
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
          appBar: AppBar(title: const Text('Table Tennis Setup')),
          body: SafeArea(
            child: _buildSetupForm(activeMatchDoc),
          ),
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
          if (inMatch) 
            _buildActiveCloudMatchBanner(activeMatchDoc)
          else if (_savedMatch != null && (_savedMatch!['matchId'] ?? '').isEmpty) ...[
            _buildActiveMatchCard(),
            const SizedBox(height: 20),
            const Divider(),
          ],
          
          // Form content
          AbsorbPointer(
            absorbing: inMatch,
            child: Opacity(
              opacity: inMatch ? 0.5 : 1.0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                    _buildDynamicPlayerSection(0, _p1Controller, 'Player 1', Icons.person),
                    const SizedBox(height: 20),
                    _buildDynamicPlayerSection(2, _p3Controller, 'Player 2', Icons.person_outline),
                  ] else ...[
                    const Text('TEAM 1', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildDynamicPlayerSection(0, _p1Controller, 'Player 1', Icons.person),
                    const SizedBox(height: 20),
                    _buildDynamicPlayerSection(1, _p2Controller, 'Player 2', Icons.person),
                    const Divider(height: 40),
                    const Text('TEAM 2', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    _buildDynamicPlayerSection(2, _p3Controller, 'Player 3', Icons.person_outline),
                    const SizedBox(height: 20),
                    _buildDynamicPlayerSection(3, _p4Controller, 'Player 4', Icons.person_outline),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: inMatch ? null : _handleStartMatch,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16), 
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[800],
            ),
            child: Text(inMatch ? 'Match Already in Progress' : 'Start Match', style: const TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCloudMatchBanner(DocumentSnapshot matchDoc) {
    final data = matchDoc.data() as Map<String, dynamic>;
    bool isHost = data['hostUid'] == _authService.currentUser?.uid;
    
    // Attempt to get scores from cloud data if available, or fall back to local
    int p1Sets = data['matchData']?['p1Sets'] ?? _savedMatch?['p1Sets'] ?? 0;
    int p2Sets = data['matchData']?['p2Sets'] ?? _savedMatch?['p2Sets'] ?? 0;

    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 24),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.lock_clock, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Match in Progress ($p1Sets - $p2Sets)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        isHost 
                          ? 'You are the host. Finish this match to start a new one.'
                          : 'You are a participant. You cannot start a new match yet.',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isHost)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Discard Match?'),
                          content: const Text('This will delete all match data. This action cannot be undone.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Discard', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        // Cleanup local first to prevent UI flicker
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('active_tt_match');
                        setState(() => _savedMatch = null);
                        
                        // Then cleanup cloud
                        await _authService.deleteActiveMatch(matchDoc.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Discard'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _resumeMatch,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Resume'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.center,
                child: ElevatedButton.icon(
                  onPressed: () => _authService.updateMatchStatus(matchDoc.id, 'forfeited'),
                  icon: const Icon(Icons.flag, size: 18),
                  label: const Text('Forfeit Match'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                ),
              ),
          ],
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
      onPressed: () {
        if (_isDoubles != value) {
          setState(() {
            _isDoubles = value;
            // Reset all names to unique defaults when switching modes 
            // to prevent "ghost" name conflicts between Singles and Doubles.
            _p1Controller.text = _authService.currentUser?.displayName ?? 'Me';
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
      child: Text(label),
    );
  }

  Widget _buildDynamicPlayerSection(int index, TextEditingController controller, String label, IconData icon) {
    bool isInvite = _isInviteMode[index];
    bool isMe = index == 0 && !isInvite && controller.text == (_authService.currentUser?.displayName ?? 'Me');
    
    // Get currently selected friends or typed names in other active slots to avoid duplicates
    List<String> otherSelectedNames = [];
    for (int i = 0; i < 4; i++) {
      // Only consider indices relevant to the current mode to prevent "ghost" filtering
      bool isRelevant = _isDoubles || (i == 0 || i == 2);
      if (isRelevant && i != index) {
        final ctrl = i == 0 ? _p1Controller : (i == 1 ? _p2Controller : (i == 2 ? _p3Controller : _p4Controller));
        if (ctrl.text.isNotEmpty) otherSelectedNames.add(ctrl.text);
      }
    }

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
                    if (index == 0) {
                      controller.text = _authService.currentUser?.displayName ?? 'Me';
                    } else if (index == 2) {
                      controller.text = _isDoubles ? 'Guest 3' : 'Guest 2';
                    } else if (index == 1) {
                      controller.text = 'Guest 2';
                    } else {
                      controller.text = 'Guest 4';
                    }
                  } else {
                    controller.clear();
                  }
                });
              },
              constraints: const BoxConstraints(minHeight: 30, minWidth: 60),
              borderRadius: BorderRadius.circular(8),
              children: [
                Text(index == 0 ? 'Me' : 'Guest', style: const TextStyle(fontSize: 12)),
                const Text('Invite', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        isInvite 
          ? LayoutBuilder(
              builder: (context, constraints) => DropdownMenu<String>(
                width: constraints.maxWidth,
                initialSelection: controller.text.isEmpty || !_friendsList.any((f) => f['username'] == controller.text) 
                    ? null 
                    : controller.text,
                requestFocusOnTap: true,
                enableFilter: true,
                leadingIcon: Icon(icon),
                label: const Text('Select Friend'),
                inputDecorationTheme: const InputDecorationTheme(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                ),
                dropdownMenuEntries: _friendsList
                    .where((f) => !otherSelectedNames.contains(f['username']))
                    .map((f) => DropdownMenuEntry(
                          value: f['username'] as String,
                          label: f['username'] as String,
                        ))
                    .toList(),
                onSelected: (val) {
                  if (val != null) {
                    setState(() => controller.text = val);
                  }
                },
              ),
            )
          : TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: isMe ? 'Account: $label' : 'Temporary Guest Name',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(icon),
                hintText: 'e.g. Guest',
              ),
              readOnly: isMe, // Prevent editing 'Me' to keep it as the account name
              onTap: isMe ? () => setState(() => controller.text = 'Guest 1') : null, // If they tap it, switch back to guest mode
            ),
      ],
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
