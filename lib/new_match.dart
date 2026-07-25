import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _guestNameController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isInviting = false;
  int _setsToWin = 4;
  StreamSubscription? _requestSub;
  Map<String, dynamic>? _savedMatch;

  @override
  void initState() {
    super.initState();
    _checkSavedMatch();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _guestNameController.dispose();
    _requestSub?.cancel();
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
            p1Name: _savedMatch!['p1Name'],
            p2Name: _savedMatch!['p2Name'],
            setsToWin: _savedMatch!['setsToWin'],
            initialP1Score: _savedMatch!['p1Score'],
            initialP2Score: _savedMatch!['p2Score'],
            initialP1Sets: _savedMatch!['p1Sets'],
            initialP2Sets: _savedMatch!['p2Sets'],
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

  void _inviteUser() async {
    final String targetUsername = _usernameController.text.trim();
    if (targetUsername.isEmpty) return;

    if (targetUsername == _authService.currentUser?.displayName) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot invite yourself!')),
      );
      return;
    }

    setState(() => _isInviting = true);

    final targetUser = await _authService.findUserByUsername(targetUsername);

    if (targetUser == null) {
      if (!mounted) return;
      setState(() => _isInviting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not found. Ensure the username is exact.')),
      );
      return;
    }

    final requestId = await _authService.sendMatchRequest(
      targetUid: targetUser['uid'],
      sport: 'Table Tennis',
      setsToWin: _setsToWin,
    );

    _requestSub = _authService.listenToRequest(requestId).listen((doc) {
      if (!doc.exists) return;
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];

      if (status == 'accepted') {
        _requestSub?.cancel();
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TableTennisMatch(
              p1Name: _authService.currentUser?.displayName ?? 'Me',
              p2Name: targetUsername,
              setsToWin: _setsToWin,
            ),
          ),
        ).then((_) => _checkSavedMatch());
      } else if (status == 'rejected') {
        _requestSub?.cancel();
        if (!mounted) return;
        setState(() => _isInviting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetUsername declined the match.')),
        );
      }
    });
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
                Card(
                  color: Colors.blue.withValues(alpha: 0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text(
                          'Match in Progress',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_savedMatch!['p1Name']} vs ${_savedMatch!['p2Name']}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_savedMatch!['p1Sets']} - ${_savedMatch!['p2Sets']}',
                          style: const TextStyle(color: Colors.blue, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Current: (${_savedMatch!['p1Score']} - ${_savedMatch!['p2Score']})',
                          style: const TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: _clearSavedMatch,
                              child: const Text('Discard', style: TextStyle(color: Colors.red)),
                            ),
                            ElevatedButton(
                              onPressed: _resumeMatch,
                              child: const Text('Resume Match'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
              ],
              const Text(
                'Match Format',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _formatButton('First to 4 sets', 4),
                    const SizedBox(width: 8),
                    _formatButton('First to 3 sets', 3),
                    const SizedBox(width: 8),
                    _customFormatButton(),
                  ],
                ),
              ),
              const Divider(height: 40),
              const Text(
                'Invite Opponent',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Enter the exact username of the person you want to play with.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: !_isInviting,
              ),
              const SizedBox(height: 24),
              if (_isInviting)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Waiting for response...'),
                  ],
                )
              else
                ElevatedButton(
                  onPressed: _inviteUser,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Send Invite', style: TextStyle(fontSize: 18)),
                ),
              const SizedBox(height: 60),
              if (!_isInviting) ...[
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  'Local Play',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _guestNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guest Name (Optional)',
                    hintText: 'Guest',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () async {
                    String guestName = _guestNameController.text.trim();
                    if (guestName.isEmpty) guestName = 'Guest';
                    
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TableTennisMatch(
                          p1Name: _authService.currentUser?.displayName ?? 'Me',
                          p2Name: guestName,
                          setsToWin: _setsToWin,
                        ),
                      ),
                    );
                    _checkSavedMatch();
                  },
                  child: const Text('Start Local Match'),
                ),
              ],
            ],
          ),
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

