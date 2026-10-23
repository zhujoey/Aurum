import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
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

  @override
  void initState() {
    super.initState();
    keepRunningTimers = widget.initialKeepRunningTimers;
    _isHost = widget.isHost ?? (widget.matchId.isEmpty || widget.matchId.startsWith('tour_'));

    _startMatchClock();
    _listenToMatchStatus();

    if (_isHost) {
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
      timerEndTime = last.timerEndTime;
      timerTitle = last.timerTitle;
    });
  }

  Future<void> _promptToss() async {
    if (!_isHost) return;
    final int tossWinner = Random().nextBool() ? 1 : 2;
    final String winnerName = tossWinner == 1 ? widget.p1Name : widget.p2Name;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text('Coin Toss Result'),
        content: Text('$winnerName won the coin toss!'),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Continue'))],
      ),
    );

    if (!mounted) return;
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('$winnerName: Choose Option'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 1), child: const Text('Serve First')),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: const Text('Receive First')),
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

    _startTimer('5-Min Warmup', 300);
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
    if (isFinished || !_isHost) return;
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
      _recordMatchResult();
    } else {
      _startTimer('120s Set Break Rest', 120);
    }
  }

  void _issueCodeViolation(int playerNum) {
    final playerViolations = logs.where((l) => l.type == 'code_violation' && l.playerNum == playerNum).toList();
    final count = playerViolations.length + 1;

    String cardType = 'warning';
    String desc = '1st Violation: Warning';

    if (count == 2) {
      cardType = 'point';
      desc = '2nd Violation: Point Penalty (+1 Point to Opponent)';
      _addPoint(3 - playerNum);
    } else if (count == 3) {
      cardType = 'game';
      desc = '3rd Violation: Game Penalty (+1 Game to Opponent)';
      _winGame(3 - playerNum);
    } else if (count >= 4) {
      cardType = 'default';
      desc = '4th Violation: Disqualification / Default';
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

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.p1Name} vs ${widget.p2Name}'),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: _history.isNotEmpty ? _undo : null),
          IconButton(
            icon: const Icon(Icons.history),
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
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'discard') {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Discard Match?'),
                    content: const Text('Are you sure you want to discard this match? Progress will be lost.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        child: const Text('Discard'),
                      ),
                    ],
                  ),
                );
              } else if (val == 'toss') {
                _promptToss();
              } else if (val == 'warmup') {
                _startTimer('5-Min Warmup', 300);
              }
            },
            itemBuilder: (context) => [
              if (_isHost) const PopupMenuItem(value: 'toss', child: Text('Coin Toss')),
              if (_isHost) const PopupMenuItem(value: 'warmup', child: Text('Start 5-Min Warmup')),
              if (_isHost) const PopupMenuItem(value: 'discard', child: Text('Discard Match', style: TextStyle(color: Colors.red))),
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
                'ITF Best of ${widget.setsToWin * 2 - 1} Sets • Server: $serverName (${_getServingCourt()} Court)',
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
                    onPointAdd: () => _addPoint(1),
                    onCodeViolation: () => _issueCodeViolation(1),
                    onMedicalTimeout: () => _startTimer('Medical Timeout (P1)', 180),
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
                    onPointAdd: () => _addPoint(2),
                    onCodeViolation: () => _issueCodeViolation(2),
                    onMedicalTimeout: () => _startTimer('Medical Timeout (P2)', 180),
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
                      label: const Text('Confirm & Finish Match', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () async {
                        await _recordMatchResult();
                        if (context.mounted) {
                          Navigator.pop(context);
                          _showAppSnackBar(context, const SnackBar(content: Text('Tennis match concluded and saved successfully!')));
                        }
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
