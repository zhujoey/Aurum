import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'tt_models.dart';
import 'widgets/tt_banners.dart';
import 'widgets/tt_history.dart';
import 'widgets/tt_stats.dart';
import 'widgets/tt_team_column.dart';

class TableTennisMatch extends StatefulWidget {
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;
  final bool isDoubles;
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
  final bool initialP1OnLeft;
  final List<MatchLogEntry> initialLogs;
  final bool initialExpediteActive;
  final int initialGameTimeSeconds;
  final int activeTimerSeconds;
  final String activeTimerTitle;
  final int? initialTimerEndTime;
  final int initialFirstServerOfMatch;
  final int initialFirstServerOfSet;
  final int initialFirstReceiverOfSet;
  final String matchId;
  final bool? isHost;

  const TableTennisMatch({
    super.key, 
    required this.p1Name, 
    required this.p2Name,
    this.p3Name = '',
    this.p4Name = '',
    this.isDoubles = false,
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
    this.initialFirstServerOfMatch = 0,
    this.initialFirstServerOfSet = 0,
    this.initialFirstReceiverOfSet = 0,
    this.initialP1OnLeft = true,
    this.initialLogs = const [],
    this.initialExpediteActive = false,
    this.initialGameTimeSeconds = 0,
    this.activeTimerSeconds = 0,
    this.activeTimerTitle = '',
    this.initialTimerEndTime,
    this.matchId = '',
    this.isHost,
  });

  @override
  State<TableTennisMatch> createState() => _TableTennisMatchState();
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
  late int firstServerOfSet;
  late int firstReceiverOfSet;
  int _activeTimerSeconds = 0;
  String _activeTimerTitle = '';
  int? _timerEndTime;
  Timer? _activeTimer;
  
  bool expediteActive = false;
  int gameTimeSeconds = 0;
  Timer? _expediteInternalTimer;
  StreamSubscription? _matchSubscription;
  final AuthService _authService = AuthService();
  bool _isHost = true;
  
  final List<MatchState> _history = [];