class SetSummary {
  final int p1Score;
  final int p2Score;
  final List<int> pointSequence;
  final bool isExpediteSet;

  SetSummary({required this.p1Score, required this.p2Score, required this.pointSequence, this.isExpediteSet = false});

  Map<String, dynamic> toMap() => {
    'p1Score': p1Score,
    'p2Score': p2Score,
    'pointSequence': pointSequence,
    'isExpediteSet': isExpediteSet,
  };

  factory SetSummary.fromMap(Map<String, dynamic> map) => SetSummary(
    p1Score: map['p1Score'],
    p2Score: map['p2Score'],
    pointSequence: List<int>.from(map['pointSequence']),
    isExpediteSet: map['isExpediteSet'] ?? false,
  );
}

class MatchLogEntry {
  final String type; // 'penalty', 'timeout', 'expedite'
  final int? playerNum;
  final String? cardType; 
  final String? reason;
  final int setNum;
  final int p1Score;
  final int p2Score;

  MatchLogEntry({
    required this.type,
    this.playerNum,
    this.cardType,
    this.reason,
    required this.setNum,
    required this.p1Score,
    required this.p2Score,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'playerNum': playerNum,
    'cardType': cardType,
    'reason': reason,
    'setNum': setNum,
    'p1Score': p1Score,
    'p2Score': p2Score,
  };

  factory MatchLogEntry.fromMap(Map<String, dynamic> map) => MatchLogEntry(
    type: map['type'],
    playerNum: map['playerNum'],
    cardType: map['cardType'],
    reason: map['reason'],
    setNum: map['setNum'],
    p1Score: map['p1Score'],
    p2Score: map['p2Score'],
  );
}

class TableTennisMatch extends StatefulWidget {
  final String p1Name;
  final String p2Name;
  final int setsToWin;
  final int initialP1Score;
  final int initialP2Score;
  final int initialP1Sets;
  final int initialP2Sets;
  final bool initialIsSetOver;
  final List<int> initialPointHistory;
  final List<SetSummary> initialSetSummaries;
  final bool initialP1TimeoutUsed;
  final bool initialP2TimeoutUsed;
  final int initialFirstServer;
  final bool initialP1OnLeft;
  final List<MatchLogEntry> initialLogs;
  final bool initialExpediteActive;
  final int initialGameTimeSeconds;

  const TableTennisMatch({
    super.key, 
    required this.p1Name, 
    required this.p2Name,
    required this.setsToWin,
    this.initialP1Score = 0,
    this.initialP2Score = 0,
    this.initialP1Sets = 0,
    this.initialP2Sets = 0,
    this.initialIsSetOver = false,
    this.initialPointHistory = const [],
    this.initialSetSummaries = const [],
    this.initialP1TimeoutUsed = false,
    this.initialP2TimeoutUsed = false,
    this.initialFirstServer = 1,
    this.initialP1OnLeft = true,
    this.initialLogs = const [],
    this.initialExpediteActive = false,
    this.initialGameTimeSeconds = 0,
  });

  @override
  State<TableTennisMatch> createState() => _TableTennisMatchState();
}

class MatchState {
  final int p1Score;
  final int p2Score;
  final int p1Sets;
  final int p2Sets;
  final bool isSetOver;
  final List<int> pointHistory;
  final List<SetSummary> setSummaries;
  final bool p1TimeoutUsed;
  final bool p2TimeoutUsed;
  final int firstServer;
  final bool p1OnLeft;
  final List<MatchLogEntry> logs;
  final bool expediteActive;
  final int gameTimeSeconds;

  MatchState({
    required this.p1Score, 
    required this.p2Score, 
    required this.p1Sets, 
    required this.p2Sets,
    required this.isSetOver,
    required this.pointHistory,
    required this.setSummaries,
    required this.p1TimeoutUsed,
    required this.p2TimeoutUsed,
    required this.firstServer,
    required this.p1OnLeft,
    required this.logs,
    required this.expediteActive,
    required this.gameTimeSeconds,
  });
}

class _TableTennisMatchState extends State<TableTennisMatch> {
  late int player1Score;
  late int player2Score;
  late int player1Sets;
  late int player2Sets;
  late bool isSetOver;
  List<int> pointHistory = [];
  List<SetSummary> setSummaries = [];
  List<MatchLogEntry> logs = [];
  bool isFinished = false;
  bool p1TimeoutUsed = false;
  bool p2TimeoutUsed = false;
  late int firstServerOfMatch;
  late bool p1OnLeftOfMatch;
  int _activeTimerSeconds = 0;
  String _activeTimerTitle = '';
  Timer? _activeTimer;
  
