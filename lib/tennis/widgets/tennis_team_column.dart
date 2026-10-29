import 'package:flutter/material.dart';
import 'package:aurum/language_service.dart';

class TennisTeamColumn extends StatelessWidget {
  final int teamNum;
  final String pointText; // '0', '15', '30', '40', 'AD'
  final int games;
  final int sets;
  final String name;
  final bool isServing;
  final String servingCourt; // 'Deuce' or 'Ad'
  final String side; // 'HOME' or 'AWAY'
  final bool isHost;
  final bool isFinished;
  final bool isTimerRunning;
  final VoidCallback onPointAdd;
  final VoidCallback onCodeViolation;

  const TennisTeamColumn({
    super.key,
    required this.teamNum,
    required this.pointText,
    required this.games,
    required this.sets,
    required this.name,
    required this.isServing,
    required this.servingCourt,
    required this.side,
    required this.isHost,
    required this.isFinished,
    required this.isTimerRunning,
    required this.onPointAdd,
    required this.onCodeViolation,
  });

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double columnWidth = (screenWidth - 40) / 2.1;
    if (columnWidth > 200) columnWidth = 200;

    return SizedBox(
      width: columnWidth,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name + (isServing ? ' (S)' : ''),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isServing ? FontWeight.bold : FontWeight.normal,
                    color: isServing ? Colors.green : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isServing) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(8)),
                  child: Text(servingCourt.tr, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                ),
                child: Text('${'Sets'.tr}: $sets', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                ),
                child: Text('${'Games'.tr}: $games', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isHost && !isFinished)
            SizedBox(
              width: columnWidth * 0.7,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: onCodeViolation,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning, size: 12, color: Colors.orange),
                      const SizedBox(width: 2),
                      Text('Code Violation'.tr, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: (isHost && !isFinished && !isTimerRunning) ? onPointAdd : null,
            child: Container(
              width: columnWidth * 0.8,
              height: columnWidth * 0.8,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isServing ? Colors.white : Colors.blue.withValues(alpha: 0.5),
                  width: 3,
                ),
                boxShadow: [
                  if (isServing && !isFinished && !isTimerRunning)
                    BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 3),
                ],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      pointText,
                      style: TextStyle(
                        fontSize: columnWidth * 0.32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('POINTS'.tr, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('${'SIDE'.tr}: ${side.tr}', style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