  @override
  void initState() {
    super.initState();
    _isHost = widget.isHost ?? widget.matchId.isEmpty;
    player1Score = widget.initialP1Score;
    player2Score = widget.initialP2Score;
    player1Sets = widget.initialP1Sets;
    player2Sets = widget.initialP2Sets;
    isSetOver = widget.initialIsSetOver;
    pointHistory = List<int>.from(widget.initialPointHistory);
    setSummaries = List<SetSummary>.from(widget.initialSetSummaries);
    p1TimeoutUsed = widget.initialP1TimeoutUsed;
    p2TimeoutUsed = widget.initialP2TimeoutUsed;
    firstServerOfMatch = widget.initialFirstServerOfMatch;
    p1OnLeftOfMatch = widget.initialP1OnLeft;
    firstServerOfSet = widget.initialFirstServerOfSet;
    firstReceiverOfSet = widget.initialFirstReceiverOfSet;
    logs = List<MatchLogEntry>.from(widget.initialLogs);
    expediteActive = widget.initialExpediteActive;
    gameTimeSeconds = widget.initialGameTimeSeconds;
    
    _activeTimerSeconds = widget.activeTimerSeconds;
    _activeTimerTitle = widget.activeTimerTitle;
    _timerEndTime = widget.initialTimerEndTime;

    _checkMatchWinner();
    _startInternalExpediteTimer();
    _listenToMatchStatus();
    
    if (_timerEndTime != null) {
      _startLocalTimerFromEndTime(_activeTimerTitle, _timerEndTime!);
    } else if (_activeTimerSeconds > 0) {
      _startMatchTimer(_activeTimerTitle, _activeTimerSeconds);
    }
    
    _persistMatch();

    if (firstServerOfMatch == 0 && _activeTimerSeconds == 0) {
      p1OnLeftOfMatch = Random().nextBool();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || isFinished || _isAnySuspended) return;
        // Wait a bit to ensure _isHost is determined for cloud matches
        if (widget.matchId.isNotEmpty) {
           await Future.delayed(const Duration(milliseconds: 1000));
        }
        if (!mounted || isFinished || _isAnySuspended) return;
        
        if (_isHost) {
          await _promptTossWinner();
          if (!mounted || isFinished || _isAnySuspended) return;
          _promptWarmup();
        }
      });
    }
  }

  @override
  void dispose() {
    _matchSubscription?.cancel();
    _activeTimer?.cancel();
    _expediteInternalTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();
    super.dispose();
  }

  void _listenToMatchStatus() {
    if (widget.matchId.isEmpty) return;
    _matchSubscription = FirebaseFirestore.instance
        .collection('active_matches')
        .doc(widget.matchId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        String status = doc.get('status') ?? 'playing';
        
        // Determine host status
        final cloudHostUid = doc.get('hostUid');
        final currentUid = _authService.currentUser?.uid;
        _isHost = cloudHostUid == currentUid;

        if (status == 'forfeited' && !isFinished) {
          setState(() {
            isFinished = true;
          });
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Match Ended'),
              content: const Text('A participant has forfeited the match.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }

        // If we are NOT the host, sync score and state from cloud
        if (!_isHost) {
          final matchData = doc.data()?['matchData'] ?? {};
          if (matchData.isNotEmpty) {
            _syncFromCloud(matchData);
          }
        }
      } else {
        // Document was deleted (match ended or discarded by host)
        if (!_isHost && mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Match ended by host.')),
          );
        }
      }
    });
  }

  void _syncFromCloud(Map<String, dynamic> data) {
    int cloudP1Score = data['p1Score'] ?? player1Score;
    int cloudP2Score = data['p2Score'] ?? player2Score;
    int cloudP1Sets = data['p1Sets'] ?? player1Sets;
    int cloudP2Sets = data['p2Sets'] ?? player2Sets;
    bool cloudIsSetOver = data['isSetOver'] ?? isSetOver;

    int localTotal = player1Score + player2Score;
    int cloudTotal = cloudP1Score + cloudP2Score;
    int localSetsTotal = player1Sets + player2Sets;
    int cloudSetsTotal = cloudP1Sets + cloudP2Sets;

    // A match "progressed" if a point was scored or a set ended
    bool matchProgressed = cloudTotal > localTotal || cloudSetsTotal > localSetsTotal || (cloudIsSetOver && !isSetOver);

    // Only hide current reminders if the match actually moved to a new state
    if (matchProgressed && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    setState(() {
      player1Score = cloudP1Score;
      player2Score = cloudP2Score;
      player1Sets = cloudP1Sets;
      player2Sets = cloudP2Sets;
      isSetOver = cloudIsSetOver;
      
      p1TimeoutUsed = data['p1TimeoutUsed'] ?? p1TimeoutUsed;
      p2TimeoutUsed = data['p2TimeoutUsed'] ?? p2TimeoutUsed;
      expediteActive = data['expediteActive'] ?? expediteActive;
      gameTimeSeconds = data['gameTimeSeconds'] ?? gameTimeSeconds;
      
      firstServerOfSet = data['firstServerOfSet'] ?? firstServerOfSet;
      firstReceiverOfSet = data['firstReceiverOfSet'] ?? firstReceiverOfSet;

      String newTitle = data['activeTimerTitle'] ?? '';
      int? newEndTime = data['timerEndTime'];
      
      if (newEndTime != null && newEndTime != _timerEndTime) {
         _timerEndTime = newEndTime;
         _activeTimerTitle = newTitle;
         _startLocalTimerFromEndTime(newTitle, newEndTime);
      } else if (newEndTime == null && _timerEndTime != null) {
         _stopMatchTimer();
      }
      
      // Reminders for non-hosts (stay until next point is synced)
      if (!_isHost && matchProgressed) {
        // 1. Towel break (every 6 points)
        if (cloudTotal % 6 == 0 && !isSetOver && cloudTotal > 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Towel Break Reminder! 🧻'), 
            duration: Duration(minutes: 30), 
            backgroundColor: Colors.blueGrey
          ));
        }
        
        // 2. Side switch in Decider (at 5 points)
        if (_isDecider && (player1Score == 5 || player2Score == 5)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Decider: Switch Sides! ↔️'), 
            backgroundColor: Colors.orange, 
            duration: Duration(minutes: 30)
          ));
        }

        // 3. Side switch at end of set
        if (isSetOver && !isFinished) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Switch Sides! ↔️'), 
            backgroundColor: Colors.orange, 
            duration: Duration(minutes: 30)
          ));
        }
      }

      // Update history and summaries for participants
      if (data['pointHistory'] != null) {
        pointHistory = List<int>.from(data['pointHistory']);
      }
      if (data['setSummaries'] != null) {
        setSummaries = (data['setSummaries'] as List)
            .map((s) => SetSummary.fromMap(s))
            .toList();
      }
      
      // Update logs if provided
      if (data['logs'] != null) {
        logs = (data['logs'] as List).map((p) => MatchLogEntry.fromMap(p)).toList();
      }
      
      _checkMatchWinner();
    });
  }

  void _startLocalTimerFromEndTime(String title, int endTime) {
    _activeTimer?.cancel();
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      int now = DateTime.now().millisecondsSinceEpoch;
      int remaining = ((endTime - now) / 1000).round();
      if (remaining > 0) {
        setState(() => _activeTimerSeconds = remaining);
      } else {
        _stopMatchTimer();
      }
    });
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
    if (isFinished || _isAnySuspended) return;

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
    int endTime = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    setState(() {
      _activeTimerTitle = title;
      _activeTimerSeconds = seconds;
      _timerEndTime = endTime;
    });
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      int now = DateTime.now().millisecondsSinceEpoch;
      int remaining = ((endTime - now) / 1000).round();
      if (remaining > 0) {
        setState(() => _activeTimerSeconds = remaining);
      } else {
        _stopMatchTimer();
      }
    });
    if (_isHost) _persistMatch();
  }

  void _stopMatchTimer() {
    _activeTimer?.cancel();
    bool wasSetOver = isSetOver;
    setState(() {
      _activeTimerSeconds = 0;
      _activeTimerTitle = '';
      _timerEndTime = null;
      if (_isHost && wasSetOver) {
        player1Score = 0;
        player2Score = 0;
        pointHistory = [];
        isSetOver = false;
        gameTimeSeconds = 0; 
        
        int servingTeam = ((player1Sets + player2Sets) % 2 == 0) ? (firstServerOfMatch <= 2 ? 1 : 2) : (firstServerOfMatch <= 2 ? 2 : 1);
        _selectServerAndReceiver(servingTeam, isFirstGame: false);
      }
    });
    if (_isHost) _persistMatch();
  }

  Future<void> _pushMatchDataToCloud() async {
    if (widget.matchId.isEmpty || !_isHost) return;

    try {
      await FirebaseFirestore.instance
          .collection('active_matches')
          .doc(widget.matchId)
          .update({
        'matchData': {
          'p1Name': widget.p1Name,
          'p2Name': widget.p2Name,
          'p3Name': widget.p3Name,
          'p4Name': widget.p4Name,
          'isDoubles': widget.isDoubles,
          'p1Score': player1Score,
          'p2Score': player2Score,
          'p1Sets': player1Sets,
          'p2Sets': player2Sets,
          'isSetOver': isSetOver,
          'setsToWin': widget.setsToWin,
          'p1TimeoutUsed': p1TimeoutUsed,
          'p2TimeoutUsed': p2TimeoutUsed,
          'expediteActive': expediteActive,
          'gameTimeSeconds': gameTimeSeconds,
          'activeTimerSeconds': _activeTimerSeconds,
          'activeTimerTitle': _activeTimerTitle,
          'timerEndTime': _timerEndTime,
          'firstServerOfSet': firstServerOfSet,
          'firstReceiverOfSet': firstReceiverOfSet,
          'pointHistory': pointHistory,
          'setSummaries': setSummaries.map((s) => s.toMap()).toList(),
          'logs': logs.map((p) => p.toMap()).toList(),
        },
        'lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error pushing match data to cloud: $e");
    }
  }

  Future<void> _persistMatch() async {
    // Local persistence
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'p1Name': widget.p1Name,
      'p2Name': widget.p2Name,
      'p3Name': widget.p3Name,
      'p4Name': widget.p4Name,
      'isDoubles': widget.isDoubles,
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
      'firstServerOfMatch': firstServerOfMatch,
      'firstServerOfSet': firstServerOfSet,
      'firstReceiverOfSet': firstReceiverOfSet,
      'p1OnLeft': p1OnLeftOfMatch,
      'logs': logs.map((p) => p.toMap()).toList(),
      'expediteActive': expediteActive,
      'gameTimeSeconds': gameTimeSeconds,
      'activeTimerSeconds': _activeTimerSeconds,
      'activeTimerTitle': _activeTimerTitle,
      'timerEndTime': _timerEndTime,
      'matchId': widget.matchId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString('active_tt_match', data);

    // Cloud persistence (if host)
    if (_isHost) {
      _pushMatchDataToCloud();
    }
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
      firstServerOfMatch: firstServerOfMatch,
      firstServerOfSet: firstServerOfSet,
      firstReceiverOfSet: firstReceiverOfSet,
      p1OnLeft: p1OnLeftOfMatch,
      logs: List<MatchLogEntry>.from(logs),
      expediteActive: expediteActive,
      gameTimeSeconds: gameTimeSeconds,
      activeTimerSeconds: _activeTimerSeconds,
      activeTimerTitle: _activeTimerTitle,
    ));
    if (_history.length > 50) _history.removeAt(0);
    _persistMatch();
  }

  Future<void> _promptTossWinner() async {
    if (isFinished || _isAnySuspended) return;

    int tossWinnerTeam = Random().nextBool() ? 1 : 2;
    String winnerDisplay = widget.isDoubles 
        ? "Team $tossWinnerTeam" 
        : (tossWinnerTeam == 1 ? widget.p1Name : widget.p3Name);
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Coin Toss Result'),
        content: Text('$winnerDisplay won the toss!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continue')),
        ],
      ),
    );
    await _promptInitialServiceChoice(tossWinnerTeam);
  }

  Future<void> _promptInitialServiceChoice(int tossWinnerTeam) async {
    if (isFinished || _isAnySuspended) return;
    String winnerDisplay = widget.isDoubles 
        ? "Team $tossWinnerTeam" 
        : (tossWinnerTeam == 1 ? widget.p1Name : widget.p3Name);
    
    String loserDisplay = widget.isDoubles
        ? "Team ${3 - tossWinnerTeam}"
        : (tossWinnerTeam == 1 ? widget.p3Name : widget.p1Name);

    int? winnerAction = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$winnerDisplay won the toss!'),
        content: const Text('What would you like to do?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Choose Service')),
          TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Choose Side')),
          TextButton(onPressed: () => Navigator.pop(context, 3), child: const Text('Let Opponent Choose')),
        ],
      ),
    );

    int servingTeam = 1;
    bool p1StartsLeft = true;

    if (winnerAction == 3) {
      int? loserAction = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$loserDisplay: Opponent deferred to you!'),
          content: const Text('What would you like to choose?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Choose Service')),
            TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Choose Side')),
          ],
        ),
      );
      
      if (loserAction == 1) {
        servingTeam = await _pickService(3 - tossWinnerTeam, loserDisplay);
        p1StartsLeft = await _pickSide(tossWinnerTeam, winnerDisplay);
      } else {
        p1StartsLeft = await _pickSide(3 - tossWinnerTeam, loserDisplay);
        servingTeam = await _pickService(tossWinnerTeam, winnerDisplay);
      }
    } else if (winnerAction == 1) {
      servingTeam = await _pickService(tossWinnerTeam, winnerDisplay);
      p1StartsLeft = await _pickSide(3 - tossWinnerTeam, loserDisplay);
    } else {
      p1StartsLeft = await _pickSide(tossWinnerTeam, winnerDisplay);
      servingTeam = await _pickService(3 - tossWinnerTeam, loserDisplay);
    }

    setState(() {
      p1OnLeftOfMatch = p1StartsLeft;
    });
    
    await _selectServerAndReceiver(servingTeam, isFirstGame: true);
  }

  Future<int> _pickService(int choosingTeam, String display) async {
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$display: Serve or Receive?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Serve First')),
          TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Receive First')),
        ],
      ),
    );
    return (choice == 1) ? choosingTeam : (3 - choosingTeam);
  }

  Future<bool> _pickSide(int choosingTeam, String display) async {
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$display: Which side to start at?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Left Side')),
          TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Right Side')),
        ],
      ),
    );
    bool choosingIsTeam1 = choosingTeam == 1;
    return (choice == 1) ? choosingIsTeam1 : !choosingIsTeam1;
  }

  Future<void> _selectServerAndReceiver(int servingTeam, {required bool isFirstGame}) async {
    if (isFinished || _isAnySuspended) return;
    _saveState();
    int? server;
    String teamDisplay = widget.isDoubles ? "Team $servingTeam" : (servingTeam == 1 ? widget.p1Name : widget.p3Name);

    if (widget.isDoubles) {
      server = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$teamDisplay: Select Server'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, servingTeam == 1 ? 1 : 3), child: Text(servingTeam == 1 ? widget.p1Name : widget.p3Name)),
            TextButton(onPressed: () => Navigator.pop(context, servingTeam == 1 ? 2 : 4), child: Text(servingTeam == 1 ? widget.p2Name : widget.p4Name)),
          ],
        ),
      );
      
      if (server != null) {
        int receiver;
        if (isFirstGame) {
          int receivingTeam = 3 - servingTeam;
          String rTeamDisplay = "Team $receivingTeam";
          receiver = await showDialog<int>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('$rTeamDisplay: Select Receiver'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, receivingTeam == 1 ? 1 : 3), child: Text(receivingTeam == 1 ? widget.p1Name : widget.p3Name)),
                TextButton(onPressed: () => Navigator.pop(context, receivingTeam == 1 ? 2 : 4), child: Text(receivingTeam == 1 ? widget.p2Name : widget.p4Name)),
              ],
            ),
          ) ?? (receivingTeam == 1 ? 1 : 3);
        } else {
          receiver = _getAutomaticReceiver(server);
        }
        
        setState(() {
          if (isFirstGame) firstServerOfMatch = server!;
          firstServerOfSet = server!;
          firstReceiverOfSet = receiver;
        });
      }
    } else {
      setState(() {
        int s = servingTeam == 1 ? 1 : 2;
        if (isFirstGame) firstServerOfMatch = s;
        firstServerOfSet = s;
        firstReceiverOfSet = 0;
      });
    }
    _persistMatch();
  }

  int _getAutomaticReceiver(int server) {
    if (setSummaries.isEmpty) return (server <= 2 ? 3 : 1);
    final lastSet = setSummaries.last;
    List<int> rotation = TTRotationLogic.calculateRotation(lastSet.firstServer, lastSet.firstReceiver, widget.isDoubles, (setSummaries.length == (widget.setsToWin * 2) - 2), lastSet.p1Score, lastSet.p2Score);
    int idx = rotation.indexOf(server);
    int serverToChosenServerIdx = (idx - 1 + 4) % 4;
    return rotation[serverToChosenServerIdx];
  }

  bool get _isDecider => (player1Sets + player2Sets) == (widget.setsToWin * 2) - 2;

  int get _currentServer {
    int totalPoints = player1Score + player2Score;
    List<int> rotation = TTRotationLogic.calculateRotation(firstServerOfSet, firstReceiverOfSet, widget.isDoubles, _isDecider, player1Score, player2Score);
    int stintSize = (expediteActive || (player1Score >= 10 && player2Score >= 10)) ? 1 : 2;
    int rotationIdx = (totalPoints ~/ stintSize) % (widget.isDoubles ? 4 : 2);
    return rotation[rotationIdx];
  }

  int get _currentReceiver {
    if (!widget.isDoubles) return 0;
    int totalPoints = player1Score + player2Score;
    List<int> rotation = TTRotationLogic.calculateRotation(firstServerOfSet, firstReceiverOfSet, widget.isDoubles, _isDecider, player1Score, player2Score);
    int stintSize = (expediteActive || (player1Score >= 10 && player2Score >= 10)) ? 1 : 2;
    int nextIdx = ((totalPoints ~/ stintSize) + 1) % 4;
    return rotation[nextIdx];
  }

  String _getPlayerSide(int playerNum) {
    int currentSetNum = player1Sets + player2Sets;
    bool isSetEven = currentSetNum % 2 == 0;
    bool p1OnLeftInSet = isSetEven ? p1OnLeftOfMatch : !p1OnLeftOfMatch;
    bool finalP1OnLeft = p1OnLeftInSet;
    if (_isDecider && (player1Score >= 5 || player2Score >= 5)) finalP1OnLeft = !p1OnLeftInSet;
    bool isTeam1 = widget.isDoubles ? (playerNum == 1 || playerNum == 2) : (playerNum == 1);
    return isTeam1 ? (finalP1OnLeft ? 'LEFT' : 'RIGHT') : (finalP1OnLeft ? 'RIGHT' : 'LEFT');
  }

  void _updateScore(int teamNum, int delta, {bool isPenalty = false}) {
    if (isFinished && delta > 0) return;
    if (!isPenalty) _saveState();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      if (isSetOver && delta > 0) _stopMatchTimer();
      if (teamNum == 1) {
        player1Score = (player1Score + delta).clamp(0, 99);
        if (delta > 0) { for (int i = 0; i < delta; i++) pointHistory.add(1); }
        else if (pointHistory.isNotEmpty && pointHistory.last == 1) { pointHistory.removeLast(); }
      } else {
        player2Score = (player2Score + delta).clamp(0, 99);
        if (delta > 0) { for (int i = 0; i < delta; i++) pointHistory.add(2); }
        else if (pointHistory.isNotEmpty && pointHistory.last == 2) { pointHistory.removeLast(); }
      }
      if (delta > 0) {
        if (_isDecider && (player1Score == 5 || player2Score == 5)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Decider: Switch Sides! ↔️'), 
            backgroundColor: Colors.orange, 
            duration: Duration(minutes: 30)
          ));
        }
        _checkSetWinner();
        int totalPoints = player1Score + player2Score;
        if (totalPoints > 0 && totalPoints % 6 == 0 && !isSetOver) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Towel Break Reminder! 🧻'), 
            duration: Duration(minutes: 30), 
            backgroundColor: Colors.blueGrey
          ));
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
      if (playerNum == 1 || playerNum == 2) p1TimeoutUsed = true; else p2TimeoutUsed = true;
      logs.add(MatchLogEntry(type: 'timeout', playerNum: playerNum, setNum: setSummaries.length + 1, p1Score: player1Score, p2Score: player2Score));
    });
    _startMatchTimer('Timeout', 60);
  }

  void _issuePenalty(int playerNum, String type) async {
    final TextEditingController reasonController = TextEditingController();
    int actualPlayerNum = playerNum;
    int teamNum = widget.isDoubles ? (playerNum <= 2 ? 1 : 2) : (playerNum == 1 ? 1 : 2);

    if (widget.isDoubles) {
      int? selected = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Which player?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(title: Text(teamNum == 1 ? widget.p1Name : widget.p3Name), onTap: () => Navigator.pop(context, teamNum == 1 ? 1 : 3)),
            ListTile(title: Text(teamNum == 1 ? widget.p2Name : widget.p4Name), onTap: () => Navigator.pop(context, teamNum == 1 ? 2 : 4)),
          ]),
        ),
      );
      if (selected == null) return;
      actualPlayerNum = selected;
    }

    int teamPenalties = logs.where((p) => p.type == 'penalty' && ((teamNum == 1 && (widget.isDoubles ? (p.playerNum == 1 || p.playerNum == 2) : p.playerNum == 1)) || (teamNum == 2 && (widget.isDoubles ? (p.playerNum == 3 || p.playerNum == 4) : p.playerNum == 2)))).length;
    if (teamPenalties >= 4) return;

    String cardName = teamPenalties == 0 ? 'Yellow Card (Warning)' : teamPenalties == 1 ? 'Yellow + Red Card (+1 point)' : teamPenalties == 2 ? 'Yellow + Red Card (+2 points)' : 'Red Card (Suspension Warning)';
    String? reason = await showDialog<String>(context: context, builder: (context) => AlertDialog(title: Text('Issue $cardName'), content: TextField(controller: reasonController, decoration: const InputDecoration(hintText: 'Reason (Optional)', border: OutlineInputBorder()), autofocus: true), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(context, reasonController.text.trim()), child: const Text('Confirm'))]));

    if (reason != null) {
      _saveState();
      setState(() {
        int logP1 = player1Score; int logP2 = player2Score;
        String finalCardType = '';
        if (teamPenalties == 0) { finalCardType = 'yellow'; } 
        else if (teamPenalties == 1) { finalCardType = 'yellow-red-1'; _updateScore(teamNum == 1 ? 2 : 1, 1, isPenalty: true); } 
        else if (teamPenalties == 2) { finalCardType = 'yellow-red-2'; _updateScore(teamNum == 1 ? 2 : 1, 2, isPenalty: true); } 
        else { finalCardType = 'red-suspension'; }
        logs.add(MatchLogEntry(type: 'penalty', playerNum: actualPlayerNum, cardType: finalCardType, reason: reason.isEmpty ? 'Offense' : reason, setNum: setSummaries.length + 1, p1Score: logP1, p2Score: logP2));
      });
      _persistMatch();
    }
  }

  void _checkSetWinner() {
    if (!isSetOver && (player1Score >= 11 || player2Score >= 11) && (player1Score - player2Score).abs() >= 2) {
      if (player1Score > player2Score) player1Sets++; else player2Sets++;
      isSetOver = true;
      setSummaries.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: List<int>.from(pointHistory), isExpediteSet: expediteActive, firstServer: firstServerOfSet, firstReceiver: firstReceiverOfSet));
      _checkMatchWinner();
      if (!isFinished) {
         _startMatchTimer('Set Break', 60);
         WidgetsBinding.instance.addPostFrameCallback((_) { 
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
             content: Text('Switch Sides! ↔️'), 
             backgroundColor: Colors.orange, 
             duration: Duration(minutes: 30)
           )); 
         });
      }
    }
  }

  void _checkMatchWinner() { setState(() { isFinished = (player1Sets >= widget.setsToWin || player2Sets >= widget.setsToWin); }); }

  bool get _isAnySuspended => logs.any((p) => p.type == 'penalty' && p.cardType == 'red-suspension');

  Map<String, dynamic> _calculateStats(int teamNum) {
    int totalPoints = 0, pointsOnServe = 0, servesTotal = 0, longestStreak = 0, currentStreak = 0;
    bool isCalcTeam1 = teamNum == 1;
    List<SetSummary> allSets = List.from(setSummaries);
    if (pointHistory.isNotEmpty || player1Score > 0 || player2Score > 0) { 
      allSets.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: List<int>.from(pointHistory), isExpediteSet: expediteActive, firstServer: firstServerOfSet, firstReceiver: firstReceiverOfSet)); 
    }
    for (int i = 0; i < allSets.length; i++) {
      final set = allSets[i]; int p1Points = 0, p2Points = 0;
      for (int p in set.pointSequence) {
        int totalInSet = p1Points + p2Points;
        List<int> rotation = TTRotationLogic.calculateRotation(set.firstServer, set.firstReceiver, widget.isDoubles, (i == (widget.setsToWin * 2) - 2), p1Points, p2Points);
        int stintSize = (set.isExpediteSet || (p1Points >= 10 && p2Points >= 10)) ? 1 : 2;
        int currentServer = rotation[(totalInSet ~/ stintSize) % (widget.isDoubles ? 4 : 2)];
        
        bool isServerTeam1 = widget.isDoubles ? (currentServer <= 2) : (currentServer == 1);
        bool pointWonByTeam1 = (p == 1);
        bool calcTeamWonPoint = (isCalcTeam1 == pointWonByTeam1);
        bool calcTeamIsServing = (isCalcTeam1 == isServerTeam1);

        if (calcTeamWonPoint) {
           totalPoints++; 
           currentStreak++; 
           if (currentStreak > longestStreak) longestStreak = currentStreak; 
           if (calcTeamIsServing) pointsOnServe++; 
        } else { 
          currentStreak = 0; 
        }
        
        if (calcTeamIsServing) servesTotal++;
        if (p == 1) p1Points++; else p2Points++;
      }
      currentStreak = 0;
    }
    return {'totalPoints': totalPoints, 'serveWinRate': servesTotal > 0 ? (pointsOnServe / servesTotal * 100) : 0.0, 'longestStreak': longestStreak};
  }

  void _undo() {
    if (_history.isNotEmpty) {
      setState(() {
        final lastState = _history.removeLast();
        player1Score = lastState.p1Score; player2Score = lastState.p2Score; player1Sets = lastState.p1Sets; player2Sets = lastState.p2Sets; isSetOver = lastState.isSetOver; pointHistory = lastState.pointHistory;         setSummaries = lastState.setSummaries;
        p1TimeoutUsed = lastState.p1TimeoutUsed;
        p2TimeoutUsed = lastState.p2TimeoutUsed;
        firstServerOfMatch = lastState.firstServerOfMatch;
        firstServerOfSet = lastState.firstServerOfSet;
        firstReceiverOfSet = lastState.firstReceiverOfSet;
        p1OnLeftOfMatch = lastState.p1OnLeft;
        logs = lastState.logs;
 expediteActive = lastState.expediteActive; gameTimeSeconds = lastState.gameTimeSeconds; _activeTimerSeconds = lastState.activeTimerSeconds; _activeTimerTitle = lastState.activeTimerTitle;
        _activeTimer?.cancel(); if (_activeTimerSeconds > 0) { _startMatchTimer(_activeTimerTitle, _activeTimerSeconds); }
        _checkMatchWinner();
        if (firstServerOfMatch == 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _promptTossWinner());
        }
      });
      _persistMatch();
    }
  }

  void _resetMatch() {
    _saveState();
    setState(() {
      player1Score = 0; player2Score = 0; player1Sets = 0; player2Sets = 0; isSetOver = false; isFinished = false; p1TimeoutUsed = false; p2TimeoutUsed = false; expediteActive = false; gameTimeSeconds = 0; pointHistory = []; setSummaries = []; logs = []; _activeTimerSeconds = 0; _activeTimerTitle = ''; _activeTimer?.cancel(); p1OnLeftOfMatch = Random().nextBool();
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptTossWinner());
    });
    _persistMatch();
  }

  @override
  Widget build(BuildContext context) {
    final bool p1Won = player1Sets >= widget.setsToWin, p2Won = player2Sets >= widget.setsToWin;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) { 
        ScaffoldMessenger.of(context).clearSnackBars();
        if (didPop && !isFinished) _persistMatch();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Table Tennis Match'),
          actions: [
            IconButton(onPressed: () {
              showDialog(context: context, builder: (context) => AlertDialog(
                title: const Text('Match Rules'),
                content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Game: 11 points (win by 2).'),
                    const Text('Cards: 1st=Warning, 2nd=1pt, 3rd=2pts, 4th=Suspend.'),
                    const Text('Expedite: After 10 mins (if score < 18), serve switches every 1 pt. Receiver wins after 13 returns.'),
                    const SizedBox(height: 16),
                    if (_isHost)
                      ElevatedButton(onPressed: () { _activateExpedite(); Navigator.pop(context); }, child: const Text('Force Expedite System'))
                ])),
                actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
              ));
            }, icon: const Icon(Icons.info_outline)),
            IconButton(onPressed: () { showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
              List<SetSummary> allSets = List.from(setSummaries);
              if (pointHistory.isNotEmpty || player1Score > 0 || player2Score > 0) allSets.add(SetSummary(p1Score: player1Score, p2Score: player2Score, pointSequence: pointHistory, isExpediteSet: expediteActive, firstServer: firstServerOfSet, firstReceiver: firstReceiverOfSet));
              return MatchHistoryBottomSheet(allSets: allSets, logs: logs, p1Name: widget.p1Name, p2Name: widget.p2Name, p3Name: widget.p3Name, p4Name: widget.p4Name);
            }); }, icon: const Icon(Icons.history), tooltip: 'Point history'),
            IconButton(onPressed: (!_isHost || _history.isEmpty) ? null : _undo, icon: const Icon(Icons.undo)),
            IconButton(onPressed: _isHost ? _resetMatch : null, icon: const Icon(Icons.refresh)),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'discard') {
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
                    if (widget.matchId.isNotEmpty) {
                      await _authService.deleteActiveMatch(widget.matchId);
                    }
                    await _clearPersistedMatch();
                    if (mounted) Navigator.pop(context);
                  }
                } else if (value == 'forfeit') {
                  bool? confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Forfeit Match?'),
                      content: const Text('You will be marked as forfeited and this match will end for everyone. This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Forfeit', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (widget.matchId.isNotEmpty) {
                      await _authService.updateMatchStatus(widget.matchId, 'forfeited');
                    }
                    if (mounted) Navigator.pop(context);
                  }
                }
              },
              itemBuilder: (context) => [
                if (_isHost)
                  const PopupMenuItem(value: 'discard', child: Text('Discard Match', style: TextStyle(color: Colors.red))),
                if (!_isHost)
                  const PopupMenuItem(value: 'forfeit', child: Text('Forfeit Match', style: TextStyle(color: Colors.red))),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(children: [
            SuspensionBanner(logs: logs, isDoubles: widget.isDoubles, p1Name: widget.p1Name, p3Name: widget.p3Name),
            if (_activeTimerSeconds > 0) TimerBanner(title: _activeTimerTitle, seconds: _activeTimerSeconds, onSkip: _isHost ? _stopMatchTimer : null),
            if (expediteActive) const ExpediteBanner(),
            const SizedBox(height: 20),
            Text('First to ${widget.setsToWin} sets', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildTeamCol(1, p1Won, p1TimeoutUsed),
              _buildTeamCol(2, p2Won, p2TimeoutUsed),
            ])),
            const SizedBox(height: 30),
            if (isFinished || _isAnySuspended) ...[MatchStatsSummary(s1: _calculateStats(1), s2: _calculateStats(2)), const SizedBox(height: 20)],
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40.0), child: ElevatedButton(
              onPressed: (isFinished || _isAnySuspended) ? () async { 
                if (widget.matchId.isNotEmpty && _isHost) {
                  await _authService.deleteActiveMatch(widget.matchId);
                }
                await _clearPersistedMatch(); 
                if (!context.mounted) return; 
                Navigator.pop(context); 
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isAnySuspended ? 'Match concluded and data cleared.' : 'Match finished and data cleared.')));
              } : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: (isFinished || _isAnySuspended) ? Colors.amber : Colors.grey.withValues(alpha: 0.1), disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1), foregroundColor: Colors.white, disabledForegroundColor: Colors.white.withValues(alpha: 0.3), elevation: (isFinished || _isAnySuspended) ? 8 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text((isFinished || _isAnySuspended) ? 'CONCLUDE MATCH' : 'Finish Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: (isFinished || _isAnySuspended) ? 1.2 : 0)),
            )),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _buildTeamCol(int teamNum, bool hasWon, bool timeoutUsed) {
    int p1Num = teamNum == 1 ? 1 : (widget.isDoubles ? 3 : 2);
    final teamPenalties = logs.where((p) => p.type == 'penalty' && ((teamNum == 1 && (widget.isDoubles ? (p.playerNum == 1 || p.playerNum == 2) : p.playerNum == 1)) || (teamNum == 2 && (widget.isDoubles ? (p.playerNum == 3 || p.playerNum == 4) : p.playerNum == 2)))).toList();
    return TeamColumn(
      teamNum: teamNum, score: teamNum == 1 ? player1Score : player2Score, sets: teamNum == 1 ? player1Sets : player2Sets, name1: teamNum == 1 ? widget.p1Name : widget.p3Name, name2: teamNum == 1 ? widget.p2Name : widget.p4Name, isDoubles: widget.isDoubles, hasWon: hasWon, timeoutUsed: timeoutUsed, isTimerRunning: _activeTimerSeconds > 0, isFinished: isFinished, isAnySuspended: _isAnySuspended, teamServing: widget.isDoubles ? (teamNum == 1 ? (_currentServer <= 2) : (_currentServer >= 3)) : (_currentServer == teamNum), playerSide: _getPlayerSide(p1Num), hasYellow: teamPenalties.length >= 1, hasRed: teamPenalties.length >= 2, isSuspended: teamPenalties.length >= 4, 
      onScoreTap: () => _updateScore(teamNum, 1), onTimeoutTap: () => _useTimeout(p1Num), onYellowTap: () => _issuePenalty(p1Num, 'yellow'), onRedTap: () => _issuePenalty(p1Num, 'red'),
      isHost: _isHost,
      playerNameBuilder: (name, pNum, won) {
        bool isS = _currentServer == pNum; bool isR = _currentReceiver == pNum;
        return Text(name + (isS ? ' (S)' : isR ? ' (R)' : ''), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: isS || isR ? FontWeight.bold : FontWeight.normal, color: isS ? Colors.white : isR ? Colors.blueAccent : (won ? Colors.amber : null)), overflow: TextOverflow.ellipsis);
      }
    );
  }
}
