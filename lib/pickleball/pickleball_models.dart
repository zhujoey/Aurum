class PickleballGameSummary {
  final int p1Score;
  final int p2Score;
  final List<int> pointSequence;
  final int firstServer;

  PickleballGameSummary({
    required this.p1Score,
    required this.p2Score,
    required this.pointSequence,
    required this.firstServer,
  });

  Map<String, dynamic> toMap() => {
    'p1Score': p1Score,
    'p2Score': p2Score,
    'pointSequence': pointSequence,
    'firstServer': firstServer,
  };

  factory PickleballGameSummary.fromMap(Map<String, dynamic> map) => PickleballGameSummary(
    p1Score: map['p1Score'] ?? 0,
    p2Score: map['p2Score'] ?? 0,
    pointSequence: List<int>.from(map['pointSequence'] ?? []),
    firstServer: map['firstServer'] ?? 1,
  );
}

class PickleballLogEntry {
  final String type; // 'timeout', 'game_end', 'penalty', 'side_switch'
  final int? playerNum;
  final String? cardType; // 'yellow', 'red', 'black'
  final String? detail;
  final int gameNum;
  final int p1Score;
  final int p2Score;

  PickleballLogEntry({
    required this.type,
    this.playerNum,
    this.cardType,
    this.detail,
    required this.gameNum,
    required this.p1Score,
    required this.p2Score,
  });

  Map<String, dynamic> toMap() => {
    'type': type,
    'playerNum': playerNum,
    'cardType': cardType,
    'detail': detail,
    'gameNum': gameNum,
    'p1Score': p1Score,
    'p2Score': p2Score,
  };

  factory PickleballLogEntry.fromMap(Map<String, dynamic> map) => PickleballLogEntry(
    type: map['type'] ?? 'log',
    playerNum: map['playerNum'],
    cardType: map['cardType'],
    detail: map['detail'],
    gameNum: map['gameNum'] ?? 1,
    p1Score: map['p1Score'] ?? 0,
    p2Score: map['p2Score'] ?? 0,
  );
}

class PickleballMatchState {
  final int p1Score;
  final int p2Score;
  final int p1Games;
  final int p2Games;
  final bool isGameOver;
  final List<int> pointHistory;
  final List<PickleballGameSummary> gameSummaries;
  final int currentServer; // 1, 2, 3, 4
  final int serverNum; // 1 or 2 (in doubles)
  final bool p1OnLeft;
  final List<PickleballLogEntry> logs;
  final int matchTimeSeconds;
  final int? timerEndTime;
  final String timerTitle;
  final bool p1TimeoutUsed;
  final bool p2TimeoutUsed;

  PickleballMatchState({
    required this.p1Score,
    required this.p2Score,
    required this.p1Games,
    required this.p2Games,
    required this.isGameOver,
    required this.pointHistory,
    required this.gameSummaries,
    required this.currentServer,
    required this.serverNum,
    required this.p1OnLeft,
    required this.logs,
    required this.matchTimeSeconds,
    this.timerEndTime,
    this.timerTitle = '',
    required this.p1TimeoutUsed,
    required this.p2TimeoutUsed,
  });

  Map<String, dynamic> toMap() => {
    'p1Score': p1Score,
    'p2Score': p2Score,
    'p1Games': p1Games,
    'p2Games': p2Games,
    'isGameOver': isGameOver,
    'pointHistory': pointHistory,
    'gameSummaries': gameSummaries.map((s) => s.toMap()).toList(),
    'currentServer': currentServer,
    'serverNum': serverNum,
    'p1OnLeft': p1OnLeft,
    'logs': logs.map((l) => l.toMap()).toList(),
    'matchTimeSeconds': matchTimeSeconds,
    'timerEndTime': timerEndTime,
    'timerTitle': timerTitle,
    'p1TimeoutUsed': p1TimeoutUsed,
    'p2TimeoutUsed': p2TimeoutUsed,
  };

  factory PickleballMatchState.fromMap(Map<String, dynamic> map) => PickleballMatchState(
    p1Score: map['p1Score'] ?? 0,
    p2Score: map['p2Score'] ?? 0,
    p1Games: map['p1Games'] ?? 0,
    p2Games: map['p2Games'] ?? 0,
    isGameOver: map['isGameOver'] ?? false,
    pointHistory: List<int>.from(map['pointHistory'] ?? []),
    gameSummaries: (map['gameSummaries'] as List? ?? [])
        .map((s) => PickleballGameSummary.fromMap(s))
        .toList(),
    currentServer: map['currentServer'] ?? 1,
    serverNum: map['serverNum'] ?? 2,
    p1OnLeft: map['p1OnLeft'] ?? true,
    logs: (map['logs'] as List? ?? [])
        .map((l) => PickleballLogEntry.fromMap(l))
        .toList(),
    matchTimeSeconds: map['matchTimeSeconds'] ?? 0,
    timerEndTime: map['timerEndTime'],
    timerTitle: map['timerTitle'] ?? '',
    p1TimeoutUsed: map['p1TimeoutUsed'] ?? false,
    p2TimeoutUsed: map['p2TimeoutUsed'] ?? false,
  );
}

class PickleballServerResults {
  final int server; // 1, 2, 3, 4
  final int receiver; // 1, 2, 3, 4
  final String serverCourt; // 'RIGHT' or 'LEFT'
  final int serverNum; // 1 or 2
  final List<int> positions; // [T1 Right, T1 Left, T2 Right, T2 Left]
  PickleballServerResults(this.server, this.receiver, this.serverCourt, this.serverNum, this.positions);
}

class PickleballRotationLogic {
  static PickleballServerResults getRotationAtPoint({
    required int firstServer,
    required bool isDoubles,
    required List<int> pointSequence,
  }) {
    if (firstServer == 0) return PickleballServerResults(1, 3, 'RIGHT', 2, [1, 2, 3, 4]);

    List<int> positions = isDoubles ? [1, 2, 3, 4] : [1, 1, 3, 3];
    int currentServer = firstServer;
    int serverNum = (firstServer == 1 || firstServer == 3) ? 2 : 1;
    int p1Score = 0;
    int p2Score = 0;

    for (int winner in pointSequence) {
      if (winner == 1) {
        p1Score++;
        if (currentServer <= 2) {
          if (isDoubles) {
            int tmp = positions[0];
            positions[0] = positions[1];
            positions[1] = tmp;
          }
        } else {
          currentServer = (p1Score % 2 == 0) ? positions[0] : positions[1];
          serverNum = 1;
        }
      } else {
        p2Score++;
        if (currentServer >= 3) {
          if (isDoubles) {
            int tmp = positions[2];
            positions[2] = positions[3];
            positions[3] = tmp;
          }
        } else {
          currentServer = (p2Score % 2 == 0) ? positions[2] : positions[3];
          serverNum = 1;
        }
      }
    }

    int servingTeamScore = (currentServer <= 2) ? p1Score : p2Score;
    String court = (servingTeamScore % 2 == 0) ? 'RIGHT' : 'LEFT';

    int receiver = 0;
    if (isDoubles) {
      if (currentServer <= 2) {
        receiver = (court == 'RIGHT') ? positions[2] : positions[3];
      } else {
        receiver = (court == 'RIGHT') ? positions[0] : positions[1];
      }
    } else {
      receiver = (currentServer == 1) ? 3 : 1;
    }

    return PickleballServerResults(currentServer, receiver, court, serverNum, positions);
  }
}
