import 'package:flutter/material.dart';
import 'package:aurum/language_service.dart';
import '../tennis_models.dart';

class TennisMatchHistoryBottomSheet extends StatelessWidget {
  final List<TennisSetSummary> allSets;
  final List<TennisLogEntry> logs;
  final String p1Name;
  final String p2Name;

  const TennisMatchHistoryBottomSheet({
    super.key,
    required this.allSets,
    required this.logs,
    required this.p1Name,
    required this.p2Name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text('Tennis Match History'.tr, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: allSets.length,
              itemBuilder: (context, setIdx) {
                final set = allSets[setIdx];
                final setLogs = logs.where((l) => l.setNum == setIdx + 1).toList();

                return ExpansionTile(
                  initiallyExpanded: setIdx == allSets.length - 1,
                  title: Text('${'Set'.tr} ${setIdx + 1}: ${set.p1Games} - ${set.p2Games}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: set.tiebreakP1Pts != null
                      ? Text('${'Tiebreak'.tr}: ${set.tiebreakP1Pts}-${set.tiebreakP2Pts}')
                      : null,
                  children: [
                    if (setLogs.isNotEmpty)
                      ...setLogs.map((entry) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning, color: Colors.orange),
                          title: Text('${entry.playerNum == 1 ? p1Name : p2Name}: ${entry.reason?.tr ?? "Code Violation".tr}'),
                          subtitle: Text('${'Games'.tr}: ${entry.p1Games}-${entry.p2Games} (${entry.p1ScoreText}-${entry.p2ScoreText})'),
                        );
                      }),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text(p1Name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${set.p1Games} ${'Games'.tr}', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                            ],
                          ),
                          Text('VS'.tr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Column(
                            children: [
                              Text(p2Name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${set.p2Games} ${'Games'.tr}', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
