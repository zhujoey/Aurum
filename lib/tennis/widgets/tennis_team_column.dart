import 'package:flutter/material.dart';

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
  final VoidCallback onPointAdd;
  final VoidCallback onCodeViolation;
  final VoidCallback onMedicalTimeout;

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
    required this.onPointAdd,
    required this.onCodeViolation,
    required this.onMedicalTimeout,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(side, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isServing) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          const Icon(Icons.sports_tennis, color: Colors.white, size: 12),
                          const SizedBox(width: 2),
                          Text(servingCourt, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: isHost ? onPointAdd : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        pointText,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const Text('POINTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text('$games', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                      const Text('GAMES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      Text('$sets', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const Text('SETS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (isHost)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.warning, size: 14, color: Colors.orange),
                      label: const Text('Code', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      onPressed: onCodeViolation,
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.medical_services, size: 14, color: Colors.red),
                      label: const Text('Medical', style: TextStyle(fontSize: 11)),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                      onPressed: onMedicalTimeout,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
