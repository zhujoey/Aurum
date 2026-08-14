import 'package:flutter/material.dart';
import '../badminton_models.dart';

class BadmintonTeamColumn extends StatelessWidget {
  final int team;
  final int score;
  final int games;
  final List<String> names;
  final bool isDoubles;
  final bool isServing;
  final int serverNum;
  final int receiverNum;
  final String side;
  final bool isHost;
  final bool isTimerRunning;
  final VoidCallback onScore;
  final VoidCallback onYellow;
  final VoidCallback onRed;
  final VoidCallback onBlack;
  final bool hasYellow;
  final bool hasRed;
  final bool isBlacked;
  final List<int> pointHistory;
  final int firstServer;

  const BadmintonTeamColumn({
    super.key,
    required this.team,
    required this.score,
    required this.games,
    required this.names,
    required this.isDoubles,
    required this.isServing,
    required this.serverNum,
    required this.receiverNum,
    required this.side,
    required this.isHost,
    required this.isTimerRunning,
    required this.onScore,
    required this.onYellow,
    required this.onRed,
    required this.onBlack,
    required this.hasYellow,
    required this.hasRed,
    required this.isBlacked,
    required this.pointHistory,
    required this.firstServer,
  });

  @override
  Widget build(BuildContext context) {
    double columnWidth = (MediaQuery.of(context).size.width - 60) / 2;
    if (columnWidth > 200) columnWidth = 200;

    bool interactionsEnabled = isHost && !isBlacked && !isTimerRunning;

    return Container(
      width: columnWidth,
      child: Column(children: [
        Column(children: [
          _playerName(names[0], team == 1 ? 1 : 3),
          if (isDoubles) ...[
            const Text('&', style: TextStyle(fontSize: 10, color: Colors.grey)),
            _playerName(names[1], team == 1 ? 2 : 4),
          ],
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: (interactionsEnabled && !hasYellow) ? onYellow : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 16, 
              height: 24, 
              decoration: BoxDecoration(
                color: hasYellow ? Colors.yellow : Colors.yellow.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: hasYellow ? Colors.yellow.shade700 : Colors.yellow.withValues(alpha: 0.2), 
                  width: hasYellow ? 1.5 : 1,
                ),
                boxShadow: hasYellow ? [
                  BoxShadow(color: Colors.yellow.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)
                ] : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: interactionsEnabled ? onRed : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 16, 
              height: 24, 
              decoration: BoxDecoration(
                color: hasRed ? Colors.red : Colors.red.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: hasRed ? Colors.red.shade900 : Colors.red.withValues(alpha: 0.2), 
                  width: hasRed ? 1.5 : 1,
                ),
                boxShadow: hasRed ? [
                  BoxShadow(color: Colors.red.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1)
                ] : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: interactionsEnabled ? onBlack : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 16, 
              height: 24, 
              decoration: BoxDecoration(
                color: isBlacked ? Colors.black : Colors.black.withValues(alpha: 0.1), 
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                  color: isBlacked ? Colors.redAccent : Colors.grey.withValues(alpha: 0.2), 
                  width: isBlacked ? 1.5 : 1,
                ),
                boxShadow: isBlacked ? [
                  const BoxShadow(color: Colors.redAccent, blurRadius: 8, spreadRadius: 1)
                ] : null,
              ),
              child: isBlacked ? const Icon(Icons.close, size: 12, color: Colors.red) : null,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('Games: $games', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: interactionsEnabled ? onScore : null,
          child: Container(
            width: columnWidth * 0.8,
            height: columnWidth * 0.8,
            decoration: BoxDecoration(
              color: isServing ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isServing ? Colors.white : (interactionsEnabled ? Colors.blue.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
                width: 3,
              ),
              boxShadow: [
                if (isServing) BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
              ],
            ),
            child: Center(
              child: Text(
                '$score',
                style: TextStyle(
                  fontSize: columnWidth * 0.35,
                  fontWeight: FontWeight.bold,
                  color: (interactionsEnabled || isServing) ? null : Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            side, 
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ),
      ]),
    );
  }

  Widget _playerName(String name, int playerNum) {
    bool isS = serverNum == playerNum;
    bool isR = receiverNum == playerNum;
    bool interactionsEnabled = isHost && !isBlacked && !isTimerRunning;

    final currentRes = BadmintonRotationLogic.getRotationAtPoint(
      firstServer: firstServer,
      isDoubles: isDoubles,
      isDecider: false,
      pointSequence: pointHistory,
    );
    
    String courtPos = "";
    if (isDoubles) {
      if (playerNum <= 2) {
        courtPos = (currentRes.positions[0] == playerNum) ? " (R)" : " (L)";
      } else {
        courtPos = (currentRes.positions[2] == playerNum) ? " (R)" : " (L)";
      }
    } else {
      if (isS) {
        courtPos = (currentRes.serverCourt == 'RIGHT') ? " (R)" : " (L)";
      } else if (isR) {
        courtPos = (currentRes.serverCourt == 'RIGHT') ? " (L)" : " (R)";
      }
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isS) const Icon(Icons.keyboard_double_arrow_up, size: 14, color: Colors.white),
        if (isR) const Icon(Icons.keyboard_double_arrow_down, size: 14, color: Colors.blueAccent),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            name + courtPos,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isS || isR ? FontWeight.bold : FontWeight.normal,
              color: isS ? Colors.white : (isR ? Colors.blueAccent : (interactionsEnabled ? null : Colors.grey)),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
