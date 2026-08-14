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
  final int firstServerOfMatch;
  final int firstServerOfSet;
  final int firstReceiverOfSet;
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
    required this.firstServerOfMatch,
    required this.firstServerOfSet,
    required this.firstReceiverOfSet,
    required this.p1OnLeft,
    required this.logs,
    required this.expediteActive,
    required this.gameTimeSeconds,
    this.activeTimerSeconds = 0,
    this.activeTimerTitle = '',
  });
}

class TTServerResults {
  final int server;
  final int receiver;
  TTServerResults(this.server, this.receiver);
}

class TTRotationLogic {
  static List<int> getNormalRotation(int fs, int fr, bool isDoubles) {
    if (fs == 0) return isDoubles ? [0, 0, 0, 0] : [0, 0];
    if (!isDoubles) return [fs, 3 - fs];
    
    int p1 = fs; 
    int p2 = fr; 
    int p3 = (fs == 1 ? 2 : (fs == 2 ? 1 : (fs == 3 ? 4 : 3))); 
    int p4 = (fr == 1 ? 2 : (fr == 2 ? 1 : (fr == 3 ? 4 : 3))); 
    
    return [p1, p2, p3, p4];
  }

  static List<int> getSwitchedRotation(int fs, int fr) {
    if (fs == 0) return [0, 0, 0, 0];
    
    int p1 = fs;
    int p2 = fr;
    int p3 = (fs == 1 ? 2 : (fs == 2 ? 1 : (fs == 3 ? 4 : 3)));
    int p4 = (fr == 1 ? 2 : (fr == 2 ? 1 : (fr == 3 ? 4 : 3)));
    
    return [p1, p4, p3, p2];
  }

  static TTServerResults getRotationAtPoint({
    required int fs,
    required int fr,
    required bool isDoubles,
    required bool isDecider,
    required List<int> pointSequence,
    bool expediteActive = false,
  }) {
    if (fs == 0) return TTServerResults(0, 0);
    
    int p1Points = 0;
    int p2Points = 0;
    int currentRotationIdx = 0;
    int pointsInCurrentStint = 0;
    bool hasSwitched = false;

    for (int i = 0; i < pointSequence.length; i++) {
      int stintSize = (expediteActive || (p1Points >= 10 && p2Points >= 10)) ? 1 : 2;
      
      if (isDecider && !hasSwitched && (p1Points >= 5 || p2Points >= 5)) {
        hasSwitched = true;
        if (isDoubles && (currentRotationIdx == 1 || currentRotationIdx == 3)) {
           currentRotationIdx = (currentRotationIdx + 2) % 4;
        }
      }

      int winner = pointSequence[i];
      if (winner == 1) {
        p1Points++;
      } else {
        p2Points++;
      }

      pointsInCurrentStint++;
      if (pointsInCurrentStint >= stintSize) {
        pointsInCurrentStint = 0;
        currentRotationIdx = (currentRotationIdx + 1) % (isDoubles ? 4 : 2);
      }
    }

    if (isDecider && !hasSwitched && (p1Points >= 5 || p2Points >= 5)) {
      hasSwitched = true;
      if (isDoubles && (currentRotationIdx == 1 || currentRotationIdx == 3)) {
         currentRotationIdx = (currentRotationIdx + 2) % 4;
      }
    }

    List<int> rotation = (isDoubles && hasSwitched) 
        ? getSwitchedRotation(fs, fr) 
        : getNormalRotation(fs, fr, isDoubles);

    int server = rotation[currentRotationIdx];
    int receiver = isDoubles ? rotation[(currentRotationIdx + 1) % 4] : 0;
    
    return TTServerResults(server, receiver);
  }

  static List<int> calculateRotation(
      int fs, int fr, bool isDoubles, bool isDecider, int p1Score, int p2Score) {
    if (fs == 0) return isDoubles ? [0, 0, 0, 0] : [0, 0];
    if (!isDoubles) return [fs, 3 - fs];
    if (isDecider && (p1Score >= 5 || p2Score >= 5)) {
      return getSwitchedRotation(fs, fr);
    }
    return getNormalRotation(fs, fr, isDoubles);
  }
}
