import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tt_models.dart';

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
  final int initialFirstServer;
  final bool initialP1OnLeft;
  final List<MatchLogEntry> initialLogs;
  final bool initialExpediteActive;
  final int initialGameTimeSeconds;
  final int activeTimerSeconds;
  final String activeTimerTitle;
  final int initialFirstReceiver;

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
    this.initialFirstServer = 1,
    this.initialFirstReceiver = 0,
    this.initialP1OnLeft = true,
    this.initialLogs = const [],
    this.initialExpediteActive = false,
    this.initialGameTimeSeconds = 0,
    this.activeTimerSeconds = 0,
    this.activeTimerTitle = '',
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
    firstServerOfSet = widget.initialFirstServer;
    firstReceiverOfSet = widget.initialFirstReceiver;
    logs = List<MatchLogEntry>.from(widget.initialLogs);
    expediteActive = widget.initialExpediteActive;
    gameTimeSeconds = widget.initialGameTimeSeconds;
    
    _activeTimerSeconds = widget.activeTimerSeconds;
    _activeTimerTitle = widget.activeTimerTitle;

    _checkMatchWinner();
    _startInternalExpediteTimer();
    
    if (_activeTimerSeconds > 0) {
      _startMatchTimer(_activeTimerTitle, _activeTimerSeconds);
    }
    
    _persistMatch();

    if (player1Score == 0 && player2Score == 0 && player1Sets == 0 && player2Sets == 0 && _activeTimerSeconds == 0) {
      p1OnLeftOfMatch = Random().nextBool();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _promptTossWinner();
        _promptWarmup();
      });
    }
  }

  @override
  void dispose() {
    _activeTimer?.cancel();
    _expediteInternalTimer?.cancel();
    ScaffoldMessenger.of(context).clearSnackBars();
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
        
        int servingTeam = ((player1Sets + player2Sets) % 2 == 0) ? (firstServerOfMatch <= 2 ? 1 : 2) : (firstServerOfMatch <= 2 ? 2 : 1);
        _selectServerAndReceiver(servingTeam, isFirstGame: false);
      }
    });
    _persistMatch();
  }

  Future<void> _persistMatch() async {
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
      'firstServer': firstServerOfSet,
      'firstReceiver': firstReceiverOfSet,
      'p1OnLeft': p1OnLeftOfMatch,
      'logs': logs.map((p) => p.toMap()).toList(),
      'expediteActive': expediteActive,
      'gameTimeSeconds': gameTimeSeconds,
      'activeTimerSeconds': _activeTimerSeconds,
      'activeTimerTitle': _activeTimerTitle,
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
      firstServer: firstServerOfSet,
      firstReceiver: firstReceiverOfSet,
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
    // Decide toss winner automatically
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
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Continue')
          ),
        ],
      ),
    );
    
    await _promptInitialServiceChoice(tossWinnerTeam);
  }

  Future<void> _promptInitialServiceChoice(int tossWinnerTeam) async {
    String winnerDisplay = widget.isDoubles 
        ? "Team $tossWinnerTeam" 
        : (tossWinnerTeam == 1 ? widget.p1Name : widget.p3Name);
    
    String loserDisplay = widget.isDoubles
        ? "Team ${3 - tossWinnerTeam}"
        : (tossWinnerTeam == 1 ? widget.p3Name : widget.p1Name);

    // ITTF Law 2.13.01: The winner of the toss makes a choice.
    int? winnerChoice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('$winnerDisplay won the toss!'),
        content: const Text('Choose your advantage:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Service/Receive')),
          TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Starting Side')),
        ],
      ),
    );

    int servingTeam = 1;
    bool p1StartsLeft = true;

    if (winnerChoice == 1) {
      // Winner chooses Service/Receive
      int? sChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$winnerDisplay: Serve or Receive?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Serve First')),
            TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Receive First')),
          ],
        ),
      );
      servingTeam = (sChoice == 1) ? tossWinnerTeam : (3 - tossWinnerTeam);

      // Loser chooses Side (ITTF Law 2.13.01)
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$loserDisplay: Which side to start at?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Left Side')),
            TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Right Side')),
          ],
        ),
      );
      bool loserIsTeam1 = (3 - tossWinnerTeam) == 1;
      p1StartsLeft = (sideChoice == 1) ? loserIsTeam1 : !loserIsTeam1;
    } else {
      // Winner chooses Starting Side
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$winnerDisplay: Which side to start at?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Left Side')),
            TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Right Side')),
          ],
        ),
      );
      bool winnerIsTeam1 = tossWinnerTeam == 1;
      p1StartsLeft = (sideChoice == 1) ? winnerIsTeam1 : !winnerIsTeam1;

      // Loser chooses Service/Receive
      int? sChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('$loserDisplay: Serve or Receive?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, 1), child: const Text('Serve First')),
            TextButton(onPressed: () => Navigator.pop(context, 2), child: const Text('Receive First')),
          ],
        ),
      );
      servingTeam = (sChoice == 1) ? (3 - tossWinnerTeam) : tossWinnerTeam;
    }

    setState(() {
      p1OnLeftOfMatch = p1StartsLeft;
    });
    
    await _selectServerAndReceiver(servingTeam, isFirstGame: true);
  }

  Future<void> _selectServerAndReceiver(int servingTeam, {required bool isFirstGame}) async {
    int? server;
    String teamDisplay = widget.isDoubles 
        ? "Team $servingTeam" 
        : (servingTeam == 1 ? widget.p1Name : widget.p3Name);

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
    List<int> rotation = _calculateRotation(lastSet.firstServer, lastSet.firstReceiver, isDecider: (setSummaries.length == (widget.setsToWin * 2) - 2), p1Score: lastSet.p1Score, p2Score: lastSet.p2Score);
    int idx = rotation.indexOf(server);
    int serverToChosenServerIdx = (idx - 1 + 4) % 4;
    return rotation[serverToChosenServerIdx];
  }

  List<int> _calculateRotation(int fs, int fr, {required bool isDecider, required int p1Score, required int p2Score}) {
    if (!widget.isDoubles) return [fs, 3 - fs];
    int p1 = fs;
    int p2 = fr;
    int p3 = (fs == 1 ? 2 : (fs == 2 ? 1 : (fs == 3 ? 4 : 3)));
    int p4 = (fr == 1 ? 2 : (fr == 2 ? 1 : (fr == 3 ? 4 : 3)));
    List<int> normal = [p1, p2, p3, p4];
    if (isDecider && (p1Score >= 5 || p2Score >= 5)) {
      return [p1, p4, p3, p2];
    }
    return normal;
  }

  bool get _isDecider => (player1Sets + player2Sets) == (widget.setsToWin * 2) - 2;

  int get _currentServer {
    int totalPoints = player1Score + player2Score;
    List<int> rotation = _calculateRotation(firstServerOfSet, firstReceiverOfSet, isDecider: _isDecider, p1Score: player1Score, p2Score: player2Score);
    int stintSize = (expediteActive || (player1Score >= 10 && player2Score >= 10)) ? 1 : 2;
    int rotationIdx = (totalPoints ~/ stintSize) % (widget.isDoubles ? 4 : 2);
    return rotation[rotationIdx];
  }

  int get _currentReceiver {
    if (!widget.isDoubles) return 0;
    int totalPoints = player1Score + player2Score;
    List<int> rotation = _calculateRotation(firstServerOfSet, firstReceiverOfSet, isDecider: _isDecider, p1Score: player1Score, p2Score: player2Score);
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
    
    if (isTeam1) {
      return finalP1OnLeft ? 'LEFT' : 'RIGHT';
    } else {
      return finalP1OnLeft ? 'RIGHT' : 'LEFT';
    }
  }

  void _updateScore(int player, int delta, {bool isPenalty = false}) {
    if (isFinished && delta > 0) return;
    if (!isPenalty) _saveState();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      if (isSetOver && delta > 0) _stopMatchTimer();
      if (player == 1) {
        player1Score = (player1Score + delta).clamp(0, 99);
        if (delta > 0) {
          for (int i = 0; i < delta; i++) pointHistory.add(1);
        } else if (pointHistory.isNotEmpty && pointHistory.last == 1) {
          pointHistory.removeLast();
        }
      } else {
        player2Score = (player2Score + delta).clamp(0, 99);
        if (delta > 0) {
          for (int i = 0; i < delta; i++) pointHistory.add(2);
        } else if (pointHistory.isNotEmpty && pointHistory.last == 2) {
          pointHistory.removeLast();
        }
      }
      if (delta > 0) {
        if (_isDecider && (player1Score == 5 || player2Score == 5)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Decider: Switch Sides! ↔️'), backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
        }
        _checkSetWinner();
        int totalPoints = player1Score + player2Score;
        if (totalPoints > 0 && totalPoints % 6 == 0 && !isSetOver) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Towel Break Reminder! 🧻'), duration: Duration(seconds: 5), backgroundColor: Colors.blueGrey));
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
    int actualPlayerNum = playerNum;
    int teamNum = widget.isDoubles ? (playerNum <= 2 ? 1 : 2) : (playerNum == 1 ? 1 : 2);

    if (widget.isDoubles) {
      int? selected = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Which player?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(teamNum == 1 ? widget.p1Name : widget.p3Name),
                onTap: () => Navigator.pop(context, teamNum == 1 ? 1 : 3),
              ),
              ListTile(
                title: Text(teamNum == 1 ? widget.p2Name : widget.p4Name),
                onTap: () => Navigator.pop(context, teamNum == 1 ? 2 : 4),
              ),
            ],
          ),
        ),
      );
      if (selected == null) return;
      actualPlayerNum = selected;
    }

    int teamPenalties = logs.where((p) => p.type == 'penalty' && 
        ((teamNum == 1 && (widget.isDoubles ? (p.playerNum == 1 || p.playerNum == 2) : p.playerNum == 1)) || 
         (teamNum == 2 && (widget.isDoubles ? (p.playerNum == 3 || p.playerNum == 4) : p.playerNum == 2)))).length;

    if (teamPenalties >= 4) return;

    String cardName = '';
    if (teamPenalties == 0) cardName = 'Yellow Card (Warning)';
    else if (teamPenalties == 1) cardName = 'Yellow + Red Card (+1 point)';
    else if (teamPenalties == 2) cardName = 'Yellow + Red Card (+2 points)';
    else cardName = 'Red Card (Suspension Warning)';

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
        int logP1 = player1Score;
        int logP2 = player2Score;

        String finalCardType = '';
        if (teamPenalties == 0) {
          finalCardType = 'yellow';
        } else if (teamPenalties == 1) {
          finalCardType = 'yellow-red-1';
          _updateScore(teamNum == 1 ? 2 : 1, 1, isPenalty: true);
        } else if (teamPenalties == 2) {
          finalCardType = 'yellow-red-2';
          _updateScore(teamNum == 1 ? 2 : 1, 2, isPenalty: true);
        } else {
          finalCardType = 'red-suspension';
        }

        logs.add(MatchLogEntry(
          type: 'penalty',
          playerNum: actualPlayerNum,
          cardType: finalCardType,
          reason: reason.isEmpty ? 'Offense' : reason,
          setNum: setSummaries.length + 1,
          p1Score: logP1,
          p2Score: logP2,
        ));
      });
      _persistMatch();
    }
  }

  void _checkSetWinner() {
    if (!isSetOver && (player1Score >= 11 || player2Score >= 11) && (player1Score - player2Score).abs() >= 2) {
      if (player1Score > player2Score) player1Sets++; else player2Sets++;
      isSetOver = true;
      setSummaries.add(SetSummary(
        p1Score: player1Score, 
        p2Score: player2Score, 
        pointSequence: List<int>.from(pointHistory), 
        isExpediteSet: expediteActive,
        firstServer: firstServerOfSet,
        firstReceiver: firstReceiverOfSet,
      ));
      _checkMatchWinner();
      if (!isFinished) {
         _startMatchTimer('Set Break', 60);
         WidgetsBinding.instance.addPostFrameCallback((_) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switch Sides! ↔️'), backgroundColor: Colors.orange, duration: Duration(seconds: 5)));
         });
      }
    }
  }

  void _checkMatchWinner() { setState(() { isFinished = (player1Sets >= widget.setsToWin || player2Sets >= widget.setsToWin); }); }

  bool get _isAnySuspended => logs.any((p) => p.type == 'penalty' && p.cardType == 'red-suspension');

  Map<String, dynamic> _calculateStats(int playerNum) {
    int totalPoints = 0, pointsOnServe = 0, servesTotal = 0, longestStreak = 0, currentStreak = 0;
    List<SetSummary> allSets = List.from(setSummaries);
    if (!isFinished) {
      allSets.add(SetSummary(
        p1Score: player1Score, 
        p2Score: player2Score, 
        pointSequence: List<int>.from(pointHistory), 
        isExpediteSet: expediteActive,
        firstServer: firstServerOfSet,
        firstReceiver: firstReceiverOfSet,
      ));
    }
    for (int i = 0; i < allSets.length; i++) {
      final set = allSets[i];
      int p1Points = 0, p2Points = 0;
      for (int p in set.pointSequence) {
        int totalInSet = p1Points + p2Points;
        List<int> rotation = _calculateRotation(set.firstServer, set.firstReceiver, isDecider: (i == (widget.setsToWin * 2) - 2), p1Score: p1Points, p2Score: p2Points);
        int stintSize = (set.isExpediteSet || (p1Points >= 10 && p2Points >= 10)) ? 1 : 2;
        int currentServer = rotation[(totalInSet ~/ stintSize) % (widget.isDoubles ? 4 : 2)];
        
        bool isTeam1 = (playerNum <= 2);
        bool pIsTeam1 = (p == 1);

        if ((isTeam1 && pIsTeam1) || (!isTeam1 && !pIsTeam1)) {
           totalPoints++; currentStreak++; if (currentStreak > longestStreak) longestStreak = currentStreak; 
           if ((isTeam1 && (currentServer == 1 || currentServer == 2)) || (!isTeam1 && (currentServer == 3 || currentServer == 4))) pointsOnServe++; 
        } else {
          currentStreak = 0;
        }
        
        if ((isTeam1 && (currentServer == 1 || currentServer == 2)) || (!isTeam1 && (currentServer == 3 || currentServer == 4))) servesTotal++;
        
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
        if (pointHistory.isNotEmpty || player1Score > 0 || player2Score > 0) allSets.add(SetSummary(
          p1Score: player1Score, 
          p2Score: player2Score, 
          pointSequence: List<int>.from(pointHistory), 
          isExpediteSet: expediteActive,
          firstServer: firstServerOfSet,
          firstReceiver: firstReceiverOfSet,
        ));
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
                        String pName = 'P${entry.playerNum}';
                        if (entry.playerNum == 1) pName = widget.p1Name;
                        else if (entry.playerNum == 2) pName = widget.p2Name;
                        else if (entry.playerNum == 3) pName = widget.p3Name;
                        else if (entry.playerNum == 4) pName = widget.p4Name;
                        text = '$pName: ${entry.reason}';
                     } else if (entry.type == 'timeout') {
                        String pName = entry.playerNum == 1 || entry.playerNum == 2 ? 'Team 1' : 'Team 2';
                        icon = Icons.timer; color = Colors.blueGrey; text = '$pName called Timeout';
                     } else if (entry.type == 'expedite') {
                        icon = Icons.flash_on; color = Colors.orange; text = 'Expedite System Activated';
                     }
                     return ListTile(dense: true, leading: Icon(icon, color: color), title: Text(text), subtitle: Text('Score: ${entry.p1Score}-${entry.p2Score}'));
                  }),
                  Padding(padding: const EdgeInsets.all(16.0), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _buildProgressRow('Team 1', p1Progress, 1), const SizedBox(height: 12), _buildProgressRow('Team 2', p2Progress, 2),
                  ]))),
                ],
              );
            })),
          ]),
        );
      },
    );
  }

  Widget _buildProgressRow(String playerName, List<int> scores, int teamNum) {
    return Row(children: [
      SizedBox(width: 80, child: Text(playerName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      ...scores.asMap().entries.map((entry) {
        bool pointWon = entry.key == 0 ? entry.value > 0 : entry.value > scores[entry.key - 1];
        return Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 4), decoration: BoxDecoration(
          color: pointWon ? (teamNum == 1 ? Colors.blue : Colors.green) : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4), border: pointWon ? null : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ), child: Center(child: Text('${entry.value}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: pointWon ? Colors.white : Colors.grey))));
      }),
    ]);
  }

  Widget _buildSuspensionBanner() {
    bool p1Suspended = logs.any((p) => p.type == 'penalty' && (p.playerNum == 1 || (widget.isDoubles && p.playerNum == 2)) && p.cardType == 'red-suspension');
    bool p2Suspended = logs.any((p) => p.type == 'penalty' && ((widget.isDoubles && (p.playerNum == 3 || p.playerNum == 4)) || (!widget.isDoubles && p.playerNum == 2)) && p.cardType == 'red-suspension');
    if (!p1Suspended && !p2Suspended) return const SizedBox.shrink();
    String teamName = p1Suspended ? (widget.isDoubles ? 'TEAM 1' : widget.p1Name) : (widget.isDoubles ? 'TEAM 2' : widget.p3Name);
    return Container(
      width: double.infinity, color: Colors.red, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), margin: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.report_problem, color: Colors.white), const SizedBox(width: 10),
          Expanded(child: Text('SUSPEND PLAY: $teamName REACHED LIMIT', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.center)),
        ]),
        const SizedBox(height: 4),
        const Text('REPORT TO REFEREE IMMEDIATELY', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
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
        firstServerOfSet = lastState.firstServer;
        firstReceiverOfSet = lastState.firstReceiver;
        p1OnLeftOfMatch = lastState.p1OnLeft;
        logs = lastState.logs;
        expediteActive = lastState.expediteActive;
        gameTimeSeconds = lastState.gameTimeSeconds;
        _activeTimerSeconds = lastState.activeTimerSeconds;
        _activeTimerTitle = lastState.activeTimerTitle;
        _activeTimer?.cancel();
        if (_activeTimerSeconds > 0) {
           _startMatchTimer(_activeTimerTitle, _activeTimerSeconds);
        }
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
      p1OnLeftOfMatch = Random().nextBool();
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptTossWinner());
    });
    _persistMatch();
  }

  @override
  Widget build(BuildContext context) {
    final bool p1Won = player1Sets >= widget.setsToWin, p2Won = player2Sets >= widget.setsToWin, isTimerRunning = _activeTimerSeconds > 0;
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
            IconButton(onPressed: _isAnySuspended ? null : () {
              showDialog(context: context, builder: (context) => AlertDialog(
                title: const Text('Match Rules'),
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
        body: SingleChildScrollView(
          child: Column(children: [
            _buildSuspensionBanner(),
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 8.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _buildTeamColumn(1, p1Won, p1TimeoutUsed, isTimerRunning),
              _buildTeamColumn(2, p2Won, p2TimeoutUsed, isTimerRunning),
            ])),
            const SizedBox(height: 30),
            if (isFinished || _isAnySuspended) ...[_buildStatsSummary(), const SizedBox(height: 20)],
            Padding(padding: const EdgeInsets.symmetric(horizontal: 40.0), child: ElevatedButton(
              onPressed: (isFinished || _isAnySuspended) ? () async { await _clearPersistedMatch(); if (!context.mounted) return; Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isAnySuspended ? 'Match suspended and saved.' : 'Match finished!'))); } : null,
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(55), backgroundColor: (isFinished || _isAnySuspended) ? Colors.amber : Colors.grey.withValues(alpha: 0.1), disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1), foregroundColor: Colors.white, disabledForegroundColor: Colors.white.withValues(alpha: 0.3), elevation: (isFinished || _isAnySuspended) ? 8 : 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text((isFinished || _isAnySuspended) ? 'CONCLUDE MATCH' : 'Finish Match', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: (isFinished || _isAnySuspended) ? 1.2 : 0)),
            )),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final s1 = _calculateStats(1), s2 = _calculateStats(3);
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

  Widget _buildTeamColumn(int teamNum, bool hasWon, bool timeoutUsed, bool isTimerRunning) {
    int score = teamNum == 1 ? player1Score : player2Score;
    int sets = teamNum == 1 ? player1Sets : player2Sets;
    String name1 = teamNum == 1 ? widget.p1Name : widget.p3Name;
    String name2 = teamNum == 1 ? widget.p2Name : widget.p4Name;
    int p1Num = teamNum == 1 ? 1 : (widget.isDoubles ? 3 : 2);
    int p2Num = teamNum == 1 ? 2 : 4;
    bool teamServing = widget.isDoubles ? (teamNum == 1 ? (_currentServer <= 2) : (_currentServer >= 3)) : (_currentServer == teamNum);
    double screenWidth = MediaQuery.of(context).size.width;
    double columnWidth = (screenWidth - 40) / 2.1;
    if (columnWidth > 200) columnWidth = 200;
    final teamPenalties = logs.where((p) => p.type == 'penalty' && ((teamNum == 1 && (widget.isDoubles ? (p.playerNum == 1 || p.playerNum == 2) : p.playerNum == 1)) || (teamNum == 2 && (widget.isDoubles ? (p.playerNum == 3 || p.playerNum == 4) : p.playerNum == 2)))).toList();
    int penaltyCount = teamPenalties.length;
    bool hasYellow = penaltyCount >= 1;
    bool hasRed = penaltyCount >= 2;
    bool isSuspended = penaltyCount >= 4;
    return Container(
      width: columnWidth,
      child: Column(children: [
        Column(children: [
          if (widget.isDoubles) ...[_playerNameText(name1, p1Num, hasWon), const Text('&', style: TextStyle(fontSize: 10, color: Colors.grey)), _playerNameText(name2, p2Num, hasWon)] else ...[_playerNameText(name1, p1Num, hasWon)],
        ]),
        const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: hasWon ? Colors.amber.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: hasWon ? Border.all(color: Colors.amber, width: 1) : null), child: Text('Sets: $sets', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: hasWon ? Colors.amber : Colors.blue))),
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(onPressed: (timeoutUsed || isTimerRunning || isFinished || _isAnySuspended) ? null : () => _useTimeout(p1Num), style: ElevatedButton.styleFrom(backgroundColor: timeoutUsed ? Colors.grey : Colors.blueGrey, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0), minimumSize: const Size(40, 25)), child: const Text('T/O', style: TextStyle(fontSize: 9))),
          const SizedBox(width: 8),
          GestureDetector(onTap: (isTimerRunning || isFinished || hasYellow || _isAnySuspended) ? null : () => _issuePenalty(p1Num, 'yellow'), child: Container(width: 18, height: 28, decoration: BoxDecoration(color: hasYellow ? Colors.yellow : Colors.yellow.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2), border: Border.all(color: hasYellow ? Colors.yellow.shade700 : Colors.yellow, width: 1.5), boxShadow: hasYellow ? [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))] : null))),
          const SizedBox(width: 6),
          GestureDetector(onTap: (isTimerRunning || isFinished || isSuspended || _isAnySuspended) ? null : () => _issuePenalty(p1Num, 'red'), child: Container(width: 18, height: 28, decoration: BoxDecoration(color: hasRed ? Colors.red : Colors.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2), border: Border.all(color: hasRed ? Colors.red.shade900 : Colors.red, width: 1.5), boxShadow: hasRed ? [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))] : null), child: isSuspended ? const Center(child: Icon(Icons.close, size: 14, color: Colors.white)) : null)),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: (isTimerRunning || isFinished || _isAnySuspended) ? null : () => _updateScore(teamNum, 1), 
          child: Container(
            width: columnWidth * 0.8, height: columnWidth * 0.8, 
            decoration: BoxDecoration(
              color: hasWon ? Colors.amber.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05), 
              shape: BoxShape.circle, 
              border: Border.all(color: teamServing ? Colors.white : (hasWon ? Colors.amber : (isFinished || isTimerRunning || _isAnySuspended ? Colors.white.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.5))), width: 3), 
              boxShadow: [
                if (hasWon) BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 3),
                if (teamServing && !isFinished && !isTimerRunning && !_isAnySuspended) BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 3)
              ]
            ), 
            child: Center(child: Text('$score', style: TextStyle(fontSize: columnWidth * 0.35, fontWeight: FontWeight.bold, color: hasWon ? Colors.amber : (isFinished || isTimerRunning || _isAnySuspended ? Colors.white.withValues(alpha: 0.1) : null))))
          )
        ),
        const SizedBox(height: 8),
        Text('SIDE: ${_getPlayerSide(p1Num)}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _playerNameText(String name, int playerNum, bool hasWon) {
    bool isServing = _currentServer == playerNum;
    bool isReceiving = _currentReceiver == playerNum;
    return Text(
      name + (isServing ? ' (S)' : isReceiving ? ' (R)' : ''),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, fontWeight: isServing || isReceiving ? FontWeight.bold : FontWeight.normal, color: isServing ? Colors.white : isReceiving ? Colors.blueAccent : (hasWon ? Colors.amber : null)),
      overflow: TextOverflow.ellipsis,
    );
  }
}
