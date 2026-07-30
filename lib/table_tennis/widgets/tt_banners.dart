import 'package:flutter/material.dart';
import '../tt_models.dart';

class SuspensionBanner extends StatelessWidget {
  final List<MatchLogEntry> logs;
  final bool isDoubles;
  final String p1Name;
  final String p3Name;

  const SuspensionBanner({
    super.key,
    required this.logs,
    required this.isDoubles,
    required this.p1Name,
    required this.p3Name,
  });

  @override
  Widget build(BuildContext context) {
    bool p1Suspended = logs.any((p) =>
        p.type == 'penalty' &&
        (p.playerNum == 1 || (isDoubles && p.playerNum == 2)) &&
        p.cardType == 'red-suspension');
    bool p2Suspended = logs.any((p) =>
        p.type == 'penalty' &&
        ((isDoubles && (p.playerNum == 3 || p.playerNum == 4)) ||
            (!isDoubles && p.playerNum == 2)) &&
        p.cardType == 'red-suspension');

    if (!p1Suspended && !p2Suspended) return const SizedBox.shrink();

    String teamName = p1Suspended
        ? (isDoubles ? 'TEAM 1' : p1Name)
        : (isDoubles ? 'TEAM 2' : p3Name);

    return Container(
      width: double.infinity,
      color: Colors.red,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.report_problem, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'SUSPEND PLAY: $teamName REACHED LIMIT',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('REPORT TO REFEREE IMMEDIATELY',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class TimerBanner extends StatelessWidget {
  final String title;
  final int seconds;
  final VoidCallback? onSkip;

  const TimerBanner({
    super.key,
    required this.title,
    required this.seconds,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.blue.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Row(children: [
          const Icon(Icons.timer, color: Colors.blue),
          const SizedBox(width: 12),
          Text(
              '$title: ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.blue)),
          const Spacer(),
          if (onSkip != null)
            TextButton(onPressed: onSkip, child: const Text('Skip')),
        ]));
  }
}

class ExpediteBanner extends StatelessWidget {
  const ExpediteBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        color: Colors.red,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: const Text('!!! EXPEDITE SYSTEM ACTIVE: SERVE EVERY POINT !!!',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1)));
  }
}
