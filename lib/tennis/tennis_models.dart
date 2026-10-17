import 'package:flutter/material.dart';

class TennisSetSummary {
  final int p1Games;
  final int p2Games;
  final int? tiebreakP1Pts;
  final int? tiebreakP2Pts;
  final List<int> gameWinnersSequence; // 1 for P1, 2 for P2

  TennisSetSummary({
    required this.p1Games,
    required this.p2Games,
    this.tiebreakP1Pts,
    this.tiebreakP2Pts,
    required this.gameWinnersSequence,
  });

  Map<String, dynamic> toMap() => {
    'p1Games': p1Games,
    'p2Games': p2Games,
    'tiebreakP1Pts': tiebreakP1Pts,
    'tiebreakP2Pts': tiebreakP2Pts,
    'gameWinnersSequence': gameWinnersSequence,
  };

  factory TennisSetSummary.fromMap(Map<String, dynamic> map) => TennisSetSummary(
    p1Games: map['p1Games'] ?? 0,
    p2Games: map['p2Games'] ?? 0,
    tiebreakP1Pts: map['tiebreakP1Pts'],
    tiebreakP2Pts: map['tiebreakP2Pts'],
    gameWinnersSequence: List<int>.from(map['gameWinnersSequence'] ?? []),
  );
}

class TennisLogEntry {
  final String type; // 'penalty', 'medical', 'changeover', 'code_violation'
  final int? playerNum;
  final String? cardType; // 'warning', 'point', 'game', 'default'
  final String? reason;
  final int setNum;
  final int p1Games;
  final int p2Games;
  final String p1ScoreText;
  final String p2ScoreText;

  TennisLogEntry({
    required this.type,
    this.playerNum,
    this.cardType,
    this.reason,
    required this.setNum,
    required this.p1Games,
    required this.p2Games,
    required this.p1ScoreText,
    required this.p2ScoreText,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'playerNum': playerNum,
    'cardType': cardType,
    'reason': reason,
    'setNum': setNum,
    'p1Games': p1Games,
    'p2Games': p2Games,
    'p1ScoreText': p1ScoreText,
    'p2ScoreText': p2ScoreText,
  };

  factory TennisLogEntry.fromMap(Map<String, dynamic> map) => TennisLogEntry(
    type: map['type'] ?? 'log',
    playerNum: map['playerNum'],
    cardType: map['cardType'],
    reason: map['reason'],
    setNum: map['setNum'] ?? 1,
    p1Games: map['p1Games'] ?? 0,
    p2Games: map['p2Games'] ?? 0,
    p1ScoreText: map['p1ScoreText'] ?? '0',
    p2ScoreText: map['p2ScoreText'] ?? '0',
  );
}

class TennisMatchState {
  final String p1PointText;
  final String p2PointText;
  final int p1Games;
  final int p2Games;
  final int p1Sets;
  final int p2Sets;
  final bool isTiebreak;
  final int p1TiebreakPts;
  final int p2TiebreakPts;
  final List<TennisSetSummary> setSummaries;
  final int serverPlayerNum; // 1, 2, 3, 4
  final String servingCourt; // 'Deuce' or 'Ad'
  final bool p1OnLeft;
  final List<TennisLogEntry> logs;
  final int matchTimeSeconds;
  final int? timerEndTime;
  final String timerTitle;

  TennisMatchState({
    required this.p1PointText,
    required this.p2PointText,
    required this.p1Games,
    required this.p2Games,
    required this.p1Sets,
    required this.p2Sets,
    required this.isTiebreak,
    required this.p1TiebreakPts,
    required this.p2TiebreakPts,
    required this.setSummaries,
    required this.serverPlayerNum,
    required this.servingCourt,
    required this.p1OnLeft,
    required this.logs,
    required this.matchTimeSeconds,
    this.timerEndTime,
    this.timerTitle = '',
  });

  Map<String, dynamic> toMap() => {
    'p1PointText': p1PointText,
    'p2PointText': p2PointText,
    'p1Games': p1Games,
    'p2Games': p2Games,
    'p1Sets': p1Sets,
    'p2Sets': p2Sets,
    'isTiebreak': isTiebreak,
    'p1TiebreakPts': p1TiebreakPts,
    'p2TiebreakPts': p2TiebreakPts,
    'setSummaries': setSummaries.map((s) => s.toMap()).toList(),
    'serverPlayerNum': serverPlayerNum,
    'servingCourt': servingCourt,
    'p1OnLeft': p1OnLeft,
    'logs': logs.map((l) => l.toMap()).toList(),
    'matchTimeSeconds': matchTimeSeconds,
    'timerEndTime': timerEndTime,
    'timerTitle': timerTitle,
  };

  factory TennisMatchState.fromMap(Map<String, dynamic> map) => TennisMatchState(
    p1PointText: map['p1PointText'] ?? '0',
    p2PointText: map['p2PointText'] ?? '0',
    p1Games: map['p1Games'] ?? 0,
    p2Games: map['p2Games'] ?? 0,
    p1Sets: map['p1Sets'] ?? 0,
    p2Sets: map['p2Sets'] ?? 0,
    isTiebreak: map['isTiebreak'] ?? false,
    p1TiebreakPts: map['p1TiebreakPts'] ?? 0,
    p2TiebreakPts: map['p2TiebreakPts'] ?? 0,
    setSummaries: (map['setSummaries'] as List? ?? [])
        .map((s) => TennisSetSummary.fromMap(Map<String, dynamic>.from(s)))
        .toList(),
    serverPlayerNum: map['serverPlayerNum'] ?? 1,
    servingCourt: map['servingCourt'] ?? 'Deuce',
    p1OnLeft: map['p1OnLeft'] ?? true,
    logs: (map['logs'] as List? ?? [])
        .map((l) => TennisLogEntry.fromMap(Map<String, dynamic>.from(l)))
        .toList(),
    matchTimeSeconds: map['matchTimeSeconds'] ?? 0,
    timerEndTime: map['timerEndTime'],
    timerTitle: map['timerTitle'] ?? '',
  );
}
