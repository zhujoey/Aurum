import 'package:flutter/material.dart';
import '../tennis_models.dart';

class TennisTimerBanner extends StatefulWidget {
  final String title;
  final int endTime;
  final bool isHost;
  final VoidCallback onSkip;

  const TennisTimerBanner({
    super.key,
    required this.title,
    required this.endTime,
    required this.isHost,
    required this.onSkip,
  });

  @override
  State<TennisTimerBanner> createState() => _TennisTimerBannerState();
}

class _TennisTimerBannerState extends State<TennisTimerBanner> {
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
  }

  @override
  void didUpdateWidget(TennisTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateRemaining();
  }

  void _updateRemaining() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _secondsRemaining = ((widget.endTime - now) / 1000).ceil();
    if (_secondsRemaining < 0) _secondsRemaining = 0;
  }

  @override
  Widget build(BuildContext context) {
    final min = _secondsRemaining ~/ 60;
    final sec = _secondsRemaining % 60;
    final timeStr = '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';

    return Container(
      width: double.infinity,
      color: Colors.blue.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              Text(
                '${widget.title}: $timeStr',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          if (widget.isHost)
            TextButton(
              onPressed: widget.onSkip,
              child: const Text('SKIP', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}

class TennisPenaltyBanner extends StatelessWidget {
  final List<TennisLogEntry> logs;
  final bool isDoubles;
  final String p1Name;
  final String p2Name;

  const TennisPenaltyBanner({
    super.key,
    required this.logs,
    required this.isDoubles,
    required this.p1Name,
    required this.p2Name,
  });

  @override
  Widget build(BuildContext context) {
    final violations = logs.where((l) => l.type == 'code_violation').toList();
    if (violations.isEmpty) return const SizedBox.shrink();

    final latest = violations.last;
    final String pName = latest.playerNum == 1 ? p1Name : p2Name;

    return Container(
      width: double.infinity,
      color: Colors.red.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.warning, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Code Violation ($pName): ${latest.cardType?.toUpperCase() ?? "WARNING"} - ${latest.reason ?? "Unsportsmanlike Conduct"}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
