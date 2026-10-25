import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import '../table_tennis/widgets/tt_stats.dart';
import 'badminton_models.dart';
import 'widgets/badminton_banners.dart';
import 'widgets/badminton_team_column.dart';

class BadmintonMatch extends StatefulWidget {
  final String p1Name, p2Name, p3Name, p4Name;
  final bool isDoubles, isHost;
  final int gamesToWin;
  final int initialP1Score, initialP2Score, initialP1Games, initialP2Games;
  final bool initialIsGameOver;
  final List<int> initialPointHistory;
  final List<BadmintonGameSummary> initialGameSummaries;
  final int initialFirstServerOfMatch, initialFirstServerOfGame;
  final bool initialP1OnLeft;
  final List<BadmintonLogEntry> initialLogs;
  final int initialMatchTimeSeconds;
  final int? activeTimerEndTime;
  final String activeTimerTitle;
  final bool initialKeepRunningTimers;
  final int? initialLastSavedTimestamp;
  final String matchId;

  const BadmintonMatch({
    super.key, required this.p1Name, required this.p2Name, this.p3Name = '', this.p4Name = '',
    required this.isDoubles, this.isHost = true, required this.gamesToWin,
    this.initialP1Score = 0, this.initialP2Score = 0, this.initialP1Games = 0, this.initialP2Games = 0,
    this.initialIsGameOver = false, this.initialPointHistory = const [],
    this.initialGameSummaries = const [], this.initialFirstServerOfMatch = 0,
    this.initialFirstServerOfGame = 0, this.initialP1OnLeft = true,
    this.initialLogs = const [], this.initialMatchTimeSeconds = 0,
    this.activeTimerEndTime, this.activeTimerTitle = '',
    this.initialKeepRunningTimers = false, this.initialLastSavedTimestamp,
    this.matchId = '',
  });

  @override
  State<BadmintonMatch> createState() => _BadmintonMatchState();
}

class _BadmintonMatchState extends State<BadmintonMatch> {
  late int p1Score, p2Score, p1Games, p2Games;
  late bool isGameOver, p1OnLeft;
  List<int> pointHistory = [];
  List<BadmintonGameSummary> gameSummaries = [];
  List<BadmintonLogEntry> logs = [];
  int matchTimeSeconds = 0;
  
  int? timerEndTime;
  String timerTitle = '';
  Timer? _activeTimer, _matchClock;
  
  late int firstServerOfMatch, firstServerOfGame;
  bool keepRunningTimers = false;
  int _lastSavedTimestamp = 0;
  final AuthService _authService = AuthService();
  StreamSubscription? _matchSubscription;
  final List<BadmintonMatchState> _history = [];
  final List<BadmintonMatchState> _redoHistory = [];

  @override
  void initState() {
    super.initState();
    p1Score = widget.initialP1Score; p2Score = widget.initialP2Score;
    p1Games = widget.initialP1Games; p2Games = widget.initialP2Games;
    isGameOver = widget.initialIsGameOver; p1OnLeft = widget.initialP1OnLeft;
    pointHistory = List<int>.from(widget.initialPointHistory);
    gameSummaries = List<BadmintonGameSummary>.from(widget.initialGameSummaries);
    logs = List<BadmintonLogEntry>.from(widget.initialLogs);
    matchTimeSeconds = widget.initialMatchTimeSeconds;
    firstServerOfMatch = widget.initialFirstServerOfMatch;
    firstServerOfGame = widget.initialFirstServerOfGame;
    timerEndTime = widget.activeTimerEndTime;
    timerTitle = widget.activeTimerTitle;
    keepRunningTimers = widget.initialKeepRunningTimers;
    _lastSavedTimestamp = widget.initialLastSavedTimestamp ?? DateTime.now().millisecondsSinceEpoch;

    if (keepRunningTimers && _lastSavedTimestamp > 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - _lastSavedTimestamp) ~/ 1000;
      if (elapsedSeconds > 0 && !isGameOver) {
        matchTimeSeconds += elapsedSeconds;
      }
    }
    _lastSavedTimestamp = DateTime.now().millisecondsSinceEpoch;

    _startMatchClock();
    _listenToMatchStatus();
    if (timerEndTime != null) _startLocalTimer(timerTitle, timerEndTime!);
    
