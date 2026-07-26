import 'package:flutter/material.dart';
import '../tt_models.dart';

class MatchHistoryBottomSheet extends StatelessWidget {
  final List<SetSummary> allSets;
  final List<MatchLogEntry> logs;
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;

  const MatchHistoryBottomSheet({
    super.key,
    required this.allSets,
    required this.logs,
    required this.p1Name,
    required this.p2Name,
    required this.p3Name,
    required this.p4Name,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Text('Match History',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Expanded(
            child: ListView.builder(
                itemCount: allSets.length,
                itemBuilder: (context, setIndex) {
                  final set = allSets[setIndex];
                  List<int> p1Progress = [], p2Progress = [];
                  int curP1 = 0, curP2 = 0;
                  for (int p in set.pointSequence) {
                    if (p == 1)
                      curP1++;
                    else
                      curP2++;
                    p1Progress.add(curP1);
                    p2Progress.add(curP2);
                  }
                  final setLogs =
                      logs.where((p) => p.setNum == setIndex + 1).toList();
                  return ExpansionTile(
                    initiallyExpanded: setIndex == allSets.length - 1,
                    title: Text('Set ${setIndex + 1}: ${set.p1Score} - ${set.p2Score}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(set.isExpediteSet ? 'Expedite System Active' : ''),
                    children: [
                      if (setLogs.isNotEmpty)
                        ...setLogs.map((entry) {
                          IconData icon = Icons.info;
                          Color color = Colors.blue;
                          String text = '';
                          if (entry.type == 'penalty') {
                            icon = Icons.warning;
                            color = (entry.cardType?.contains('red') ?? false)
                                ? Colors.red
                                : Colors.yellow;
                            String pName = 'P${entry.playerNum}';
                            if (entry.playerNum == 1)
                              pName = p1Name;
                            else if (entry.playerNum == 2)
                              pName = p2Name;
                            else if (entry.playerNum == 3)
                              pName = p3Name;
                            else if (entry.playerNum == 4) pName = p4Name;
                            text = '$pName: ${entry.reason}';
                          } else if (entry.type == 'timeout') {
                            String pName =
                                entry.playerNum == 1 || entry.playerNum == 2
                                    ? 'Team 1'
                                    : 'Team 2';
                            icon = Icons.timer;
                            color = Colors.blueGrey;
                            text = '$pName called Timeout';
                          } else if (entry.type == 'expedite') {
                            icon = Icons.flash_on;
                            color = Colors.orange;
                            text = 'Expedite System Activated';
                          }
                          return ListTile(
                              dense: true,
                              leading: Icon(icon, color: color),
                              title: Text(text),
                              subtitle: Text(
                                  'Score: ${entry.p1Score}-${entry.p2Score}'));
                        }),
                      Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildProgressRow('Team 1', p1Progress, 1),
                                    const SizedBox(height: 12),
                                    _buildProgressRow('Team 2', p2Progress, 2),
                                  ]))),
                    ],
                  );
                })),
      ]),
    );
  }

  Widget _buildProgressRow(String playerName, List<int> scores, int teamNum) {
    return Row(children: [
      SizedBox(
          width: 80,
          child: Text(playerName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 8),
      ...scores.asMap().entries.map((entry) {
        bool pointWon =
            entry.key == 0 ? entry.value > 0 : entry.value > scores[entry.key - 1];
        return Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: pointWon
                  ? (teamNum == 1 ? Colors.blue : Colors.green)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: pointWon
                  ? null
                  : Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Center(
                child: Text('${entry.value}',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: pointWon ? Colors.white : Colors.grey))));
      }),
    ]);
  }
}
