class SetSummary {
  final int p1Score;
  final int p2Score;
  final List<int> pointSequence;
  final bool isExpediteSet;
  final int firstServer;
  final int firstReceiver;

  SetSummary({
    required this.p1Score, 
    required this.p2Score, 
    required this.pointSequence, 
    this.isExpediteSet = false,
    required this.firstServer,
    required this.firstReceiver,
  });

  Map<String, dynamic> toMap() => {
    'p1Score': p1Score,
    'p2Score': p2Score,
    'pointSequence': pointSequence,
    'isExpediteSet': isExpediteSet,
    'firstServer': firstServer,
    'firstReceiver': firstReceiver,
  };

  factory SetSummary.fromMap(Map<String, dynamic> map) => SetSummary(
    p1Score: map['p1Score'],
    p2Score: map['p2Score'],
    pointSequence: List<int>.from(map['pointSequence']),
    isExpediteSet: map['isExpediteSet'] ?? false,
    firstServer: map['firstServer'] ?? 1,
    firstReceiver: map['firstReceiver'] ?? 0,
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
  final int firstReceiver;
  final bool p1OnLeft;
  final List<MatchLogEntry> logs;
  final bool expediteActive;
  final int gameTimeSeconds;
  final int activeTimerSeconds;
  final String activeTimerTitle;

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
    required this.firstReceiver,
    required this.p1OnLeft,
    required this.logs,
    required this.expediteActive,
    required this.gameTimeSeconds,
    this.activeTimerSeconds = 0,
    this.activeTimerTitle = '',
  });
}