    if (firstServerOfMatch == 0 && widget.isHost) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptToss());
    }
  }

  @override
  void dispose() {
    _activeTimer?.cancel(); _matchClock?.cancel(); _matchSubscription?.cancel();
    super.dispose();
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
            if (data['status'] == 'completed' && !isGameOver) {
              setState(() => isGameOver = true);
            }
          }
        });
      }
      return;
    }

    _matchSubscription = FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).snapshots().listen((doc) {
      if (!doc.exists) { if (!widget.isHost && mounted) Navigator.pop(context); return; }
      if (!widget.isHost) {
        final data = doc.data()?['matchData'] ?? {};
        if (data.isNotEmpty) _syncFromCloud(data);
      }
    });
  }

  void _syncFromCloud(Map<String, dynamic> data) {
    int cloudP1 = data['p1Score'] ?? p1Score;
    int cloudP2 = data['p2Score'] ?? p2Score;
    bool progressed = (cloudP1 + cloudP2) > (p1Score + p2Score);

    if (progressed && mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      p1Score = cloudP1; p2Score = cloudP2;
      p1Games = data['p1Games'] ?? p1Games; p2Games = data['p2Games'] ?? p2Games;
      isGameOver = data['isGameOver'] ?? isGameOver;
      pointHistory = List<int>.from(data['pointHistory'] ?? pointHistory);
      firstServerOfMatch = data['firstServerOfMatch'] ?? firstServerOfMatch;
      firstServerOfGame = data['firstServerOfGame'] ?? firstServerOfGame;
      p1OnLeft = data['p1OnLeft'] ?? p1OnLeft;
      matchTimeSeconds = data['matchTimeSeconds'] ?? matchTimeSeconds;
      keepRunningTimers = data['keepRunningTimers'] ?? keepRunningTimers;
      
      int? newEndTime = data['timerEndTime'];
      if (newEndTime != null && newEndTime != timerEndTime) {
        timerEndTime = newEndTime; timerTitle = data['timerTitle'] ?? '';
        _startLocalTimer(timerTitle, newEndTime);
      } else if (newEndTime == null) { _activeTimer?.cancel(); timerEndTime = null; }

      if (data['gameSummaries'] != null) {
        gameSummaries = (data['gameSummaries'] as List)
            .map((s) => BadmintonGameSummary.fromMap(s))
            .toList();
      }

      if (data['logs'] != null) {
        logs = (data['logs'] as List).map((l) => BadmintonLogEntry.fromMap(l)).toList();
      }
      
      // ... same logic for decider switch ...

      if (!widget.isHost && progressed) {
         if ((p1Score + p2Score) % 6 == 0 && !isGameOver) {
           // Standard reminder, though BWF doesn't have 6-point towel rule like ITTF
         }
         if (_isDecider && (p1Score == 11 || p2Score == 11)) {
           ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(content: Text('Decider: Switch Ends! ↔️'), backgroundColor: Colors.orange, duration: Duration(minutes: 5)));
         }
      }
    });
  }

  void _startMatchClock() {
    _matchClock = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!isGameOver && timerEndTime == null) setState(() => matchTimeSeconds++);
    });
  }

  void _startLocalTimer(String title, int endTime) {
    _activeTimer?.cancel();
    _activeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      int remaining = ((endTime - DateTime.now().millisecondsSinceEpoch) / 1000).round();
      if (remaining <= 0) { _stopTimer(); } else { setState(() => timerTitle = title); }
    });
  }

  void _stopTimer() {
    _activeTimer?.cancel();
    setState(() { timerEndTime = null; timerTitle = ''; });
    if (isGameOver && widget.isHost) _prepareNextGame();
  }

  void _prepareNextGame() {
    setState(() {
      p1Score = 0; p2Score = 0; pointHistory = []; isGameOver = false;
      p1OnLeft = !p1OnLeft; 
      int lastWinner = gameSummaries.last.p1Score > gameSummaries.last.p2Score ? 1 : 2;
      firstServerOfGame = widget.isDoubles ? (lastWinner == 1 ? 1 : 3) : (lastWinner == 1 ? 1 : 2);
    });
    _persistMatch();
  }

  Future<void> _persistMatch() async {
    _lastSavedTimestamp = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode({
      'p1Name': widget.p1Name, 'p2Name': widget.p2Name, 'p3Name': widget.p3Name, 'p4Name': widget.p4Name,
      'isDoubles': widget.isDoubles, 'p1Score': p1Score, 'p2Score': p2Score, 'p1Games': p1Games, 'p2Games': p2Games,
      'isGameOver': isGameOver, 'pointHistory': pointHistory, 'gameSummaries': gameSummaries.map((s) => s.toMap()).toList(),
      'firstServerOfMatch': firstServerOfMatch, 'firstServerOfGame': firstServerOfGame, 'p1OnLeft': p1OnLeft,
      'logs': logs.map((l) => l.toMap()).toList(), 'matchTimeSeconds': matchTimeSeconds, 'timerEndTime': timerEndTime,
      'timerTitle': timerTitle, 'keepRunningTimers': keepRunningTimers, 'lastSavedTimestamp': _lastSavedTimestamp,
      'matchId': widget.matchId,
    });
    await prefs.setString('active_badminton_match', data);
    if (widget.isHost && widget.matchId.isNotEmpty) _pushToCloud();
  }

  Future<void> _pushToCloud() async {
    _lastSavedTimestamp = DateTime.now().millisecondsSinceEpoch;
    await FirebaseFirestore.instance.collection('active_matches').doc(widget.matchId).update({
      'matchData': {
        'p1Name': widget.p1Name,
        'p2Name': widget.p2Name,
        'p3Name': widget.p3Name,
        'p4Name': widget.p4Name,
        'isDoubles': widget.isDoubles,
        'gamesToWin': widget.gamesToWin,
        'p1Score': p1Score,
        'p2Score': p2Score,
        'p1Games': p1Games,
        'p2Games': p2Games,
        'isGameOver': isGameOver,
        'pointHistory': pointHistory,
        'gameSummaries': gameSummaries.map((s) => s.toMap()).toList(),
        'firstServerOfMatch': firstServerOfMatch,
        'firstServerOfGame': firstServerOfGame,
        'p1OnLeft': p1OnLeft,
        'timerEndTime': timerEndTime,
        'timerTitle': timerTitle,
        'logs': logs.map((l) => l.toMap()).toList(),
        'matchTimeSeconds': matchTimeSeconds,
        'keepRunningTimers': keepRunningTimers,
        'lastSavedTimestamp': _lastSavedTimestamp,
      },
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  void _saveState() {
    _history.add(BadmintonMatchState(
      p1Score: p1Score, p2Score: p2Score, p1Games: p1Games, p2Games: p2Games, isGameOver: isGameOver,
      pointHistory: List<int>.from(pointHistory), gameSummaries: List.from(gameSummaries),
      firstServerOfMatch: firstServerOfMatch, firstServerOfGame: firstServerOfGame, p1OnLeft: p1OnLeft,
      logs: List.from(logs), matchTimeSeconds: matchTimeSeconds, timerEndTime: timerEndTime, timerTitle: timerTitle,
    ));
    if (_history.length > 30) _history.removeAt(0);
    _redoHistory.clear();
  }

  Future<void> _promptToss() async {
    if (!widget.isHost) return;

    int winnerTeam = Random().nextBool() ? 1 : 2;
    String winnerName = widget.isDoubles ? "Team $winnerTeam" : (winnerTeam == 1 ? widget.p1Name : widget.p2Name);

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

    // BWF Law 6.1: The side winning the toss shall exercise the choice in either 6.1.1 or 6.1.2:
    // 6.1.1 to serve or receive first;
    // 6.1.2 to start play at one end of the court or the other.
    if (!mounted) return;
    int? choice = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text('$winnerName: ${"Choose Your Advantage".tr}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Choose Service'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Choose Side (Home/Away)'.tr)),
          TextButton(onPressed: () => Navigator.pop(c, 3), child: Text('Let Opponent Choose'.tr)),
        ],
      ),
    );
    if (!mounted) return;

    bool p1StartsLeft = widget.initialP1OnLeft;
    int firstServer = 1;

    if (choice == 3) {
      // Defer choice to loser
      int loserTeam = 3 - winnerTeam;
      String loserName = widget.isDoubles ? "Team $loserTeam" : (loserTeam == 1 ? widget.p1Name : widget.p2Name);

      int? loserChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Opponent deferred to you!".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Choose Service'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Choose Side'.tr)),
          ],
        ),
      );
      if (!mounted) return;

      if (loserChoice == 1) {
        // Loser chooses Service
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
        if (!mounted) return;
        int servingTeam = (serviceChoice == 1) ? loserTeam : (3 - loserTeam);
        firstServer = widget.isDoubles ? (servingTeam == 1 ? 1 : 3) : servingTeam;

        // Winner gets Side
        int? sideChoice = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text('$winnerName: ${"Choose Side (Home/Away)".tr}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
              TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
            ],
          ),
        );
        if (!mounted) return;
        p1StartsLeft = (sideChoice == 1) ? (winnerTeam == 1) : (winnerTeam != 1);
      } else {
        // Loser chooses Side
        int? sideChoice = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text('$loserName: ${"Choose Side (Home/Away)".tr}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
              TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
            ],
          ),
        );
        if (!mounted) return;
        p1StartsLeft = (sideChoice == 1) ? (loserTeam == 1) : (loserTeam != 1);

        // Winner gets Service
        int? serviceChoice = await showDialog<int>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            title: Text('$winnerName: ${"Serve or Receive?".tr}'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
              TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
            ],
          ),
        );
        if (!mounted) return;
        int servingTeam = (serviceChoice == 1) ? winnerTeam : (3 - winnerTeam);
        firstServer = widget.isDoubles ? (servingTeam == 1 ? 1 : 3) : servingTeam;
      }
    } else if (choice == 1) {
      // Winner chooses Service
      int? serviceChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$winnerName: ${"Serve or Receive?".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Serve First'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Receive First'.tr)),
          ],
        ),
      );
      if (!mounted) return;
      
      // If winner chooses to serve, they serve. If they choose receive, the other team serves.
      int servingTeam = (serviceChoice == 1) ? winnerTeam : (3 - winnerTeam);
      firstServer = (servingTeam == 1) ? 1 : 3;

      // Loser chooses Side
      String loserName = (3 - winnerTeam) == 1 ? widget.p1Name : widget.p3Name;
      if (widget.isDoubles) loserName = "Team ${3 - winnerTeam}";
      
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$loserName: ${"Choose Side (Home/Away)".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
          ],
        ),
      );
      if (!mounted) return;
      p1StartsLeft = (sideChoice == 1) ? ((3 - winnerTeam) == 1) : ((3 - winnerTeam) != 1);

    } else {
      // Winner chooses Side
      int? sideChoice = await showDialog<int>(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: Text('$winnerName: ${"Choose Side (Home/Away)".tr}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, 1), child: Text('Start on Home Side'.tr)),
            TextButton(onPressed: () => Navigator.pop(c, 2), child: Text('Start on Away Side'.tr)),
          ],
        ),
      );
      if (!mounted) return;
      p1StartsLeft = (sideChoice == 1) ? (winnerTeam == 1) : (winnerTeam != 1);

      // Loser chooses Service
      String loserName = (3 - winnerTeam) == 1 ? widget.p1Name : widget.p3Name;
      if (widget.isDoubles) loserName = "Team ${3 - winnerTeam}";

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
      int servingTeam = (serviceChoice == 1) ? (3 - winnerTeam) : winnerTeam;
      firstServer = (servingTeam == 1) ? 1 : 3;
    }

    setState(() {
      firstServerOfMatch = firstServer;
      firstServerOfGame = firstServer;
      p1OnLeft = p1StartsLeft;
    });
    _persistMatch();
  }

  Map<String, dynamic> _calculateStats(int teamNum) {
    int totalPoints = 0, pointsOnServe = 0, servesTotal = 0, longestStreak = 0, currentStreak = 0;
    bool isCalcTeam1 = teamNum == 1;
    List<BadmintonGameSummary> allGames = List.from(gameSummaries);
    if (pointHistory.isNotEmpty || p1Score > 0 || p2Score > 0) { 
      allGames.add(BadmintonGameSummary(p1Score: p1Score, p2Score: p2Score, pointSequence: List.from(pointHistory), firstServer: firstServerOfGame)); 
    }
    
    for (int i = 0; i < allGames.length; i++) {
      final game = allGames[i];
      if (game.firstServer == 0) continue;
      
      int p1PointsInGame = 0, p2PointsInGame = 0;
      int currentServer = game.firstServer;
      
      // Doubles positions track
      List<int> positions = widget.isDoubles ? [1, 2, 3, 4] : [1, 1, 2, 2];

      for (int winner in game.pointSequence) {
        bool isServerTeam1 = (currentServer <= 2);
        bool pointWonByTeam1 = (winner == 1);
        bool calcTeamWonPoint = (isCalcTeam1 == pointWonByTeam1);
        bool calcTeamIsServing = (isCalcTeam1 == isServerTeam1);

        if (calcTeamWonPoint) {
           totalPoints++; currentStreak++; if (currentStreak > longestStreak) longestStreak = currentStreak; 
           if (calcTeamIsServing) pointsOnServe++; 
        } else { currentStreak = 0; }
        if (calcTeamIsServing) servesTotal++;

        // Update for next point simulation
        if (winner == 1) {
          if (currentServer <= 2) {
            if (widget.isDoubles) {
              int tmp = positions[0]; positions[0] = positions[1]; positions[1] = tmp;
            }
          } else {
            currentServer = (p1PointsInGame + 1) % 2 == 0 ? positions[0] : positions[1];
          }
          p1PointsInGame++;
        } else {
          if (currentServer >= 3) {
            if (widget.isDoubles) {
              int tmp = positions[2]; positions[2] = positions[3]; positions[3] = tmp;
            }
          } else {
            currentServer = (p2PointsInGame + 1) % 2 == 0 ? positions[2] : positions[3];
          }
          p2PointsInGame++;
        }
      }
      currentStreak = 0;
    }
    return {'totalPoints': totalPoints, 'serveWinRate': servesTotal > 0 ? (pointsOnServe / servesTotal * 100) : 0.0, 'longestStreak': longestStreak};
  }

  void _updateScore(int team, int delta) {
    if (timerEndTime != null || isGameOver) return; // Block changes during break or if game is over
    if (delta > 0) {
      _saveState();
    }
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      if (team == 1) {
        p1Score = max(0, p1Score + delta);
      } else {
        p2Score = max(0, p2Score + delta);
      }
      if (delta > 0) {
        pointHistory.add(team);
        _checkGameWinner();
        if ((p1Score == 11 && p2Score < 11) || (p2Score == 11 && p1Score < 11)) {
          _startTimer('Interval', 60);
          if (_isDecider) {
            p1OnLeft = !p1OnLeft; 
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(const SnackBar(
              content: Text('Decider: Switch Ends! ↔️'), 
              backgroundColor: Colors.orange, 
              duration: Duration(minutes: 30)
            ));
          }
        }
      } else if (pointHistory.isNotEmpty) {
        pointHistory.removeLast();
      }
    });
    _persistMatch();
  }

  void _issuePenalty(int playerNum, String type) async {
    if (timerEndTime != null) return; // Block during break
    
    final TextEditingController reasonController = TextEditingController();
    int actualPlayerNum = playerNum;
    int teamNum = playerNum <= 2 ? 1 : 2;

    if (widget.isDoubles && type != 'black') {
      int? selected = await showDialog<int>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Which player?'.tr),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ListTile(title: Text(teamNum == 1 ? widget.p1Name : widget.p3Name), onTap: () => Navigator.pop(context, teamNum == 1 ? 1 : 3)),
              ListTile(title: Text(teamNum == 1 ? widget.p2Name : widget.p4Name), onTap: () => Navigator.pop(context, teamNum == 1 ? 2 : 4)),
            ]),
          ),
        ),
      );
      if (selected == null) return;
      if (!mounted) return;
      actualPlayerNum = selected;
    }

    int teamYellows = logs.where((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! <= 2 ? 1 : 2) == teamNum).length;
    bool teamBlacked = logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! <= 2 ? 1 : 2) == teamNum);

    if (teamBlacked) return;

    if (type == 'yellow') {
      if (teamYellows > 0) {
        _showError("A warning (Yellow Card) has already been issued to this side.".tr);
        return;
      }
    }

    String cardName = type == 'yellow' ? 'Yellow Card (Warning)'.tr : type == 'red' ? 'Red Card (Fault + 1 pt)'.tr : 'Black Card (Disqualification)'.tr;
    
    String? reason = await showDialog<String>(
      context: context, 
      builder: (context) => AlertDialog(
        title: Text('${"Issue".tr} $cardName'), 
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonController, 
                decoration: InputDecoration(hintText: 'Reason (Optional)'.tr, border: const OutlineInputBorder()), 
                autofocus: true,
              ),
            ],
          ),
        ), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)), 
          ElevatedButton(onPressed: () => Navigator.pop(context, reasonController.text.trim()), child: Text('Confirm'.tr))
        ]
      )
    );

    if (reason == null) return;
    if (!mounted) return;

    _saveState();
    setState(() {
      if (type == 'red') {
        // Award point to opponent
        if (teamNum == 1) {
          p2Score = max(0, p2Score + 1);
        } else {
          p1Score = max(0, p1Score + 1);
        }
        pointHistory.add(teamNum == 1 ? 2 : 1);
        _checkGameWinner();
      } else if (type == 'black') {
        isGameOver = true;
        // Winner is the other team
        if (teamNum == 1) {
          p2Games = widget.gamesToWin;
        } else {
          p1Games = widget.gamesToWin;
        }
      }
      logs.add(BadmintonLogEntry(
        type: 'penalty', 
        playerNum: actualPlayerNum, 
        cardType: type, 
        detail: reason.isEmpty ? 'Misconduct' : reason,
        gameNum: gameSummaries.length + 1, 
        p1Score: p1Score, 
        p2Score: p2Score
      ));
    });
    _persistMatch();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  void _startTimer(String title, int seconds) {
    int end = DateTime.now().millisecondsSinceEpoch + (seconds * 1000);
    setState(() { timerEndTime = end; timerTitle = title; });
    _startLocalTimer(title, end);
    _persistMatch();
  }

  void _checkGameWinner() {
    bool win = false;
    if ((p1Score >= 21 || p2Score >= 21) && (p1Score - p2Score).abs() >= 2) win = true;
    if (p1Score == 30 || p2Score == 30) win = true;

    if (win) {
      if (p1Score > p2Score) {
        p1Games++;
      } else {
        p2Games++;
      }
      gameSummaries.add(BadmintonGameSummary(p1Score: p1Score, p2Score: p2Score, pointSequence: List.from(pointHistory), firstServer: firstServerOfGame));
      isGameOver = true;
      if (p1Games < widget.gamesToWin && p2Games < widget.gamesToWin) {
        _startTimer('Game Break', 120);
      }
    }
  }

  bool get _allPointsReset =>
      p1Score == 0 &&
      p2Score == 0 &&
      p1Games == 0 &&
      p2Games == 0 &&
      pointHistory.isEmpty &&
      gameSummaries.isEmpty;

  bool get _isDecider => (p1Games + p2Games) == (widget.gamesToWin * 2) - 2;

  BadmintonServerResults get _rotation => BadmintonRotationLogic.getRotationAtPoint(
    firstServer: firstServerOfGame, isDoubles: widget.isDoubles, isDecider: _isDecider, pointSequence: pointHistory,
  );

  void _resetMatch() {
    _saveState();
    setState(() {
      p1Score = 0; p2Score = 0; p1Games = 0; p2Games = 0;
      isGameOver = false; pointHistory = []; gameSummaries = [];
      logs = []; matchTimeSeconds = 0; timerEndTime = null; timerTitle = '';
      firstServerOfMatch = 0; firstServerOfGame = 0;
      p1OnLeft = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _promptToss());
    });
    _persistMatch();
  }

  @override
  Widget build(BuildContext context) {
    final res = _rotation;
    return Scaffold(
      appBar: AppBar(title: Text('Badminton Scoreboard'.tr), actions: [
        IconButton(icon: const Icon(Icons.info_outline), onPressed: () {
          showDialog(context: context, builder: (c) => AlertDialog(
            title: Text('BWF Rules'.tr),
            content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('• Rally point to 21. Win by 2.'.tr),
              Text('• Cap at 30 points (Golden Point).'.tr),
              Text('• Best of 3 games.'.tr),
              Text('• Intervals: 60s at 11 pts, 120s between games.'.tr),
              Text('• Change ends at 11 pts in Decider (Game 3).'.tr),
              Text('• Red Card: Fault + Point to Opponent.'.tr),
            ])),
            actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text('OK'.tr))],
          ));
        }),
        IconButton(icon: const Icon(Icons.undo), onPressed: (!widget.isHost || (_history.isEmpty && !_allPointsReset)) ? null : () {
          final bool wasAllPointsReset = _allPointsReset;

          if (_history.isNotEmpty) {
            _redoHistory.add(BadmintonMatchState(
              p1Score: p1Score, p2Score: p2Score, p1Games: p1Games, p2Games: p2Games, isGameOver: isGameOver,
              pointHistory: List<int>.from(pointHistory), gameSummaries: List.from(gameSummaries),
              firstServerOfMatch: firstServerOfMatch, firstServerOfGame: firstServerOfGame, p1OnLeft: p1OnLeft,
              logs: List.from(logs), matchTimeSeconds: matchTimeSeconds, timerEndTime: timerEndTime, timerTitle: timerTitle,
            ));
            final s = _history.removeLast();
            setState(() {
              p1Score = s.p1Score; p2Score = s.p2Score; p1Games = s.p1Games; p2Games = s.p2Games;
              isGameOver = s.isGameOver; pointHistory = s.pointHistory; gameSummaries = s.gameSummaries;
              firstServerOfGame = s.firstServerOfGame; p1OnLeft = s.p1OnLeft; logs = s.logs;
            });
            _persistMatch();
          }

          if (wasAllPointsReset) {
            setState(() {
              firstServerOfMatch = 0;
              firstServerOfGame = 0;
            });
            _persistMatch();
            WidgetsBinding.instance.addPostFrameCallback((_) => _promptToss());
          }
        }),
        IconButton(icon: const Icon(Icons.redo), onPressed: _redoHistory.isEmpty || !widget.isHost ? null : () {
          _history.add(BadmintonMatchState(
            p1Score: p1Score, p2Score: p2Score, p1Games: p1Games, p2Games: p2Games, isGameOver: isGameOver,
            pointHistory: List<int>.from(pointHistory), gameSummaries: List.from(gameSummaries),
            firstServerOfMatch: firstServerOfMatch, firstServerOfGame: firstServerOfGame, p1OnLeft: p1OnLeft,
            logs: List.from(logs), matchTimeSeconds: matchTimeSeconds, timerEndTime: timerEndTime, timerTitle: timerTitle,
          ));
          final s = _redoHistory.removeLast();
          setState(() {
            p1Score = s.p1Score; p2Score = s.p2Score; p1Games = s.p1Games; p2Games = s.p2Games;
            isGameOver = s.isGameOver; pointHistory = s.pointHistory; gameSummaries = s.gameSummaries;
            firstServerOfGame = s.firstServerOfGame; p1OnLeft = s.p1OnLeft; logs = s.logs;
          });
          _persistMatch();
        }),
        IconButton(icon: const Icon(Icons.refresh), onPressed: !widget.isHost ? null : () {
          showDialog(context: context, builder: (c) => AlertDialog(
            title: Text('Reset Match?'.tr),
            content: Text('All progress will be lost. This cannot be undone.'.tr),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: Text('Cancel'.tr)),
              TextButton(onPressed: () { Navigator.pop(c); _resetMatch(); }, child: Text('Reset'.tr, style: const TextStyle(color: Colors.red))),
            ],
          ));
        }),
        PopupMenuButton<String>(
          onSelected: (val) async {
            if (val == 'discard') {
              if (widget.isHost) _authService.deleteActiveMatch(widget.matchId);
              Navigator.pop(context);
            }
          },
          itemBuilder: (c) => [if (widget.isHost) PopupMenuItem(value: 'discard', child: Text('Discard Match'.tr, style: const TextStyle(color: Colors.red)))],
        )
      ]),
      body: Column(children: [
        BadmintonSuspensionBanner(logs: logs, isDoubles: widget.isDoubles, p1Name: widget.p1Name, p3Name: widget.p3Name),
        if (timerEndTime != null) BadmintonTimerBanner(title: timerTitle, endTime: timerEndTime!, isHost: widget.isHost, onSkip: _stopTimer),
        const SizedBox(height: 20),
        Text('Best of ${widget.gamesToWin * 2 - 1} games'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          BadmintonTeamColumn(
            team: 1, score: p1Score, games: p1Games, names: widget.isDoubles ? [widget.p1Name, widget.p2Name] : [widget.p1Name, ''],
            isDoubles: widget.isDoubles, isServing: res.server <= 2, serverNum: res.server, receiverNum: res.receiver,
            side: p1OnLeft ? 'HOME' : 'AWAY', isHost: widget.isHost, isTimerRunning: timerEndTime != null,
            onScore: () => _updateScore(1, 1),
            onYellow: () => _issuePenalty(1, 'yellow'), onRed: () => _issuePenalty(1, 'red'),
            onBlack: () => _issuePenalty(1, 'black'),
            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! <= 2)),
            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! <= 2)),
            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! <= 2)),
            pointHistory: pointHistory, firstServer: firstServerOfGame,
          ),
          BadmintonTeamColumn(
            team: 2, score: p2Score, games: p2Games, names: widget.isDoubles ? [widget.p3Name, widget.p4Name] : [widget.p2Name, ''],
            isDoubles: widget.isDoubles, isServing: res.server >= 3, serverNum: res.server, receiverNum: res.receiver,
            side: p1OnLeft ? 'AWAY' : 'HOME', isHost: widget.isHost, isTimerRunning: timerEndTime != null,
            onScore: () => _updateScore(2, 1),
            onYellow: () => _issuePenalty(3, 'yellow'), onRed: () => _issuePenalty(3, 'red'),
            onBlack: () => _issuePenalty(3, 'black'),
            hasYellow: logs.any((l) => l.type == 'penalty' && l.cardType == 'yellow' && (l.playerNum! >= 3)),
            hasRed: logs.any((l) => l.type == 'penalty' && l.cardType == 'red' && (l.playerNum! >= 3)),
            isBlacked: logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && (l.playerNum! >= 3)),
            pointHistory: pointHistory, firstServer: firstServerOfGame,
          ),
        ]),
        const SizedBox(height: 30),
        if (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ...[
          MatchStatsSummary(s1: _calculateStats(1), s2: _calculateStats(2)),
          const SizedBox(height: 20)
        ],
        Padding(padding: const EdgeInsets.symmetric(horizontal: 40.0), child: ElevatedButton(
          onPressed: (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ? () async { 
            await _recordMatchResult();
            if (widget.matchId.isNotEmpty && widget.isHost) {
              await _authService.deleteActiveMatch(widget.matchId);
            }
            await _clearPersistedMatch(); 
            if (!context.mounted) return; 
            Navigator.pop(context); 
            ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(SnackBar(content: Text(isBlackedMatch ? 'Match concluded and saved (Disqualification).'.tr : 'Match finished and saved successfully!'.tr)));
          } : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(55), 
            backgroundColor: (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ? Colors.amber : Colors.grey.withValues(alpha: 0.1), 
            disabledBackgroundColor: Colors.grey.withValues(alpha: 0.1), 
            foregroundColor: Colors.white, 
            disabledForegroundColor: Colors.white.withValues(alpha: 0.3), 
            elevation: (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ? 8 : 0, 
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
          ),
          child: Text((p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ? 'CONCLUDE MATCH'.tr : 'Finish Match'.tr, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: (p1Games >= widget.gamesToWin || p2Games >= widget.gamesToWin || isBlackedMatch) ? 1.2 : 0)),
        )),
        const SizedBox(height: 40),
      ]),
    );
  }

  Future<void> _recordMatchResult() async {
    if (widget.matchId.startsWith('tour_')) {
      final parts = widget.matchId.split('_');
      if (parts.length >= 4) {
        final cId = parts[1];
        final tId = parts[2];
        final mId = parts.sublist(3).join('_');

        final winnerName = p1Games > p2Games ? widget.p1Name : widget.p2Name;
        final loserName = p1Games > p2Games ? widget.p2Name : widget.p1Name;

        await _authService.recordTournamentMatchResult(
          clubId: cId,
          tournamentId: tId,
          matchId: mId,
          winnerUid: winnerName,
          loserUid: loserName,
          scoreText: '$p1Games-$p2Games',
          logs: logs.map((l) => l.toMap()).toList(),
        );
      }
    }
  }

  bool get isBlackedMatch => logs.any((l) => l.type == 'penalty' && l.cardType == 'black');

  Future<void> _clearPersistedMatch() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_badminton_match');
  }
}
