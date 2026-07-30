import 'package:flutter/material.dart';

class MatchStatsSummary extends StatelessWidget {
  final Map<String, dynamic> s1;
  final Map<String, dynamic> s2;

  const MatchStatsSummary({
    super.key,
    required this.s1,
    required this.s2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
        child: Column(children: [
          const Text('MATCH STATISTICS',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: Colors.amber)),
          const SizedBox(height: 20),
          _statsRow('Total Points', '${s1['totalPoints']}', '${s2['totalPoints']}'),
          const Divider(height: 24),
          _statsRow(
              'Longest Streak', '${s1['longestStreak']}', '${s2['longestStreak']}'),
          const Divider(height: 24),
          _statsRow('Win % on Serve',
              '${s1['serveWinRate'].toStringAsFixed(2)}%', '${s2['serveWinRate'].toStringAsFixed(2)}%'),
        ]));
  }

  Widget _statsRow(String label, String v1, String v2) {
    return Row(children: [
      Expanded(
          child: Text(v1,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
      Expanded(
          flex: 2,
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13))),
      Expanded(
          child: Text(v2,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
    ]);
  }
}
