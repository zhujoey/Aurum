import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'tennis_models.dart';
import 'widgets/tennis_banners.dart';
import 'widgets/tennis_history.dart';
import 'widgets/tennis_team_column.dart';

void _showAppSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: snackBar.backgroundColor,
      duration: snackBar.duration,
      behavior: SnackBarBehavior.floating,
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Container(
          color: Colors.transparent,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: snackBar.content,
        ),
      ),
    ),
  );
}

class TennisMatch extends StatefulWidget {
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;
  final bool isDoubles;
  final int setsToWin; // 2 for Best of 3, 3 for Best of 5
  final String matchId;
  final bool initialKeepRunningTimers;
  final bool? isHost;
  final int initialP1Pts;
  final int initialP2Pts;
  final int initialP1Games;
  final int initialP2Games;
  final int initialP1Sets;
  final int initialP2Sets;
  final bool initialIsTiebreak;
  final int initialP1TiebreakPts;
  final int initialP2TiebreakPts;
  final int initialServerPlayerNum;
  final bool initialP1OnLeft;
  final bool initialIsFinished;
  final List<TennisSetSummary> initialSetSummaries;
  final List<TennisLogEntry> initialLogs;
  final int initialMatchTimeSeconds;
  final int? activeTimerEndTime;
  final String activeTimerTitle;

  const TennisMatch({
    super.key,
    required this.p1Name,
    required this.p2Name,
    this.p3Name = '',
    this.p4Name = '',
    this.isDoubles = false,
    this.setsToWin = 2,
    this.matchId = '',
    this.initialKeepRunningTimers = true,
    this.isHost,
    this.initialP1Pts = 0,
    this.initialP2Pts = 0,
    this.initialP1Games = 0,
    this.initialP2Games = 0,
    this.initialP1Sets = 0,
    this.initialP2Sets = 0,
    this.initialIsTiebreak = false,
    this.initialP1TiebreakPts = 0,
    this.initialP2TiebreakPts = 0,
    this.initialServerPlayerNum = 1,
    this.initialP1OnLeft = true,
    this.initialIsFinished = false,
    this.initialSetSummaries = const [],
    this.initialLogs = const [],
    this.initialMatchTimeSeconds = 0,
    this.activeTimerEndTime,
    this.activeTimerTitle = '',
  });

  @override
  State<TennisMatch> createState() => _TennisMatchState();
}

class _TennisMatchState extends State<TennisMatch> {
  final _authService = AuthService();
  StreamSubscription<DocumentSnapshot>? _matchSubscription;
  Timer? _matchClock;
  Timer? _activeTimer;

  bool _isHost = true;
  bool isFinished = false;

  // Game Points: 0, 1, 2, 3 (40), 4 (Ad)
  int p1Pts = 0;
  int p2Pts = 0;
  int p1Games = 0;
  int p2Games = 0;
  int p1Sets = 0;
  int p2Sets = 0;

  bool isTiebreak = false;
  int p1TiebreakPts = 0;
  int p2TiebreakPts = 0;

  int serverPlayerNum = 1; // 1 = P1, 2 = P2
  bool p1OnLeft = true;
  List<TennisSetSummary> setSummaries = [];
  List<int> gameWinnersInCurrentSet = [];
  List<TennisLogEntry> logs = [];

  int matchTimeSeconds = 0;
  int? timerEndTime;
  String timerTitle = '';
  bool keepRunningTimers = true;

  final List<TennisMatchState> _history = [];
  final List<TennisMatchState> _redoHistory = [];
  int _lastSavedTimestamp = 0;