  bool expediteActive = false;
  int gameTimeSeconds = 0;
  Timer? _expediteInternalTimer;
  
  final List<MatchState> _history = [];

  @override
  void initState() {
    super.initState();
    player1Score = widget.initialP1Score;
    player2Score = widget.initialP2Score;
    player1Sets = widget.initialP1Sets;
    player2Sets = widget.initialP2Sets;
    isSetOver = widget.initialIsSetOver;
    pointHistory = List<int>.from(widget.initialPointHistory);
    setSummaries = List<SetSummary>.from(widget.initialSetSummaries);
    p1TimeoutUsed = widget.initialP1TimeoutUsed;
    p2TimeoutUsed = widget.initialP2TimeoutUsed;
    firstServerOfMatch = widget.initialFirstServer;
    p1OnLeftOfMatch = widget.initialP1OnLeft;
    logs = List<MatchLogEntry>.from(widget.initialLogs);
    expediteActive = widget.initialExpediteActive;
    gameTimeSeconds = widget.initialGameTimeSeconds;
    
    _checkMatchWinner();
    _startInternalExpediteTimer();
    _persistMatch();

    if (player1Score == 0 && player2Score == 0 && player1Sets == 0 && player2Sets == 0) {
      final rand = Random();
      firstServerOfMatch = rand.nextBool() ? 1 : 2;
      p1OnLeftOfMatch = rand.nextBool();
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptWarmup());
    }
  }

  @override
  void dispose() {
    _activeTimer?.cancel();
    _expediteInternalTimer?.cancel();
    super.dispose();
  }

