class BadmintonGameSummary {
  final int p1Score;
  final int p2Score;
  final List<int> pointSequence;
  final int firstServer;

  BadmintonGameSummary({
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

  factory BadmintonGameSummary.fromMap(Map<String, dynamic> map) => BadmintonGameSummary(
    p1Score: map['p1Score'],
    p2Score: map['p2Score'],
    pointSequence: List<int>.from(map['pointSequence']),
    firstServer: map['firstServer'] ?? 1,
  );
}

class BadmintonLogEntry {
  final String type; // 'interval', 'game_end', 'penalty', 'side_switch'
  final int? playerNum;
  final String? cardType; // 'yellow', 'red', 'black'
  final String? detail;
  final int gameNum;
  final int p1Score;
  final int p2Score;

  BadmintonLogEntry({
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

  factory BadmintonLogEntry.fromMap(Map<String, dynamic> map) => BadmintonLogEntry(
    type: map['type'],
    playerNum: map['playerNum'],
    cardType: map['cardType'],
    detail: map['detail'],
    gameNum: map['gameNum'],
    p1Score: map['p1Score'],
    p2Score: map['p2Score'],
  );
}

class BadmintonMatchState {
  final int p1Score;
  final int p2Score;
  final int p1Games;
  final int p2Games;
  final bool isGameOver;
  final List<int> pointHistory;
  final List<BadmintonGameSummary> gameSummaries;
  final int firstServerOfMatch;
  final int firstServerOfGame;
  final bool p1OnLeft;
  final List<BadmintonLogEntry> logs;
  final int matchTimeSeconds;
  final int? timerEndTime;
  final String? timerTitle;

  BadmintonMatchState({
    required this.p1Score,
    required this.p2Score,
    required this.p1Games,
    required this.p2Games,
    required this.isGameOver,
    required this.pointHistory,
    required this.gameSummaries,
    required this.firstServerOfMatch,
    required this.firstServerOfGame,
    required this.p1OnLeft,
    required this.logs,
    required this.matchTimeSeconds,
    this.timerEndTime,
    this.timerTitle,
  });

  Map<String, dynamic> toMap() => {
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
    'logs': logs.map((l) => l.toMap()).toList(),
    'matchTimeSeconds': matchTimeSeconds,
    'timerEndTime': timerEndTime,
    'timerTitle': timerTitle,
  };

  factory BadmintonMatchState.fromMap(Map<String, dynamic> map) => BadmintonMatchState(
    p1Score: map['p1Score'] ?? 0,
    p2Score: map['p2Score'] ?? 0,
    p1Games: map['p1Games'] ?? 0,
    p2Games: map['p2Games'] ?? 0,
    isGameOver: map['isGameOver'] ?? false,
    pointHistory: List<int>.from(map['pointHistory'] ?? []),
    gameSummaries: (map['gameSummaries'] as List? ?? [])
        .map((s) => BadmintonGameSummary.fromMap(s))
        .toList(),
    firstServerOfMatch: map['firstServerOfMatch'] ?? 0,
    firstServerOfGame: map['firstServerOfGame'] ?? 0,
    p1OnLeft: map['p1OnLeft'] ?? true,
    logs: (map['logs'] as List? ?? [])
        .map((l) => BadmintonLogEntry.fromMap(l))
        .toList(),
    matchTimeSeconds: map['matchTimeSeconds'] ?? 0,
    timerEndTime: map['timerEndTime'],
    timerTitle: map['timerTitle'],
  );
}

class BadmintonServerResults {
  final int server;
  final int receiver;
  final String serverCourt; // 'RIGHT' or 'LEFT'
  final List<int> positions; // [T1 Right, T1 Left, T2 Right, T2 Left]
  BadmintonServerResults(this.server, this.receiver, this.serverCourt, this.positions);
}

class BadmintonRotationLogic {
  static BadmintonServerResults getRotationAtPoint({
    required int firstServer,
    required bool isDoubles,
    required bool isDecider,
    required List<int> pointSequence,
  }) {
    if (firstServer == 0) return BadmintonServerResults(0, 0, 'RIGHT', [1, 2, 3, 4]);

    // Team 1: Players 1 & 2, Team 2: Players 3 & 4
    // In Singles, we use Player 1 for Team 1 and Player 3 for Team 2.
    List<int> positions = isDoubles ? [1, 2, 3, 4] : [1, 1, 3, 3];
    int currentServer = firstServer;
    int p1Score = 0;
    int p2Score = 0;

    for (int winner in pointSequence) {
      if (winner == 1) {
        if (currentServer <= 2) {
          // Team 1 was serving and won the point.
          if (isDoubles) {
            int tmp = positions[0];
            positions[0] = positions[1];
            positions[1] = tmp;
          }
        } else {
          // Change of service to Team 1.
          currentServer = (p1Score + 1) % 2 == 0 ? positions[0] : positions[1];
        }
        p1Score++;
      } else {
        // Team 2 wins the rally.
        if (currentServer >= 3) {
          // Team 2 was serving and won.
          if (isDoubles) {
            int tmp = positions[2];
            positions[2] = positions[3];
            positions[3] = tmp;
          }
        } else {
          // Change of service to Team 2.
          currentServer = (p2Score + 1) % 2 == 0 ? positions[2] : positions[3];
        }
        p2Score++;
      }
    }

    int totalForTeam = (currentServer <= 2) ? p1Score : p2Score;
    String court = (totalForTeam % 2 == 0) ? 'RIGHT' : 'LEFT';

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

    return BadmintonServerResults(currentServer, receiver, court, positions);
  }
}
