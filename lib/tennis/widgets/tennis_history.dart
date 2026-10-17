import 'package:flutter/material.dart';
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
          const Text('Tennis Match History', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: allSets.length,
              itemBuilder: (context, setIdx) {
                final set = allSets[setIdx];
                final setLogs = logs.where((l) => l.setNum == setIdx + 1).toList();

                return ExpansionTile(
                  initiallyExpanded: setIdx == allSets.length - 1,
                  title: Text('Set ${setIdx + 1}: ${set.p1Games} - ${set.p2Games}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: set.tiebreakP1Pts != null
                      ? Text('Tiebreak: ${set.tiebreakP1Pts}-${set.tiebreakP2Pts}')
                      : null,
                  children: [
                    if (setLogs.isNotEmpty)
                      ...setLogs.map((entry) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.warning, color: Colors.orange),
                          title: Text('${entry.playerNum == 1 ? p1Name : p2Name}: ${entry.reason ?? "Code Violation"}'),
                          subtitle: Text('Games: ${entry.p1Games}-${entry.p2Games} (${entry.p1ScoreText}-${entry.p2ScoreText})'),
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
                              Text('${set.p1Games} Games', style: const TextStyle(fontSize: 18, color: Colors.blue)),
                            ],
                          ),
                          const Text('VS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          Column(
                            children: [
                              Text(p2Name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('${set.p2Games} Games', style: const TextStyle(fontSize: 18, color: Colors.blue)),
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
