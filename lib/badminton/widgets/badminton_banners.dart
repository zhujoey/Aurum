import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import '../badminton_models.dart';

class BadmintonSuspensionBanner extends StatelessWidget {
  final List<BadmintonLogEntry> logs;
  final bool isDoubles;
  final String p1Name, p3Name;

  const BadmintonSuspensionBanner({
    super.key,
    required this.logs,
    required this.isDoubles,
    required this.p1Name,
    required this.p3Name,
  });

  @override
  Widget build(BuildContext context) {
    bool p1Disqualified = logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && l.playerNum! <= 2);
    bool p2Disqualified = logs.any((l) => l.type == 'penalty' && l.cardType == 'black' && l.playerNum! >= 3);

    if (!p1Disqualified && !p2Disqualified) return const SizedBox.shrink();

    String teamName = p1Disqualified 
        ? (isDoubles ? 'TEAM 1' : p1Name) 
        : (isDoubles ? 'TEAM 2' : p3Name);

    return Container(
      width: double.infinity,
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, color: Colors.red),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'DISQUALIFIED: $teamName',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('REFEREE HAS ENDED THE MATCH',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class BadmintonTimerBanner extends StatelessWidget {
  final String title;
  final int endTime;
  final bool isHost;
  final VoidCallback onSkip;

  const BadmintonTimerBanner({
    super.key,
    required this.title,
    required this.endTime,
    required this.isHost,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        int now = DateTime.now().millisecondsSinceEpoch;
        int remaining = ((endTime - now) / 1000).round();
        if (remaining < 0) remaining = 0;

        return Container(
          width: double.infinity,
          color: Colors.blue.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: Row(children: [
            const Icon(Icons.timer, color: Colors.blue),
            const SizedBox(width: 12),
            Text(
              '$title: ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const Spacer(),
            if (isHost)
              TextButton(onPressed: onSkip, child: const Text('Skip')),
          ]),
        );
      }
    );
  }
}
