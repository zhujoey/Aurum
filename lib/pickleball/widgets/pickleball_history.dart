import 'package:flutter/material.dart';
import 'package:aurum/language_service.dart';
import '../pickleball_models.dart';

class PickleballMatchHistoryBottomSheet extends StatelessWidget {
  final List<PickleballGameSummary> gameSummaries;
  final List<PickleballLogEntry> logs;
  final String p1Name;
  final String p2Name;
  final String p3Name;
  final String p4Name;
  final bool isDoubles;

  const PickleballMatchHistoryBottomSheet({
    super.key,
    required this.gameSummaries,
    required this.logs,
    required this.p1Name,
    required this.p2Name,
    required this.p3Name,
    required this.p4Name,
    required this.isDoubles,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Match History & Set Summaries'.tr, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                Text('Games Summary'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (gameSummaries.isEmpty)
                  Text('No completed games yet.'.tr)
                else
                  ...gameSummaries.asMap().entries.map((entry) {
                    int idx = entry.key;
                    var summary = entry.value;
                    return Card(
                      child: ListTile(
                        title: Text('${'Game'.tr} ${idx + 1}'),
                        trailing: Text('${summary.p1Score} - ${summary.p2Score}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    );
                  }),
                const SizedBox(height: 20),
                Text('Match Event Logs'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (logs.isEmpty)
                  Text('No logs recorded yet.'.tr)
                else
                  ...logs.map((l) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline, size: 16),
                    title: Text('${l.type.toUpperCase()}: Game ${l.gameNum} (${l.p1Score}-${l.p2Score})'),
                    subtitle: l.detail != null ? Text(l.detail!) : null,
                  )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
