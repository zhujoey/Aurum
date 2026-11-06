import 'package:flutter/material.dart';
import 'package:aurum/language_service.dart';
import '../pickleball_models.dart';

class PickleballSuspensionBanner extends StatelessWidget {
  final List<PickleballLogEntry> logs;
  final bool isDoubles;
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;

  const PickleballSuspensionBanner({
    super.key,
    required this.logs,
    required this.isDoubles,
    required this.p1Name,
    required this.p2Name,
    required this.p3Name,
    required this.p4Name,
  });

  @override
  Widget build(BuildContext context) {
    final penalties = logs.where((l) => l.type == 'penalty').toList();
    if (penalties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.red.withValues(alpha: 0.1),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match Penalties / Warnings'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ...penalties.map((p) {
            String playerName = '';
            if (p.playerNum == 1) {
              playerName = p1Name;
            } else if (p.playerNum == 2) {
              playerName = isDoubles ? p2Name : p1Name;
            } else if (p.playerNum == 3) {
              playerName = p3Name;
            } else if (p.playerNum == 4) {
              playerName = p4Name;
            }

            return Text('• ${p.cardType?.toUpperCase() ?? 'CARD'} card given to $playerName: ${p.detail ?? ''}');
          }),
        ],
      ),
    );
  }
}

class PickleballTimerBanner extends StatelessWidget {
  final String title;
  final int endTime;
  final bool isHost;
  final VoidCallback onCancel;

  const PickleballTimerBanner({
    super.key,
    required this.title,
    required this.endTime,
    required this.isHost,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber.withValues(alpha: 0.2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.orange),
              const SizedBox(width: 8),
              Text('$title (Active)'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          if (isHost)
            TextButton(
              onPressed: onCancel,
              child: Text('End Timer'.tr, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }
}