  void _startInternalExpediteTimer() {
    _expediteInternalTimer?.cancel();
    _expediteInternalTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isFinished && !isSetOver && _activeTimerSeconds == 0) {
        setState(() {
          gameTimeSeconds++;
          if (!expediteActive && gameTimeSeconds >= 600 && (player1Score + player2Score < 18)) {
            _activateExpedite();
          }
        });
      }
    });
  }

  void _activateExpedite() {
    setState(() {
      expediteActive = true;
      logs.add(MatchLogEntry(
        type: 'expedite',
        setNum: setSummaries.length + 1,
        p1Score: player1Score,
        p2Score: player2Score,
      ));
    });
    _persistMatch();
  }

  void _promptWarmup() async {
    bool? startWarmup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Match Ready'),
        content: const Text('Would you like to start the official 2-minute warmup?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Skip Warmup')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start Warmup')),
        ],
      ),
    );
    if (startWarmup == true) _startMatchTimer('Warmup', 120);
  }

  void _startMatchTimer(String title, int seconds) {
    _activeTimer?.cancel();
    setState(() {
      _activeTimerTitle = title;
      _activeTimerSeconds = seconds;
    });
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_activeTimerSeconds > 0) {
        setState(() => _activeTimerSeconds--);
      } else {
        _stopMatchTimer();
      }
    });
  }

  void _stopMatchTimer() {
    _activeTimer?.cancel();
    setState(() {
      _activeTimerSeconds = 0;
      _activeTimerTitle = '';
      if (isSetOver) {
        player1Score = 0;
        player2Score = 0;
        pointHistory = [];
        isSetOver = false;
        gameTimeSeconds = 0; 
      }
    });
    _persistMatch();
  }

  Future<void> _persistMatch() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'p1Name': widget.p1Name,
      'p2Name': widget.p2Name,
      'p1Score': player1Score,
      'p2Score': player2Score,
      'p1Sets': player1Sets,
      'p2Sets': player2Sets,
      'isSetOver': isSetOver,
      'pointHistory': pointHistory,
      'setSummaries': setSummaries.map((s) => s.toMap()).toList(),
      'setsToWin': widget.setsToWin,
      'p1TimeoutUsed': p1TimeoutUsed,
      'p2TimeoutUsed': p2TimeoutUsed,
      'firstServer': firstServerOfMatch,
      'p1OnLeft': p1OnLeftOfMatch,
      'logs': logs.map((p) => p.toMap()).toList(),
      'expediteActive': expediteActive,
      'gameTimeSeconds': gameTimeSeconds,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString('active_tt_match', data);
  }

  Future<void> _clearPersistedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_tt_match');
  }

  void _saveState() {
    _history.add(MatchState(
      p1Score: player1Score,
      p2Score: player2Score,
      p1Sets: player1Sets,
      p2Sets: player2Sets,
      isSetOver: isSetOver,
      pointHistory: List<int>.from(pointHistory),
      setSummaries: List<SetSummary>.from(setSummaries),
      p1TimeoutUsed: p1TimeoutUsed,
      p2TimeoutUsed: p2TimeoutUsed,
      firstServer: firstServerOfMatch,
      p1OnLeft: p1OnLeftOfMatch,
      logs: List<MatchLogEntry>.from(logs),
      expediteActive: expediteActive,
      gameTimeSeconds: gameTimeSeconds,
    ));
    if (_history.length > 50) _history.removeAt(0);
    _persistMatch();
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        final lastState = _history.removeLast();
        player1Score = lastState.p1Score;
        player2Score = lastState.p2Score;
        player1Sets = lastState.p1Sets;
        player2Sets = lastState.p2Sets;
        isSetOver = lastState.isSetOver;
        pointHistory = lastState.pointHistory;
        setSummaries = lastState.setSummaries;
        p1TimeoutUsed = lastState.p1TimeoutUsed;
        p2TimeoutUsed = lastState.p2TimeoutUsed;
        firstServerOfMatch = lastState.firstServer;
        p1OnLeftOfMatch = lastState.p1OnLeft;
        logs = lastState.logs;
        expediteActive = lastState.expediteActive;
        gameTimeSeconds = lastState.gameTimeSeconds;
        _activeTimerSeconds = 0;
        _activeTimerTitle = '';
        _activeTimer?.cancel();
        _checkMatchWinner();
      });
      _persistMatch();
    }
  }

  void _resetMatch() {
    _saveState();
    setState(() {
      player1Score = 0;
      player2Score = 0;
      player1Sets = 0;
      player2Sets = 0;
      isSetOver = false;
      isFinished = false;
      p1TimeoutUsed = false;
      p2TimeoutUsed = false;
      expediteActive = false;
      gameTimeSeconds = 0;
      pointHistory = [];
      setSummaries = [];
      logs = [];
      _activeTimerSeconds = 0;
      _activeTimerTitle = '';
      _activeTimer?.cancel();
      final rand = Random();
      firstServerOfMatch = rand.nextBool() ? 1 : 2;
      p1OnLeftOfMatch = rand.nextBool();
    });
    _persistMatch();
  }

  bool get _isDecider => (player1Sets + player2Sets) == (widget.setsToWin * 2) - 2;

  int get _currentServer {
    int currentSetNum = player1Sets + player2Sets;
    int serverToStartSet = (currentSetNum % 2 == 0) ? firstServerOfMatch : (3 - firstServerOfMatch);
    int totalPointsInSet = player1Score + player2Score;
    if (expediteActive || (player1Score >= 10 && player2Score >= 10)) {
      return (totalPointsInSet % 2 == 0) ? serverToStartSet : (3 - serverToStartSet);
    } else {
      return ((totalPointsInSet ~/ 2) % 2 == 0) ? serverToStartSet : (3 - serverToStartSet);
    }
  }

  String _getPlayerSide(int playerNum) {
    int currentSetNum = player1Sets + player2Sets;
    bool isSetEven = currentSetNum % 2 == 0;
    bool p1OnLeftInSet = isSetEven ? p1OnLeftOfMatch : !p1OnLeftOfMatch;
    bool finalP1OnLeft = p1OnLeftInSet;
    if (_isDecider && (player1Score + player2Score >= 5)) finalP1OnLeft = !p1OnLeftInSet;
    return playerNum == 1 ? (finalP1OnLeft ? 'LEFT' : 'RIGHT') : (finalP1OnLeft ? 'RIGHT' : 'LEFT');
  }

  void _updateScore(int player, int delta) {
    if (isFinished && delta > 0) return;
    _saveState();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      if (isSetOver && delta > 0) _stopMatchTimer();
      if (player == 1) {
        player1Score = (player1Score + delta).clamp(0, 99);
        if (delta > 0) pointHistory.add(1);
        else if (pointHistory.isNotEmpty && pointHistory.last == 1) pointHistory.removeLast();
      } else {
        player2Score = (player2Score + delta).clamp(0, 99);
        if (delta > 0) pointHistory.add(2);
        else if (pointHistory.isNotEmpty && pointHistory.last == 2) pointHistory.removeLast();
      }
      if (delta > 0) {
        if (_isDecider && (player1Score == 5 || player2Score == 5) && (player1Score + player2Score == 5 || (player1Score == 5 && player2Score < 5) || (player2Score == 5 && player1Score < 5))) {
            if ((player1Score == 5 && player2Score < 5) || (player2Score == 5 && player1Score < 5)) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decider: Switch Sides! ↔️'), backgroundColor: Colors.orange, duration: Duration(days: 1)));
            }
        }
        _checkSetWinner();
        int totalPoints = player1Score + player2Score;
        if (totalPoints > 0 && totalPoints % 6 == 0 && !isSetOver) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Towel Break Reminder! 🧻'), duration: Duration(days: 1), backgroundColor: Colors.blueGrey));
        }
      } else {
        isSetOver = false;
        _checkMatchWinner();
      }
    });
    _persistMatch();
  }

  void _useTimeout(int playerNum) {
    _saveState();
    setState(() {
      if (playerNum == 1) p1TimeoutUsed = true; else p2TimeoutUsed = true;
      logs.add(MatchLogEntry(
        type: 'timeout',
        playerNum: playerNum,
        setNum: setSummaries.length + 1,
        p1Score: player1Score,
        p2Score: player2Score,
      ));
    });
    _startMatchTimer('Timeout', 60);
  }

  void _issuePenalty(int playerNum, String type) async {
    final TextEditingController reasonController = TextEditingController();
    final String cardName = type == 'yellow' ? 'Yellow Card' : 'Red Card';

    String? reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Issue $cardName'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason (Optional)', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, reasonController.text.trim()), child: const Text('Confirm')),
        ],
      ),
    );

    if (reason != null) {
      _saveState();
      setState(() {
        int playerPenalties = logs.where((p) => p.type == 'penalty' && p.playerNum == playerNum && p.cardType != 'red-direct').length;
        
        // Record score BEFORE adding penalty points per user preference
        int logP1 = player1Score;
        int logP2 = player2Score;

        String finalCardType = type;
        if (type == 'yellow') {
          if (playerPenalties == 0) finalCardType = 'yellow';
          else if (playerPenalties == 1) { finalCardType = 'yellow-red'; if (playerNum == 1) player2Score++; else player1Score++; }
          else { finalCardType = 'yellow-red-2'; if (playerNum == 1) player2Score += 2; else player1Score += 2; }
          
          if (playerPenalties >= 3) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('REPORT TO REFEREE - SUSPEND PLAY'), backgroundColor: Colors.red, duration: Duration(seconds: 10)));
          }
        } else {
           finalCardType = 'red-direct'; 
           if (playerNum == 1) player2Score++; else player1Score++;
        }

        logs.add(MatchLogEntry(
          type: 'penalty',
          playerNum: playerNum,
          cardType: finalCardType,
          reason: reason.isEmpty ? 'Offense' : reason,
          setNum: setSummaries.length + 1,
          p1Score: logP1,
          p2Score: logP2,
        ));
        _checkSetWinner();
      });
      _persistMatch();
    }
  }

  void _checkSetWinner() {
    if (!isSetOver && (player1Score >= 11 || player2Score >= 11) && (player1Score - player2Score).abs() >= 2) {
      if (player1Score > player2Score) player1Sets++; else player2Sets++;
      isSetOver = true;
      setSummaries.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: List<int>.from(pointHistory), isExpediteSet: expediteActive));
      _checkMatchWinner();
      if (!isFinished) {
         _startMatchTimer('Set Break', 60);
         WidgetsBinding.instance.addPostFrameCallback((_) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch Sides! ↔️'), backgroundColor: Colors.orange, duration: Duration(days: 1)));
         });
      }
    }
  }

  void _checkMatchWinner() { setState(() { isFinished = (player1Sets >= widget.setsToWin || player2Sets >= widget.setsToWin); }); }

  Map<String, dynamic> _calculateStats(int playerNum) {
    int totalPoints = 0, pointsOnServe = 0, servesTotal = 0, longestStreak = 0, currentStreak = 0;
    List<SetSummary> allSets = List.from(setSummaries);
    allSets.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: List<int>.from(pointHistory), isExpediteSet: expediteActive));
    for (int i = 0; i < allSets.length; i++) {
      final set = allSets[i];
      int serverToStartSet = (i % 2 == 0) ? firstServerOfMatch : (3 - firstServerOfMatch);
      int p1Points = 0, p2Points = 0;
      for (int p in set.pointSequence) {
        int totalInSet = p1Points + p2Points;
        int currentServer;
        if (set.isExpediteSet || (p1Points >= 10 && p2Points >= 10)) {
          currentServer = (totalInSet % 2 == 0) ? serverToStartSet : (3 - serverToStartSet);
        } else {
          currentServer = ((totalInSet ~/ 2) % 2 == 0) ? serverToStartSet : (3 - serverToStartSet);
        }
        if (p == playerNum) { totalPoints++; currentStreak++; if (currentStreak > longestStreak) longestStreak = currentStreak; if (currentServer == playerNum) pointsOnServe++; }
        else currentStreak = 0;
        if (currentServer == playerNum) servesTotal++;
        if (p == 1) p1Points++; else p2Points++;
      }
      currentStreak = 0;
    }
    return {'totalPoints': totalPoints, 'serveWinRate': servesTotal > 0 ? (pointsOnServe / servesTotal * 100) : 0.0, 'longestStreak': longestStreak};
  }

  void _showPointLog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        List<SetSummary> allSets = List.from(setSummaries);
        if (pointHistory.isNotEmpty || player1Score > 0 || player2Score > 0) allSets.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: pointHistory, isExpediteSet: expediteActive));
        return Container(
          height: MediaQuery.of(context).size.height * 0.7, padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('Match History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Expanded(child: ListView.builder(itemCount: allSets.length, itemBuilder: (context, setIndex) {
              final set = allSets[setIndex];
              List<int> p1Progress = [], p2Progress = [];
              int curP1 = 0, curP2 = 0;
              for (int p in set.pointSequence) { if (p == 1) curP1++; else curP2++; p1Progress.add(curP1); p2Progress.add(curP2); }
              final setLogs = logs.where((p) => p.setNum == setIndex + 1).toList();
              return ExpansionTile(
                initiallyExpanded: setIndex == allSets.length - 1,
                title: Text('Set ${setIndex + 1}: ${set.p1Score} - ${set.p2Score}', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(set.isExpediteSet ? 'Expedite System Active' : ''),
                children: [
                  if (setLogs.isNotEmpty) ...setLogs.map((entry) {
                     IconData icon = Icons.info; Color color = Colors.blue; String text = '';
                     if (entry.type == 'penalty') {
                        icon = Icons.warning; color = (entry.cardType?.contains('red') ?? false) ? Colors.red : Colors.yellow;
                        text = '${entry.playerNum == 1 ? widget.p1Name : widget.p2Name}: ${entry.reason}';
                     } else if (entry.type == 'timeout') {
                        icon = Icons.timer; color = Colors.blueGrey; text = '${entry.playerNum == 1 ? widget.p1Name : widget.p2Name} called Timeout';
                     } else if (entry.type == 'expedite') {
                        icon = Icons.flash_on; color = Colors.orange; text = 'Expedite System Activated';
                     }
                     return ListTile(dense: true, leading: Icon(icon, color: color), title: Text(text), subtitle: Text('Score: ${entry.p1Score}-${entry.p2Score}'));
                  }),
                  Padding(padding: const EdgeInsets.all(16.0), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildProgressRow(widget.p1Name, p1Progress, 1), const SizedBox(height: 12), _buildProgressRow(widget.p2Name, p2Progress, 2),
                  ]))),
                ],
              );
            })),
          ]),
        );
      },
    );
  }

  Widget _buildProgressRow(String playerName, List<int> scores, int playerNum) {
    return Row(children: [
      SizedBox(width: 80, child: Text(playerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      ...scores.asMap().entries.map((entry) {
        bool pointWon = entry.key == 0 ? entry.value > 0 : entry.value > scores[entry.key - 1];
        return Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(
          color: pointWon ? (playerNum == 1 ? Colors.blue : Colors.green) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4), border: pointWon ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ), child: Center(child: Text('${entry.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pointWon ? Colors.white : Colors.grey))));
      }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final bool p1Won = player1Sets >= widget.setsToWin, p2Won = player2Sets >= widget.setsToWin, isTimerRunning = _activeTimerSeconds > 0;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) { if (didPop && !isFinished) _persistMatch(); },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Table Tennis Match'),
          actions: [
            IconButton(onPressed: () {
              showDialog(context: context, builder: (context) => AlertDialog(
                title: const Text('2026 Match Rules'),
                content: SingleChildScrollView(child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Game: 11 points (win by 2).'),
                    const Text('Cards: 1st=Warning, 2nd=1pt, 3rd=2pts, 4th=Suspend.'),
                    const Text('Expedite: After 10 mins (if score < 18), serve switches every 1 pt. Receiver wins after 13 returns.'),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: () { _activateExpedite(); Navigator.pop(context); }, child: const Text('Force Expedite System'))
                  ],
                )),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ));
            }, icon: const Icon(Icons.info_outline)),
            IconButton(onPressed: _showPointLog, icon: const Icon(Icons.history), tooltip: 'Point history'),
            IconButton(onPressed: _history.isEmpty ? null : _undo, icon: const Icon(Icons.undo)),
            IconButton(onPressed: _resetMatch, icon: const Icon(Icons.refresh)),
          ],
        ),
        body: Column(
          children: [
            if (_activeTimerSeconds > 0)
              Container(color: Colors.blue.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20), child: Row(children: [
                const Icon(Icons.timer, color: Colors.blue), const SizedBox(width: 12),
                Text('${_activeTimerTitle}: ${_activeTimerSeconds ~/ 60}:${(_activeTimerSeconds % 60).toString().padLeft(2, '0')}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                const Spacer(), TextButton(onPressed: _stopMatchTimer, child: const Text('Skip')),
              ])),
            if (expediteActive)
              Container(width: double.infinity, color: Colors.red, padding: const EdgeInsets.symmetric(vertical: 6), child: const Text('!!! EXPEDITE SYSTEM ACTIVE: SERVE EVERY POINT !!!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1))),
            const SizedBox(height: 20),
            Text('First to ${widget.setsToWin} sets', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildPlayerColumn(widget.p1Name, player1Score, player1Sets, 1, p1Won, p1TimeoutUsed, _currentServer == 1, isTimerRunning),
              _buildPlayerColumn(widget.p2Name, player2Score, player2Sets, 2, p2Won, p2TimeoutUsed, _currentServer == 2, isTimerRunning),
            ]),
            const SizedBox(height: 20),
            if (isFinished) ...[_buildStatsSummary(), const SizedBox(height: 20)],
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40.0), child: ElevatedButton(
              onPressed: isFinished ? () async { await _clearPersistedMatch(); if (!context.mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match finished!'))); } : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: isFinished ? Colors.amber : Colors.grey.withValues(alpha: 0.1), disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1), foregroundColor: Colors.white, disabledForegroundColor: Colors.white.withValues(alpha: 0.3), elevation: isFinished ? 8 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(isFinished ? 'CONCLUDE MATCH' : 'Finish Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: isFinished ? 1.2 : 0)),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final s1 = _calculateStats(1), s2 = _calculateStats(2);
    return Container(margin: const EdgeInsets.symmetric(horizontal: 20), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))), child: Column(children: [
      const Text('MATCH STATISTICS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.amber)),
      const SizedBox(height: 20),
      _statsRow('Total Points', '${s1['totalPoints']}', '${s2['totalPoints']}'),
      const Divider(height: 24),
      _statsRow('Longest Streak', '${s1['longestStreak']}', '${s2['longestStreak']}'),
      const Divider(height: 24),
      _statsRow('Win % on Serve', '${s1['serveWinRate'].toStringAsFixed(1)}%', '${s2['serveWinRate'].toStringAsFixed(1)}%'),
    ]));
  }

  Widget _statsRow(String label, String v1, String v2) {
    return Row(children: [
      Expanded(child: Text(v1, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      Expanded(flex: 2, child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(child: Text(v2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    ]);
  }

  Widget _buildPlayerColumn(String name, int score, int sets, int playerNum, bool hasWon, bool timeoutUsed, bool isServing, bool isTimerRunning) {
    final playerPenalties = logs.where((p) => p.type == 'penalty' && p.playerNum == playerNum).toList();
    final hasYellow = playerPenalties.any((p) => p.cardType?.startsWith('yellow') ?? false);
    final hasRed = playerPenalties.any((p) => p.cardType?.contains('red') ?? false);
    return Column(children: [
      SizedBox(width: 150, child: Text(name, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: hasWon ? Colors.amber : null), overflow: TextOverflow.ellipsis)),
      const SizedBox(height: 15),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: hasWon ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: hasWon ? Border.all(color: Colors.amber, width: 1) : null), child: Text('Sets: $sets', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: hasWon ? Colors.amber : Colors.blue))),
      const SizedBox(height: 12),
      Row(mainAxisSize: MainAxisSize.min, children: [
        ElevatedButton(onPressed: (timeoutUsed || isTimerRunning) ? null : () => _useTimeout(playerNum), style: ElevatedButton.styleFrom(backgroundColor: timeoutUsed ? Colors.grey : Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: const Size(60, 30)), child: const Text('T/O', style: TextStyle(fontSize: 10))),
        const SizedBox(width: 8),
        GestureDetector(onTap: isTimerRunning ? null : () => _issuePenalty(playerNum, 'yellow'), child: Container(width: 20, height: 30, decoration: BoxDecoration(color: hasYellow ? Colors.yellow : Colors.yellow.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.yellow, width: 1)))),
        const SizedBox(width: 4),
        GestureDetector(onTap: isTimerRunning ? null : () => _issuePenalty(playerNum, 'red'), child: Container(width: 20, height: 30, decoration: BoxDecoration(color: hasRed ? Colors.red : Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.red, width: 1)))),
      ]),
      const SizedBox(height: 15),
      Column(children: [
        GestureDetector(onTap: isTimerRunning ? null : () => _updateScore(playerNum, 1), child: Container(width: 140, height: 140, decoration: BoxDecoration(color: hasWon ? Colors.amber.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05), shape: BoxShape.circle, border: Border.all(color: isServing ? Colors.white : (hasWon ? Colors.amber : (isFinished || isTimerRunning ? Colors.white.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.5))), width: 4), boxShadow: [if (hasWon) BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 5), if (isServing && !isFinished && !isTimerRunning) BoxShadow(color: Colors.white.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 5)]), child: Center(child: Text('$score', style: TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: hasWon ? Colors.amber : (isFinished || isTimerRunning ? Colors.white.withValues(alpha: 0.1) : null)))))),
      ]),
      const SizedBox(height: 8),
      if (isServing && !isFinished) const Text('SERVING', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12)),
      const SizedBox(height: 4),
      Text('SIDE: ${_getPlayerSide(playerNum)}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }
}
