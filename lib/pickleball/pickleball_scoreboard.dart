import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/language_service.dart';
import 'pickleball_models.dart';
import 'widgets/pickleball_banners.dart';
import 'widgets/pickleball_history.dart';
import 'widgets/pickleball_team_column.dart';

class PickleballMatch extends StatefulWidget {
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;
  final bool isDoubles;
  final int gamesToWin; // e.g. 2 for best of 3

  final int initialP1Score;
  final int initialP2Score;
  final int initialP1Games;
  final int initialP2Games;
  final bool initialIsGameOver;
  final List<int> initialPointHistory;
  final List<PickleballGameSummary> initialGameSummaries;
  final int initialCurrentServer;
  final int initialServerNum;
  final bool initialP1OnLeft;
  final List<PickleballLogEntry> initialLogs;
  final int initialMatchTimeSeconds;
  final int? activeTimerEndTime;
  final String activeTimerTitle;
  final bool initialKeepRunningTimers;
  final int? initialLastSavedTimestamp;
  final String matchId;
  final bool isHost;
  final bool initialP1TimeoutUsed;
  final bool initialP2TimeoutUsed;

  const PickleballMatch({
    super.key,
    required this.p1Name,
    required this.p2Name,
    required this.p3Name,
    required this.p4Name,
    required this.isDoubles,
    required this.gamesToWin,
    this.initialP1Score = 0,
    this.initialP2Score = 0,
    this.initialP1Games = 0,
    this.initialP2Games = 0,
    this.initialIsGameOver = false,
    this.initialPointHistory = const [],
    this.initialGameSummaries = const [],
    this.initialCurrentServer = 0,
    this.initialServerNum = 2,
    this.initialP1OnLeft = true,
    this.initialLogs = const [],
    this.initialMatchTimeSeconds = 0,
    this.activeTimerEndTime,
    this.activeTimerTitle = '',
    this.initialKeepRunningTimers = false,
    this.initialLastSavedTimestamp,
    required this.matchId,
    required this.isHost,
    this.initialP1TimeoutUsed = false,
    this.initialP2TimeoutUsed = false,
  });

  @override
  State<PickleballMatch> createState() => _PickleballMatchState();
}

class _PickleballMatchState extends State<PickleballMatch> with WidgetsBindingObserver {
  int p1Score = 0;
  int p2Score = 0;
  int p1Games = 0;
  int p2Games = 0;
  bool isGameOver = false;
  List<int> pointHistory = [];
  List<PickleballGameSummary> gameSummaries = [];
  List<PickleballLogEntry> logs = [];

  int currentServer = 1; // 1, 2, 3, 4
  int serverNum = 2; // 1 or 2
  bool p1OnLeft = true;

  int matchTimeSeconds = 0;
  Timer? _matchTimer;
  int? timerEndTime;
  String timerTitle = '';
  Timer? _countdownTimer;

  bool p1TimeoutUsed = false;
  bool p2TimeoutUsed = false;
  int firstServerOfGame = 1;

  final List<PickleballMatchState> _history = [];
  final List<PickleballMatchState> _redoHistory = [];
  StreamSubscription? _cloudMatchSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    p1Score = widget.initialP1Score;
    p2Score = widget.initialP2Score;
    p1Games = widget.initialP1Games;
    p2Games = widget.initialP2Games;
    isGameOver = widget.initialIsGameOver;
    pointHistory = List<int>.from(widget.initialPointHistory);
    gameSummaries = List<PickleballGameSummary>.from(widget.initialGameSummaries);
    logs = List<PickleballLogEntry>.from(widget.initialLogs);
    currentServer = widget.initialCurrentServer > 0 ? widget.initialCurrentServer : 1;
    firstServerOfGame = currentServer;
    serverNum = widget.initialServerNum;
    p1OnLeft = widget.initialP1OnLeft;
    matchTimeSeconds = widget.initialMatchTimeSeconds;
    timerEndTime = widget.activeTimerEndTime;
    timerTitle = widget.activeTimerTitle;
    p1TimeoutUsed = widget.initialP1TimeoutUsed;
    p2TimeoutUsed = widget.initialP2TimeoutUsed;

    _startMatchTimer();
    if (timerEndTime != null) {
      _startCountdownTimer();
    }

