import 'package:flutter/material.dart';

class TeamColumn extends StatelessWidget {
  final int teamNum;
  final int score;
  final int sets;
  final String name1;
  final String name2;
  final bool isDoubles;
  final bool hasWon;
  final bool timeoutUsed;
  final bool isTimerRunning;
  final bool isFinished;
  final bool isAnySuspended;
  final bool teamServing;
  final String playerSide;
  final bool hasYellow;
  final bool hasRed;
  final bool isSuspended;
  final VoidCallback onScoreTap;
  final VoidCallback onTimeoutTap;
  final VoidCallback onYellowTap;
  final VoidCallback onRedTap;
  final Widget Function(String, int, bool) playerNameBuilder;

  const TeamColumn({
    super.key,
    required this.teamNum,
    required this.score,
    required this.sets,
    required this.name1,
    required this.name2,
    required this.isDoubles,
    required this.hasWon,
    required this.timeoutUsed,
    required this.isTimerRunning,
    required this.isFinished,
    required this.isAnySuspended,
    required this.teamServing,
    required this.playerSide,
    required this.hasYellow,
    required this.hasRed,
    required this.isSuspended,
    required this.onScoreTap,
    required this.onTimeoutTap,
    required this.onYellowTap,
    required this.onRedTap,
    required this.playerNameBuilder,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double columnWidth = (screenWidth - 40) / 2.1;
    if (columnWidth > 200) columnWidth = 200;

    int p1Num = teamNum == 1 ? 1 : (isDoubles ? 3 : 2);
    int p2Num = teamNum == 1 ? 2 : 4;

    return Container(
      width: columnWidth,
      child: Column(children: [
        Column(children: [
          if (isDoubles) ...[
            playerNameBuilder(name1, p1Num, hasWon),
            const Text('&', style: TextStyle(fontSize: 10, color: Colors.grey)),
            playerNameBuilder(name2, p2Num, hasWon)
          ] else ...[
            playerNameBuilder(name1, p1Num, hasWon)
          ],
        ]),
        const SizedBox(height: 10),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: hasWon
                    ? Colors.amber.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: hasWon ? Border.all(color: Colors.amber, width: 1) : null),
            child: Text('Sets: $sets',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasWon ? Colors.amber : Colors.blue))),
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          ElevatedButton(
              onPressed: (timeoutUsed ||
                      isTimerRunning ||
                      isFinished ||
                      isAnySuspended)
                  ? null
                  : onTimeoutTap,
              style: ElevatedButton.styleFrom(
                  backgroundColor: timeoutUsed ? Colors.grey : Colors.blueGrey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  minimumSize: const Size(40, 25)),
              child: const Text('T/O', style: TextStyle(fontSize: 9))),
          const SizedBox(width: 8),
          GestureDetector(
              onTap: (isTimerRunning || isFinished || hasYellow || isAnySuspended)
                  ? null
                  : onYellowTap,
              child: Container(
                  width: 18,
                  height: 28,
                  decoration: BoxDecoration(
                      color: hasYellow
                          ? Colors.yellow
                          : Colors.yellow.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: hasYellow ? Colors.yellow.shade700 : Colors.yellow,
                          width: 1.5),
                      boxShadow: hasYellow
                          ? [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ]
                          : null))),
          const SizedBox(width: 6),
          GestureDetector(
              onTap: (isTimerRunning ||
                      isFinished ||
                      isSuspended ||
                      isAnySuspended)
                  ? null
                  : onRedTap,
              child: Container(
                  width: 18,
                  height: 28,
                  decoration: BoxDecoration(
                      color: hasRed ? Colors.red : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                          color: hasRed ? Colors.red.shade900 : Colors.red,
                          width: 1.5),
                      boxShadow: hasRed
                          ? [
                              BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 2,
                                  offset: Offset(1, 1))
                            ]
                          : null),
                  child: isSuspended
                      ? const Center(child: Icon(Icons.close, size: 14, color: Colors.white))
                      : null)),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
            onTap: (isTimerRunning || isFinished || isAnySuspended)
                ? null
                : onScoreTap,
            child: Container(
                width: columnWidth * 0.8,
                height: columnWidth * 0.8,
                decoration: BoxDecoration(
                    color: hasWon
                        ? Colors.amber.withValues(alpha: 0.05)
                        : Colors.blue.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: teamServing
                            ? Colors.white
                            : (hasWon
                                ? Colors.amber
                                : (isFinished || isTimerRunning || isAnySuspended
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.blue.withValues(alpha: 0.5))),
                        width: 3),
                    boxShadow: [
                      if (hasWon)
                        BoxShadow(
                            color: Colors.amber.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 3),
                      if (teamServing &&
                          !isFinished &&
                          !isTimerRunning &&
                          !isAnySuspended)
                        BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 3)
                    ]),
                child: Center(
                    child: Text('$score',
                        style: TextStyle(
                            fontSize: columnWidth * 0.35,
                            fontWeight: FontWeight.bold,
                            color: hasWon
                                ? Colors.amber
                                : (isFinished || isTimerRunning || isAnySuspended
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : null)))))),
        const SizedBox(height: 8),
        Text('SIDE: $playerSide',
            style: const TextStyle(
                color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