  Future<void> _persistMatch() async {
    _lastSavedTimestamp = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'p1Name': widget.p1Name,
      'p2Name': widget.p2Name,
      'p3Name': widget.p3Name,
      'p4Name': widget.p4Name,
      'isDoubles': widget.isDoubles,
      'setsToWin': widget.setsToWin,
      'p1Pts': p1Pts,
      'p2Pts': p2Pts,
      'p1Games': p1Games,
      'p2Games': p2Games,
      'p1Sets': p1Sets,
      'p2Sets': p2Sets,
      'isTiebreak': isTiebreak,
      'p1TiebreakPts': p1TiebreakPts,
      'p2TiebreakPts': p2TiebreakPts,
      'serverPlayerNum': serverPlayerNum,
      'p1OnLeft': p1OnLeft,
      'isFinished': isFinished,
      'setSummaries': setSummaries.map((s) => s.toMap()).toList(),
      'logs': logs.map((l) => l.toMap()).toList(),
      'matchTimeSeconds': matchTimeSeconds,
      'timerEndTime': timerEndTime,
      'timerTitle': timerTitle,
      'keepRunningTimers': keepRunningTimers,
      'lastSavedTimestamp': _lastSavedTimestamp,
      'matchId': widget.matchId,
    });
    await prefs.setString('active_tennis_match', data);
    if (_isHost && widget.matchId.isNotEmpty) _pushToCloud();
  }

  Future<void> _pushToCloud() async {
    _lastSavedTimestamp = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).set({
      'sport': 'Tennis',
      'hostUid': _authService.currentUser?.uid ?? '',
      'status': isFinished ? 'completed' : 'active',
      'matchData': {
        'p1Name': widget.p1Name,
        'p2Name': widget.p2Name,
        'p3Name': widget.p3Name,
        'p4Name': widget.p4Name,
        'isDoubles': widget.isDoubles,
        'setsToWin': widget.setsToWin,
        'p1Pts': p1Pts,
        'p2Pts': p2Pts,
        'p1Games': p1Games,
        'p2Games': p2Games,
        'p1Sets': p1Sets,
        'p2Sets': p2Sets,
        'isTiebreak': isTiebreak,
        'p1TiebreakPts': p1TiebreakPts,
        'p2TiebreakPts': p2TiebreakPts,
        'serverPlayerNum': serverPlayerNum,
        'p1OnLeft': p1OnLeft,
        'isFinished': isFinished,
        'setSummaries': setSummaries.map((s) => s.toMap()).toList(),
        'logs': logs.map((l) => l.toMap()).toList(),
        'matchTimeSeconds': matchTimeSeconds,
        'timerEndTime': timerEndTime,
        'timerTitle': timerTitle,
        'keepRunningTimers': keepRunningTimers,
        'lastSavedTimestamp': _lastSavedTimestamp,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _clearPersistedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_tennis_match');
  }

  @override
  void initState() {
    super.initState();
    keepRunningTimers = widget.initialKeepRunningTimers;
    _isHost = widget.isHost ?? (widget.matchId.isEmpty || widget.matchId.startsWith('tour_'));

    p1Pts = widget.initialP1Pts;
    p2Pts = widget.initialP2Pts;
    p1Games = widget.initialP1Games;
    p2Games = widget.initialP2Games;
    p1Sets = widget.initialP1Sets;
    p2Sets = widget.initialP2Sets;
    isTiebreak = widget.initialIsTiebreak;
    p1TiebreakPts = widget.initialP1TiebreakPts;
    p2TiebreakPts = widget.initialP2TiebreakPts;
    serverPlayerNum = widget.initialServerPlayerNum;
    p1OnLeft = widget.initialP1OnLeft;
    isFinished = widget.initialIsFinished;
    setSummaries = List.from(widget.initialSetSummaries);
    logs = List.from(widget.initialLogs);
    matchTimeSeconds = widget.initialMatchTimeSeconds;
    timerEndTime = widget.activeTimerEndTime;
    timerTitle = widget.activeTimerTitle;

    _startMatchClock();
    _listenToMatchStatus();

    if (_isHost && p1Pts == 0 && p2Pts == 0 && p1Games == 0 && p2Games == 0 && p1Sets == 0 && p2Sets == 0 && !isFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _promptToss();
      });
    }
  }

  @override
  void dispose() {
    _matchClock?.cancel();
    _activeTimer?.cancel();
    _matchSubscription?.cancel();
    super.dispose();
  }

  void _startMatchClock() {
    _matchClock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !isFinished) {
        setState(() => matchTimeSeconds++);
      }
    });
  }

  void _listenToMatchStatus() {
    if (widget.matchId.isEmpty) return;

    if (widget.matchId.startsWith('tour_')) {
      final parts = widget.matchId.split('_');
      if (parts.length >= 4) {
        final cId = parts[1];
        final tId = parts[2];
        final mId = parts.sublist(3).join('_');

        _matchSubscription = FirebaseFirestore.instance
            .collection('clubs')
            .doc(cId)
            .collection('tournaments')
            .doc(tId)
            .collection('matches')
            .doc(mId)
            .snapshots()
            .listen((doc) {
          if (doc.exists) {
            final data = doc.data() ?? {};
            if (data['status'] == 'completed' && !isFinished) {
              setState(() => isFinished = true);
            }
          }
        });
      }
      return;
    }

    _matchSubscription = FirebaseFirestore.instance
        .collection('active_matches')
        .doc(widget.matchId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final cloudHostUid = doc.get('hostUid');
        final currentUid = _authService.currentUser?.uid;
        _isHost = cloudHostUid == currentUid;

        if (!_isHost) {
          final data = doc.data()?['matchData'] ?? {};
          if (data.isNotEmpty) _syncFromCloud(data);
        }
      } else {
        if (!_isHost && mounted) {
          Navigator.pop(context);
          _showAppSnackBar(context, const SnackBar(content: Text('Match ended by host.')));
        }
      }
    });
  }

  void _syncFromCloud(Map<String, dynamic> data) {
    setState(() {
      p1Games = data['p1Games'] ?? p1Games;
      p2Games = data['p2Games'] ?? p2Games;
      p1Sets = data['p1Sets'] ?? p1Sets;
      p2Sets = data['p2Sets'] ?? p2Sets;
      isTiebreak = data['isTiebreak'] ?? isTiebreak;
      p1TiebreakPts = data['p1TiebreakPts'] ?? p1TiebreakPts;
      p2TiebreakPts = data['p2TiebreakPts'] ?? p2TiebreakPts;
      serverPlayerNum = data['serverPlayerNum'] ?? serverPlayerNum;
      p1OnLeft = data['p1OnLeft'] ?? p1OnLeft;
      timerEndTime = data['timerEndTime'];
      timerTitle = data['timerTitle'] ?? '';
    });
  }

  void _saveState() {
    _history.add(TennisMatchState(
      p1PointText: _getPointDisplay(1),
      p2PointText: _getPointDisplay(2),
      p1Games: p1Games,
      p2Games: p2Games,
      p1Sets: p1Sets,
      p2Sets: p2Sets,
      isTiebreak: isTiebreak,
      p1TiebreakPts: p1TiebreakPts,
      p2TiebreakPts: p2TiebreakPts,
      setSummaries: List.from(setSummaries),
      serverPlayerNum: serverPlayerNum,
      servingCourt: _getServingCourt(),
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
    ));
    if (_history.length > 30) _history.removeAt(0);
    _redoHistory.clear();
  }

  void _undo() {
    if (_history.isEmpty) return;
    _redoHistory.add(TennisMatchState(
      p1PointText: _getPointDisplay(1),
      p2PointText: _getPointDisplay(2),
      p1Games: p1Games,
      p2Games: p2Games,
      p1Sets: p1Sets,
      p2Sets: p2Sets,
      isTiebreak: isTiebreak,
      p1TiebreakPts: p1TiebreakPts,
      p2TiebreakPts: p2TiebreakPts,
      setSummaries: List.from(setSummaries),
      serverPlayerNum: serverPlayerNum,
      servingCourt: _getServingCourt(),
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
    ));
    final last = _history.removeLast();
    setState(() {
      p1Games = last.p1Games;
      p2Games = last.p2Games;
      p1Sets = last.p1Sets;
      p2Sets = last.p2Sets;
      isTiebreak = last.isTiebreak;
      p1TiebreakPts = last.p1TiebreakPts;
      p2TiebreakPts = last.p2TiebreakPts;
      serverPlayerNum = last.serverPlayerNum;
      p1OnLeft = last.p1OnLeft;
      setSummaries = List.from(last.setSummaries);
      logs = List.from(last.logs);
      matchTimeSeconds = last.matchTimeSeconds;
      timerEndTime = last.timerEndTime;
      timerTitle = last.timerTitle;
    });
    _persistMatch();
  }

  void _redo() {
    if (_redoHistory.isEmpty) return;
    _history.add(TennisMatchState(
      p1PointText: _getPointDisplay(1),
      p2PointText: _getPointDisplay(2),
      p1Games: p1Games,
      p2Games: p2Games,
      p1Sets: p1Sets,
      p2Sets: p2Sets,
      isTiebreak: isTiebreak,
      p1TiebreakPts: p1TiebreakPts,
      p2TiebreakPts: p2TiebreakPts,
      setSummaries: List.from(setSummaries),
      serverPlayerNum: serverPlayerNum,
      servingCourt: _getServingCourt(),
      p1OnLeft: p1OnLeft,
      logs: List.from(logs),
      matchTimeSeconds: matchTimeSeconds,
      timerEndTime: timerEndTime,
      timerTitle: timerTitle,
    ));
    final next = _redoHistory.removeLast();
    setState(() {
      p1Games = next.p1Games;
      p2Games = next.p2Games;
      p1Sets = next.p1Sets;
      p2Sets = next.p2Sets;
      isTiebreak = next.isTiebreak;
      p1TiebreakPts = next.p1TiebreakPts;
      p2TiebreakPts = next.p2TiebreakPts;
      serverPlayerNum = next.serverPlayerNum;
      p1OnLeft = next.p1OnLeft;
      setSummaries = List.from(next.setSummaries);
      logs = List.from(next.logs);
      matchTimeSeconds = next.matchTimeSeconds;
      timerEndTime = next.timerEndTime;
      timerTitle = next.timerTitle;
    });
    _persistMatch();
  }

  void _resetMatch() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset Match?'.tr),
        content: Text('All progress will be lost. This cannot be undone.'.tr),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Reset'.tr, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      _saveState();
      setState(() {
        p1Pts = 0;
        p2Pts = 0;
        p1Games = 0;
        p2Games = 0;
        p1Sets = 0;
        p2Sets = 0;
        isTiebreak = false;
        p1TiebreakPts = 0;
        p2TiebreakPts = 0;
        setSummaries.clear();
        gameWinnersInCurrentSet.clear();
        logs.clear();
        isFinished = false;
      });
      _persistMatch();
    }
  }

  Future<void> _promptToss() async {
    if (!_isHost) return;
    final int tossWinner = Random().nextBool() ? 1 : 2;
    final String winnerName = tossWinner == 1 ? widget.p1Name : widget.p2Name;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('Coin Toss Result'.tr),
        content: Text('$winnerName ${'won the coin toss!'.tr}'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('Continue'.tr))],
      ),
    );

    if (!mounted) return;
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('$winnerName: ${'Choose Option'.tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
        ],
      ),
    );

    if (choice != null) {
      setState(() {
        if (choice == 1) {
          serverPlayerNum = tossWinner;
        } else {
          serverPlayerNum = 3 - tossWinner;
        }
      });
    }

    _startTimer('5-Min Warmup'.tr, 300);
  }

  void _startTimer(String title, int seconds) {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      timerTitle = title;
      timerEndTime = now + (seconds * 1000);
    });

    _activeTimer?.cancel();
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final remaining = ((timerEndTime! - DateTime.now().millisecondsSinceEpoch) / 1000).ceil();
      if (remaining <= 0) {
        t.cancel();
        setState(() {
          timerEndTime = null;
          timerTitle = '';
        });
      } else {
        setState(() {});
      }
    });
  }

  String _getPointDisplay(int playerNum) {
    if (isTiebreak) {
      return playerNum == 1 ? '$p1TiebreakPts' : '$p2TiebreakPts';
    }

    int myPts = playerNum == 1 ? p1Pts : p2Pts;
    int oppPts = playerNum == 1 ? p2Pts : p1Pts;

    if (myPts >= 3 && oppPts >= 3) {
      if (myPts == oppPts) return '40'; // Deuce
      if (myPts > oppPts) return 'AD';
      return '40';
    }

    switch (myPts) {
      case 0:
        return '0';
      case 1:
        return '15';
      case 2:
        return '30';
      case 3:
        return '40';
      default:
        return '0';
    }
  }

  String _getServingCourt() {
    int totalPts = isTiebreak ? (p1TiebreakPts + p2TiebreakPts) : (p1Pts + p2Pts);
    return totalPts % 2 == 0 ? 'Deuce' : 'Ad';
  }

  void _addPoint(int playerNum) {
    if (isFinished || !_isHost || timerEndTime != null) return;
    _saveState();

    if (isTiebreak) {
      if (playerNum == 1) {
        p1TiebreakPts++;
      } else {
        p2TiebreakPts++;
      }

      int totalTb = p1TiebreakPts + p2TiebreakPts;
      if (totalTb % 2 == 1) {
        serverPlayerNum = 3 - serverPlayerNum;
      }
      if (totalTb % 6 == 0) {
        p1OnLeft = !p1OnLeft; // Change ends every 6 points
      }

      if ((p1TiebreakPts >= 7 || p2TiebreakPts >= 7) && (p1TiebreakPts - p2TiebreakPts).abs() >= 2) {
        _winGame(p1TiebreakPts > p2TiebreakPts ? 1 : 2);
      }
    } else {
      if (playerNum == 1) {
        p1Pts++;
      } else {
        p2Pts++;
      }

      if (p1Pts >= 4 && p1Pts - p2Pts >= 2) {
        _winGame(1);
      } else if (p2Pts >= 4 && p2Pts - p1Pts >= 2) {
        _winGame(2);
      } else if (p1Pts >= 3 && p2Pts >= 3 && (p1Pts - p2Pts).abs() == 0) {
        // Returned to deuce
      }
    }
    setState(() {});
    _persistMatch();
  }

  void _winGame(int winnerTeam) {
    p1Pts = 0;
    p2Pts = 0;
    p1TiebreakPts = 0;
    p2TiebreakPts = 0;
    isTiebreak = false;

    if (winnerTeam == 1) {
      p1Games++;
    } else {
      p2Games++;
    }
    gameWinnersInCurrentSet.add(winnerTeam);

    // Alternate server every game
    serverPlayerNum = 3 - serverPlayerNum;

    // Change ends at odd games
    int totalGamesInSet = p1Games + p2Games;
    if (totalGamesInSet % 2 == 1) {
      p1OnLeft = !p1OnLeft;
      _startTimer('90s Changeover Rest', 90);
    }

    if (p1Games == 6 && p2Games == 6) {
      isTiebreak = true;
    } else if ((p1Games >= 6 || p2Games >= 6) && (p1Games - p2Games).abs() >= 2) {
      _winSet(p1Games > p2Games ? 1 : 2);
    }
  }

  void _winSet(int setWinner) {
    setSummaries.add(TennisSetSummary(
      p1Games: p1Games,
      p2Games: p2Games,
      gameWinnersSequence: List.from(gameWinnersInCurrentSet),
    ));

    gameWinnersInCurrentSet.clear();
    p1Games = 0;
    p2Games = 0;

    if (setWinner == 1) {
      p1Sets++;
    } else {
      p2Sets++;
    }

    if (p1Sets >= widget.setsToWin || p2Sets >= widget.setsToWin) {
      isFinished = true;
      _clearPersistedMatch();
      _recordMatchResult();
    } else {
      _startTimer('120s Set Break Rest', 120);
    }
  }

  Future<void> _issueCodeViolation(int playerNum) async {
    final playerName = playerNum == 1 ? widget.p1Name : widget.p2Name;
    final playerViolations = logs.where((l) => l.type == 'code_violation' && l.playerNum == playerNum).toList();
    final count = playerViolations.length + 1;

    String previewDesc = count == 1
        ? '1st Violation: Warning'
        : count == 2
            ? '2nd Violation: Point Penalty (+1 Point to Opponent)'
            : count == 3
                ? '3rd Violation: Game Penalty (+1 Game to Opponent)'
                : '4th Violation: Disqualification / Default';

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Code Violation'.tr),
        content: Text('${"Issue code violation to".tr} $playerName?\n\n${previewDesc.tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'.tr),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    String cardType = 'warning';
    String desc = '1st Violation: Warning'.tr;

    if (count == 2) {
      cardType = 'point';
      desc = '2nd Violation: Point Penalty (+1 Point to Opponent)'.tr;
      _addPoint(3 - playerNum);
    } else if (count == 3) {
      cardType = 'game';
      desc = '3rd Violation: Game Penalty (+1 Game to Opponent)'.tr;
      _winGame(3 - playerNum);
    } else if (count >= 4) {
      cardType = 'default';
      desc = '4th Violation: Disqualification / Default'.tr;
      isFinished = true;
    }

    logs.add(TennisLogEntry(
      type: 'code_violation',
      playerNum: playerNum,
      cardType: cardType,
      reason: desc,
      setNum: p1Sets + p2Sets + 1,
      p1Games: p1Games,
      p2Games: p2Games,
      p1ScoreText: _getPointDisplay(1),
      p2ScoreText: _getPointDisplay(2),
    ));

    setState(() {});
    _persistMatch();
  }

  Future<void> _recordMatchResult() async {
    if (widget.matchId.startsWith('tour_')) {
      final parts = widget.matchId.split('_');
      if (parts.length >= 4) {
        final cId = parts[1];
        final tId = parts[2];
        final mId = parts.sublist(3).join('_');

        final String t1Name = widget.isDoubles ? '${widget.p1Name} & ${widget.p2Name}' : widget.p1Name;
        final String t2Name = widget.isDoubles ? '${widget.p3Name} & ${widget.p4Name}' : widget.p2Name;

        final winnerName = p1Sets > p2Sets ? t1Name : t2Name;
        final loserName = p1Sets > p2Sets ? t2Name : t1Name;

        await _authService.recordTournamentMatchResult(
          clubId: cId,
          tournamentId: tId,
          matchId: mId,
          winnerUid: winnerName,
          loserUid: loserName,
          scoreText: '$p1Sets-$p2Sets',
          logs: logs.map((l) => l.toMap()).toList(),
          setSummaries: setSummaries.map((s) => s.toMap()).toList(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String serverName = serverPlayerNum == 1 ? widget.p1Name : widget.p2Name;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        ScaffoldMessenger.of(context).clearSnackBars();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.p1Name} vs ${widget.p2Name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.history),
              tooltip: 'Point history'.tr,
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => TennisMatchHistoryBottomSheet(
                    allSets: setSummaries,
                    logs: logs,
                    p1Name: widget.p1Name,
                    p2Name: widget.p2Name,
                  ),
                );
              },
            ),
            IconButton(
              onPressed: (!_isHost || _history.isEmpty) ? null : _undo,
              icon: const Icon(Icons.undo),
              tooltip: 'Undo'.tr,
            ),
            IconButton(
              onPressed: (!_isHost || _redoHistory.isEmpty) ? null : _redo,
              icon: const Icon(Icons.redo),
              tooltip: 'Redo'.tr,
            ),
            IconButton(
              onPressed: _isHost ? _resetMatch : null,
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Match'.tr,
            ),
            PopupMenuButton<String>(
              onSelected: (val) async {
                if (val == 'discard') {
                  bool? confirm = await showDialog<bool>(
                    context: context,
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
                      await _authService.deleteActiveMatch(widget.matchId);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  }
                } else if (val == 'med1') {
                  _startTimer('Medical Timeout (${widget.p1Name})'.tr, 180);
                } else if (val == 'med2') {
                  _startTimer('Medical Timeout (${widget.p2Name})'.tr, 180);
                }
              },
              itemBuilder: (context) => [
                if (_isHost) PopupMenuItem(value: 'discard', child: Text('Discard Match'.tr, style: const TextStyle(color: Colors.red))),
                if (_isHost) PopupMenuItem(value: 'med1', child: Text('${"Medical Timeout".tr} (${widget.p1Name})')),
                if (_isHost) PopupMenuItem(value: 'med2', child: Text('${"Medical Timeout".tr} (${widget.p2Name})')),
              ],
            ),
          ],
        ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            children: [
              TennisPenaltyBanner(logs: logs, isDoubles: false, p1Name: widget.p1Name, p2Name: widget.p2Name),
              if (timerEndTime != null)
                TennisTimerBanner(
                  title: timerTitle,
                  endTime: timerEndTime!,
                  isHost: _isHost,
                  onSkip: () => setState(() => timerEndTime = null),
                ),
              const SizedBox(height: 12),
              Text(
                '${'Best of ${widget.setsToWin * 2 - 1} sets'.tr} • ${'Server'.tr}: $serverName (${_getServingCourt().tr} ${'Court'.tr})',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TennisTeamColumn(
                    teamNum: 1,
                    pointText: _getPointDisplay(1),
                    games: p1Games,
                    sets: p1Sets,
                    name: widget.isDoubles ? '${widget.p1Name} & ${widget.p2Name}' : widget.p1Name,
                    isServing: serverPlayerNum == 1,
                    servingCourt: _getServingCourt(),
                    side: p1OnLeft ? 'HOME' : 'AWAY',
                    isHost: _isHost,
                    isFinished: isFinished,
                    isTimerRunning: timerEndTime != null,
                    onPointAdd: () => _addPoint(1),
                    onCodeViolation: () => _issueCodeViolation(1),
                  ),
                  TennisTeamColumn(
                    teamNum: 2,
                    pointText: _getPointDisplay(2),
                    games: p2Games,
                    sets: p2Sets,
                    name: widget.isDoubles ? '${widget.p3Name} & ${widget.p4Name}' : widget.p2Name,
                    isServing: serverPlayerNum == 2,
                    servingCourt: _getServingCourt(),
                    side: p1OnLeft ? 'AWAY' : 'HOME',
                    isHost: _isHost,
                    isFinished: isFinished,
                    isTimerRunning: timerEndTime != null,
                    onPointAdd: () => _addPoint(2),
                    onCodeViolation: () => _issueCodeViolation(2),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (isFinished)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: Text('Confirm & Finish Match'.tr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        await _recordMatchResult();
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showAppSnackBar(context, SnackBar(content: Text('Tennis match concluded and saved successfully!'.tr)));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}