    if (!widget.isHost && widget.matchId.isNotEmpty) {
      _listenToCloudMatch();
    } else if (widget.isHost && widget.initialCurrentServer == 0 && pointHistory.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptToss());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _matchTimer?.cancel();
    _countdownTimer?.cancel();
    _cloudMatchSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveStateLocally();
    }
  }

  Future<void> _promptToss() async {
    if (!widget.isHost) return;

    int winnerTeam = Random().nextBool() ? 1 : 2;
    String winnerName = widget.isDoubles ? "Team $winnerTeam" : (winnerTeam == 1 ? widget.p1Name : widget.p2Name);
    int loserTeam = 3 - winnerTeam;
    String loserName = widget.isDoubles ? "Team $loserTeam" : (loserTeam == 1 ? widget.p1Name : widget.p2Name);

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Coin Toss Result'.tr),
        content: Text('$winnerName ${"won the toss!".tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text('Continue'.tr)),
        ],
      ),
    );

    if (!mounted) return;
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('$winnerName: ${"Choose Option".tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 3), child: Text('Home Side'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 4), child: Text('Away Side'.tr)),
        ],
      ),
    );
    if (!mounted) return;

    bool startsLeft = true;
    int servingTeam = winnerTeam;

    if (choice == 1) {
      servingTeam = winnerTeam;
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Choose Side".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
          ],
        ),
      );
      startsLeft = (sideChoice != 2);
    } else if (choice == 2) {
      servingTeam = loserTeam;
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Choose Side".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
          ],
        ),
      );
      startsLeft = (sideChoice != 2);
    } else if (choice == 3) {
      startsLeft = true;
      int? serviceChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Serve or Receive?".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
          ],
        ),
      );
      servingTeam = (serviceChoice == 1) ? loserTeam : winnerTeam;
    } else if (choice == 4) {
      startsLeft = false;
      int? serviceChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Serve or Receive?".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
          ],
        ),
      );
      servingTeam = (serviceChoice == 1) ? loserTeam : winnerTeam;
    }

    setState(() {
      p1OnLeft = startsLeft;
      currentServer = servingTeam == 1 ? 1 : 3;
      firstServerOfGame = currentServer;
    });
    _saveStateLocally();
  }

  void _listenToCloudMatch() {
    _cloudMatchSubscription = FirebaseFirestore.instance
        .collection('active_matches')
        .doc(widget.matchId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: Text('Match Ended'.tr),
              content: Text('The host has ended or discarded the match.'.tr),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text('OK'.tr),
                ),
              ],
            ),
          );
        }
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final String status = data['status'] ?? 'playing';
      if (status != 'playing') {
        if (mounted) {
          Navigator.pop(context);
        }
        return;
      }

      final matchData = data['matchData'] as Map<String, dynamic>?;
      if (matchData != null && mounted) {
        setState(() {
          p1Score = matchData['p1Score'] ?? p1Score;
          p2Score = matchData['p2Score'] ?? p2Score;
          p1Games = matchData['p1Games'] ?? p1Games;
          p2Games = matchData['p2Games'] ?? p2Games;
          isGameOver = matchData['isGameOver'] ?? isGameOver;
          pointHistory = List<int>.from(matchData['pointHistory'] ?? pointHistory);
          currentServer = matchData['currentServer'] ?? currentServer;
          serverNum = matchData['serverNum'] ?? serverNum;
          p1OnLeft = matchData['p1OnLeft'] ?? p1OnLeft;
          matchTimeSeconds = matchData['matchTimeSeconds'] ?? matchTimeSeconds;
          p1TimeoutUsed = matchData['p1TimeoutUsed'] ?? p1TimeoutUsed;
          p2TimeoutUsed = matchData['p2TimeoutUsed'] ?? p2TimeoutUsed;
          if (matchData['gameSummaries'] != null) {
            gameSummaries = (matchData['gameSummaries'] as List)
                .map((s) => PickleballGameSummary.fromMap(s))
                .toList();
          }
          if (matchData['logs'] != null) {
            logs = (matchData['logs'] as List)
                .map((l) => PickleballLogEntry.fromMap(l))
                .toList();
          }
        });
      }
    });
  }

  void _startMatchTimer() {
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !isGameOver) {
        setState(() {
          matchTimeSeconds++;
        });
      }
    });
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timerEndTime == null) {
        timer.cancel();
        return;
      }
      final remaining = timerEndTime! - DateTime.now().millisecondsSinceEpoch;
      if (remaining <= 0) {
        timer.cancel();
        setState(() {
          timerEndTime = null;
          timerTitle = '';
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _saveStateLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final state = PickleballMatchState(
      p1Score: p1Score,
      p2Score: p2Score,
      p1Games: p1Games,
      p2Games: p2Games,
      isGameOver: isGameOver,
      pointHistory: pointHistory,
      gameSummaries: gameSummaries,
      currentServer: currentServer,
      serverNum: serverNum,
      p1OnLeft: p1OnLeft,
      logs: logs,
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
      p1TimeoutUsed: p1TimeoutUsed,
      p2TimeoutUsed: p2TimeoutUsed,
    );
    await prefs.setString('active_pickleball_match', jsonEncode({
      'matchId': widget.matchId,
      ...state.toMap(),
      'p1Name': widget.p1Name,
      'p2Name': widget.p2Name,
      'p3Name': widget.p3Name,
      'p4Name': widget.p4Name,
      'isDoubles': widget.isDoubles,
      'gamesToWin': widget.gamesToWin,
      'keepRunningTimers': widget.initialKeepRunningTimers,
      'lastSavedTimestamp': DateTime.now().millisecondsSinceEpoch,
    }));

    if (widget.matchId.isNotEmpty && widget.isHost) {
      await FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).update({
        'matchData': state.toMap(),
      });
    }
  }

  void _pushHistory() {
    _history.add(PickleballMatchState(
      p1Score: p1Score,
      p2Score: p2Score,
      p1Games: p1Games,
      p2Games: p2Games,
      isGameOver: isGameOver,
      pointHistory: List.from(pointHistory),
      gameSummaries: List.from(gameSummaries),
      currentServer: currentServer,
      serverNum: serverNum,
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
      p1TimeoutUsed: p1TimeoutUsed,
      p2TimeoutUsed: p2TimeoutUsed,
    ));
    _redoHistory.clear();
  }

  void _addPoint(int team) {
    if (isGameOver) return;
    _pushHistory();

    setState(() {
      pointHistory.add(team);
      if (team == 1) {
        p1Score++;
      } else {
        p2Score++;
      }

      final res = PickleballRotationLogic.getRotationAtPoint(
        firstServer: firstServerOfGame,
        isDoubles: widget.isDoubles,
        pointSequence: pointHistory,
      );
      currentServer = res.server;
      serverNum = res.serverNum;

      int target = 11;
      if ((p1Score >= target || p2Score >= target) && (p1Score - p2Score).abs() >= 2) {
        _endGame(team);
      }
    });

    _saveStateLocally();
  }

  void _endGame(int winningTeam) {
    isGameOver = true;
    if (winningTeam == 1) {
      p1Games++;
    } else {
      p2Games++;
    }

    gameSummaries.add(PickleballGameSummary(
      p1Score: p1Score,
      p2Score: p2Score,
      pointSequence: List.from(pointHistory),
      firstServer: currentServer,
    ));

    logs.add(PickleballLogEntry(
      type: 'game_end',
      gameNum: p1Games + p2Games,
      p1Score: p1Score,
      p2Score: p2Score,
      detail: 'Team $winningTeam won game',
    ));

    if (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin) {
      _finishMatch(winningTeam);
    } else {
      _showNextGameDialog();
    }
  }

  void _showNextGameDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Game Concluded'.tr),
        content: Text('Start next game?'.tr),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                p1Score = 0;
                p2Score = 0;
                pointHistory.clear();
                isGameOver = false;
                p1OnLeft = !p1OnLeft;
                firstServerOfGame = firstServerOfGame <= 2 ? 3 : 1; // Alternate starting server each game
              });
              _saveStateLocally();
            },
            child: Text('Start Next Game'.tr),
          ),
        ],
      ),
    );
  }

  void _finishMatch(int winningTeam) async {
    String winnerName = winningTeam == 1 ? widget.p1Name : widget.p3Name;
    if (widget.isDoubles && winningTeam == 1) winnerName += ' & ${widget.p2Name}';
    if (widget.isDoubles && winningTeam == 2) winnerName += ' & ${widget.p4Name}';

    if (widget.matchId.isNotEmpty && widget.isHost) {
      await FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).update({
        'status': 'completed',
        'winnerUid': winningTeam == 1 ? 'p1' : 'p2',
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_pickleball_match');

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Match Concluded!'.tr),
        content: Text('$winnerName won the match!'.tr),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('OK'.tr),
          ),
        ],
      ),
    );
  }

  void _undo() {
    if (_history.isEmpty) return;
    _redoHistory.add(PickleballMatchState(
      p1Score: p1Score,
      p2Score: p2Score,
      p1Games: p1Games,
      p2Games: p2Games,
      isGameOver: isGameOver,
      pointHistory: List.from(pointHistory),
      gameSummaries: List.from(gameSummaries),
      currentServer: currentServer,
      serverNum: serverNum,
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
      p1TimeoutUsed: p1TimeoutUsed,
      p2TimeoutUsed: p2TimeoutUsed,
    ));

    final prevState = _history.removeLast();
    setState(() {
      p1Score = prevState.p1Score;
      p2Score = prevState.p2Score;
      p1Games = prevState.p1Games;
      p2Games = prevState.p2Games;
      isGameOver = prevState.isGameOver;
      pointHistory = List.from(prevState.pointHistory);
      gameSummaries = List.from(prevState.gameSummaries);
      currentServer = prevState.currentServer;
      serverNum = prevState.serverNum;
      p1OnLeft = prevState.p1OnLeft;
      logs = List.from(prevState.logs);
      matchTimeSeconds = prevState.matchTimeSeconds;
      timerEndTime = prevState.timerEndTime;
      timerTitle = prevState.timerTitle;
      p1TimeoutUsed = prevState.p1TimeoutUsed;
      p2TimeoutUsed = prevState.p2TimeoutUsed;
    });
    _saveStateLocally();
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    _history.add(PickleballMatchState(
      p1Score: p1Score,
      p2Score: p2Score,
      p1Games: p1Games,
      p2Games: p2Games,
      isGameOver: isGameOver,
      pointHistory: List.from(pointHistory),
      gameSummaries: List.from(gameSummaries),
      currentServer: currentServer,
      serverNum: serverNum,
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
      p1TimeoutUsed: p1TimeoutUsed,
      p2TimeoutUsed: p2TimeoutUsed,
    ));

    final nextState = _redoHistory.removeLast();
    setState(() {
      p1Score = nextState.p1Score;
      p2Score = nextState.p2Score;
      p1Games = nextState.p1Games;
      p2Games = nextState.p2Games;
      isGameOver = nextState.isGameOver;
      pointHistory = List.from(nextState.pointHistory);
      gameSummaries = List.from(nextState.gameSummaries);
      currentServer = nextState.currentServer;
      serverNum = nextState.serverNum;
      p1OnLeft = nextState.p1OnLeft;
      logs = List.from(nextState.logs);
      matchTimeSeconds = nextState.matchTimeSeconds;
      timerEndTime = nextState.timerEndTime;
      timerTitle = nextState.timerTitle;
      p1TimeoutUsed = nextState.p1TimeoutUsed;
      p2TimeoutUsed = nextState.p2TimeoutUsed;
    });
    _saveStateLocally();
  }

  void _resetMatch() {
    setState(() {
      p1Score = 0;
      p2Score = 0;
      p1Games = 0;
      p2Games = 0;
      isGameOver = false;
      pointHistory.clear();
      gameSummaries.clear();
      logs.clear();
      currentServer = 1;
      serverNum = 2;
      p1OnLeft = true;
      matchTimeSeconds = 0;
      timerEndTime = null;
      timerTitle = '';
      p1TimeoutUsed = false;
      p2TimeoutUsed = false;
    });
    _saveStateLocally();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptToss());
  }

  void _callTimeout(int teamNum) {
    setState(() {
      if (teamNum == 1) {
        p1TimeoutUsed = true;
      } else {
        p2TimeoutUsed = true;
      }

      timerEndTime = DateTime.now().millisecondsSinceEpoch + 60000;
      timerTitle = 'Timeout (Team $teamNum)';
      logs.add(PickleballLogEntry(
        type: 'timeout',
        gameNum: p1Games + p2Games + 1,
        p1Score: p1Score,
        p2Score: p2Score,
        detail: 'Timeout called by Team $teamNum',
      ));
    });
    _startCountdownTimer();
    _saveStateLocally();
  }

  void _issuePenalty(int playerNum, String cardType) {
    _pushHistory();
    setState(() {
      logs.add(PickleballLogEntry(
        type: 'penalty',
        playerNum: playerNum,
        cardType: cardType,
        gameNum: p1Games + p2Games + 1,
        p1Score: p1Score,
        p2Score: p2Score,
        detail: 'Issued $cardType card to player $playerNum',
      ));
    });
    _saveStateLocally();
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => PickleballMatchHistoryBottomSheet(
        gameSummaries: gameSummaries,
        logs: logs,
        p1Name: widget.p1Name,
        p2Name: widget.p2Name,
        p3Name: widget.p3Name,
        p4Name: widget.p4Name,
        isDoubles: widget.isDoubles,
      ),
    );
  }

  void _showRulesInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pickleball Match Rules & Info'.tr),
        content: SingleChildScrollView(
          child: Text(
            '• Games are played to 11 points (win by 2).\n'
            '• Best of N games as configured.\n'
            '• Doubles uses the 3-number score: Server Score - Receiver Score - Server Number (1 or 2).\n'
            '• Each team is allowed 1-minute timeouts per game.\n'
            '• Official conduct cards can be issued for penalties.'
                .tr,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'.tr)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String scoreDisplay = widget.isDoubles
        ? '$p1Score - $p2Score - $serverNum'
        : '$p1Score - $p2Score';

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && widget.isHost && !isGameOver) {
          _saveStateLocally();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pickleball Scoreboard'.tr),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showRulesInfo,
              tooltip: 'Rules'.tr,
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showHistoryModal,
              tooltip: 'Match History'.tr,
            ),
            if (widget.isHost) ...[
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _history.isNotEmpty ? _undo : null,
                tooltip: 'Undo'.tr,
              ),
              IconButton(
                icon: const Icon(Icons.redo),
                onPressed: _redoHistory.isNotEmpty ? _redo : null,
                tooltip: 'Redo'.tr,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: Text('Reset Match?'.tr),
                      content: Text('All progress will be lost. This cannot be undone.'.tr),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel'.tr)),
                        TextButton(onPressed: () { Navigator.pop(c); _resetMatch(); }, child: Text('Reset'.tr, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                },
                tooltip: 'Reset'.tr,
              ),
            ],
            PopupMenuButton<String>(
              onSelected: (value) async {
                final localContext = context;
                if (value == 'discard') {
                  bool? confirm = await showDialog<bool>(
                    context: localContext,
                    builder: (context) => AlertDialog(
                      title: Text('Discard Match?'.tr),
                      content: Text('This will delete all match data. This action cannot be undone.'.tr),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Discard'.tr, style: const TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    if (widget.matchId.isNotEmpty) {
                      await FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).delete();
                    }
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('active_pickleball_match');
                    if (mounted) {
                      Navigator.pop(localContext);
                    }
                  }
                } else if (value == 'timeout1') {
                  if (!p1TimeoutUsed) _callTimeout(1);
                } else if (value == 'timeout2') {
                  if (!p2TimeoutUsed) _callTimeout(2);
                }
              },
              itemBuilder: (context) => [
                if (widget.isHost && !isGameOver) ...[
                  PopupMenuItem(value: 'discard', child: Text('Discard Match'.tr, style: const TextStyle(color: Colors.red))),
                  if (!p1TimeoutUsed)
                    PopupMenuItem(value: 'timeout1', child: Text('${"Timeout".tr} (${widget.p1Name})')),
                  if (!p2TimeoutUsed)
                    PopupMenuItem(value: 'timeout2', child: Text('${"Timeout".tr} (${widget.isDoubles ? widget.p3Name : widget.p2Name})')),
                ],
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              PickleballSuspensionBanner(
                logs: logs,
                isDoubles: widget.isDoubles,
                p1Name: widget.p1Name,
                p2Name: widget.p2Name,
                p3Name: widget.p3Name,
                p4Name: widget.p4Name,
              ),
              if (timerEndTime != null)
                PickleballTimerBanner(
                  title: timerTitle,
                  endTime: timerEndTime!,
                  isHost: widget.isHost,
                  onCancel: () {
                    setState(() {
                      timerEndTime = null;
                      timerTitle = '';
                    });
                    _saveStateLocally();
                  },
                ),
              const SizedBox(height: 12),
              Text('Best of ${widget.gamesToWin * 2 - 1} games'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 4),
              Text(
                'Score: $scoreDisplay',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    p1OnLeft
                        ? PickleballTeamColumn(
                            team: 1,
                            score: p1Score,
                            games: p1Games,
                            names: widget.isDoubles ? [widget.p1Name, widget.p2Name] : [widget.p1Name, ''],
                            isDoubles: widget.isDoubles,
                            isServing: currentServer <= 2,
                            serverNum: serverNum,
                            side: 'HOME',
                            isHost: widget.isHost,
                            isTimerRunning: timerEndTime != null,
                            onScore: () => _addPoint(1),
                            onYellow: () => _issuePenalty(1, 'yellow'),
                            onRed: () => _issuePenalty(1, 'red'),
                            onBlack: () => _issuePenalty(1, 'black'),
                            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! <= 2)),
                            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! <= 2)),
                            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! <= 2)),
                            pointHistory: pointHistory,
                            firstServer: firstServerOfGame,
                          )
                        : PickleballTeamColumn(
                            team: 2,
                            score: p2Score,
                            games: p2Games,
                            names: widget.isDoubles ? [widget.p3Name, widget.p4Name] : [widget.p2Name, ''],
                            isDoubles: widget.isDoubles,
                            isServing: currentServer >= 3,
                            serverNum: serverNum,
                            side: 'AWAY',
                            isHost: widget.isHost,
                            isTimerRunning: timerEndTime != null,
                            onScore: () => _addPoint(2),
                            onYellow: () => _issuePenalty(3, 'yellow'),
                            onRed: () => _issuePenalty(3, 'red'),
                            onBlack: () => _issuePenalty(3, 'black'),
                            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! >= 3)),
                            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! >= 3)),
                            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! >= 3)),
                            pointHistory: pointHistory,
                            firstServer: firstServerOfGame,
                          ),
                    const SizedBox(width: 16),
                    p1OnLeft
                        ? PickleballTeamColumn(
                            team: 2,
                            score: p2Score,
                            games: p2Games,
                            names: widget.isDoubles ? [widget.p3Name, widget.p4Name] : [widget.p2Name, ''],
                            isDoubles: widget.isDoubles,
                            isServing: currentServer >= 3,
                            serverNum: serverNum,
                            side: 'AWAY',
                            isHost: widget.isHost,
                            isTimerRunning: timerEndTime != null,
                            onScore: () => _addPoint(2),
                            onYellow: () => _issuePenalty(3, 'yellow'),
                            onRed: () => _issuePenalty(3, 'red'),
                            onBlack: () => _issuePenalty(3, 'black'),
                            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! >= 3)),
                            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! >= 3)),
                            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! >= 3)),
                            pointHistory: pointHistory,
                            firstServer: firstServerOfGame,
                          )
                        : PickleballTeamColumn(
                            team: 1,
                            score: p1Score,
                            games: p1Games,
                            names: widget.isDoubles ? [widget.p1Name, widget.p2Name] : [widget.p1Name, ''],
                            isDoubles: widget.isDoubles,
                            isServing: currentServer <= 2,
                            serverNum: serverNum,
                            side: 'HOME',
                            isHost: widget.isHost,
                            isTimerRunning: timerEndTime != null,
                            onScore: () => _addPoint(1),
                            onYellow: () => _issuePenalty(1, 'yellow'),
                            onRed: () => _issuePenalty(1, 'red'),
                            onBlack: () => _issuePenalty(1, 'black'),
                            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! <= 2)),
                            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! <= 2)),
                            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! <= 2)),
                            pointHistory: pointHistory,
                            firstServer: firstServerOfGame,
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
