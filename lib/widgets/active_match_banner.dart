import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/table_tennis/tt_scoreboard.dart';
import 'package:aurum/table_tennis/tt_models.dart';
import 'package:aurum/badminton/badminton_scoreboard.dart';
import 'package:aurum/badminton/badminton_models.dart';
import 'package:aurum/tennis/tennis_scoreboard.dart';
import 'package:aurum/tennis/tennis_models.dart';

class ActiveMatchBanner extends StatelessWidget {
  final DocumentSnapshot matchDoc;
  final VoidCallback? onForfeit;

  const ActiveMatchBanner({
    super.key,
    required this.matchDoc,
    this.onForfeit,
  });

  void _openMatch(BuildContext context) {
    final AuthService authService = AuthService();
    final data = matchDoc.data() as Map<String, dynamic>;
    final String sport = data['sport'] ?? '';
    bool isHost = data['hostUid'] == authService.currentUser?.uid;
    final matchData = data['matchData'] ?? {};

    if (sport == 'Table Tennis') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TableTennisMatch(
            p1Name: matchData['p1Name'] ?? 'P1',
            p2Name: matchData['p2Name'] ?? '',
            p3Name: matchData['p3Name'] ?? 'P2',
            p4Name: matchData['p4Name'] ?? '',
            isDoubles: matchData['isDoubles'] ?? false,
            setsToWin: matchData['setsToWin'] ?? 4,
            initialP1Score: matchData['p1Score'] ?? 0,
            initialP2Score: matchData['p2Score'] ?? 0,
            initialP1Sets: matchData['p1Sets'] ?? 0,
            initialP2Sets: matchData['p2Sets'] ?? 0,
            initialIsSetOver: matchData['isSetOver'] ?? false,
            initialPointHistory: List<int>.from(matchData['pointHistory'] ?? []),
            initialSetSummaries: (matchData['setSummaries'] as List? ?? [])
                .map((s) => SetSummary.fromMap(s))
                .toList(),
            initialP1TimeoutUsed: matchData['p1TimeoutUsed'] ?? false,
            initialP2TimeoutUsed: matchData['p2TimeoutUsed'] ?? false,
            initialFirstServerOfMatch: matchData['firstServerOfMatch'] ?? 0,
            initialFirstServerOfSet: matchData['firstServerOfSet'] ?? 0,
            initialFirstReceiverOfSet: matchData['firstReceiverOfSet'] ?? 0,
            initialP1OnLeft: matchData['p1OnLeft'] ?? true,
            initialLogs: (matchData['logs'] as List? ?? [])
                .map((p) => MatchLogEntry.fromMap(p))
                .toList(),
            initialExpediteActive: matchData['expediteActive'] ?? false,
            initialGameTimeSeconds: matchData['gameTimeSeconds'] ?? 0,
            activeTimerSeconds: matchData['activeTimerSeconds'] ?? 0,
            activeTimerTitle: matchData['activeTimerTitle'] ?? '',
            initialTimerEndTime: matchData['timerEndTime'],
            initialKeepRunningTimers: matchData['keepRunningTimers'] ?? false,
            initialLastSavedTimestamp: matchData['lastSavedTimestamp'],
            matchId: matchDoc.id,
            isHost: isHost,
          ),
        ),
      );
    } else if (sport == 'Badminton') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BadmintonMatch(
            p1Name: matchData['p1Name'] ?? 'P1',
            p2Name: matchData['p2Name'] ?? '',
            p3Name: matchData['p3Name'] ?? 'P2',
            p4Name: matchData['p4Name'] ?? '',
            isDoubles: matchData['isDoubles'] ?? false,
            gamesToWin: matchData['gamesToWin'] ?? 2,
            initialP1Score: matchData['p1Score'] ?? 0,
            initialP2Score: matchData['p2Score'] ?? 0,
            initialP1Games: matchData['p1Games'] ?? 0,
            initialP2Games: matchData['p2Games'] ?? 0,
            initialIsGameOver: matchData['isGameOver'] ?? false,
            initialPointHistory: List<int>.from(matchData['pointHistory'] ?? []),
            initialGameSummaries: (matchData['gameSummaries'] as List? ?? [])
                .map((s) => BadmintonGameSummary.fromMap(s))
                .toList(),
            initialFirstServerOfMatch: matchData['firstServerOfMatch'] ?? 0,
            initialFirstServerOfGame: matchData['firstServerOfGame'] ?? 0,
            initialP1OnLeft: matchData['p1OnLeft'] ?? true,
            initialLogs: (matchData['logs'] as List? ?? [])
                .map((l) => BadmintonLogEntry.fromMap(l))
                .toList(),
            initialMatchTimeSeconds: matchData['matchTimeSeconds'] ?? 0,
            initialKeepRunningTimers: matchData['keepRunningTimers'] ?? false,
            initialLastSavedTimestamp: matchData['lastSavedTimestamp'],
            activeTimerEndTime: matchData['timerEndTime'],
            activeTimerTitle: matchData['timerTitle'] ?? '',
            matchId: matchDoc.id,
            isHost: isHost,
          ),
        ),
      );
    } else if (sport == 'Tennis') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TennisMatch(
            p1Name: matchData['p1Name'] ?? 'P1',
            p2Name: matchData['p2Name'] ?? '',
            p3Name: matchData['p3Name'] ?? 'P2',
            p4Name: matchData['p4Name'] ?? '',
            isDoubles: matchData['isDoubles'] ?? false,
            setsToWin: matchData['setsToWin'] ?? 2,
            initialP1Pts: matchData['p1Pts'] ?? 0,
            initialP2Pts: matchData['p2Pts'] ?? 0,
            initialP1Games: matchData['p1Games'] ?? 0,
            initialP2Games: matchData['p2Games'] ?? 0,
            initialP1Sets: matchData['p1Sets'] ?? 0,
            initialP2Sets: matchData['p2Sets'] ?? 0,
            initialIsTiebreak: matchData['isTiebreak'] ?? false,
            initialP1TiebreakPts: matchData['p1TiebreakPts'] ?? 0,
            initialP2TiebreakPts: matchData['p2TiebreakPts'] ?? 0,
            initialServerPlayerNum: matchData['serverPlayerNum'] ?? 1,
            initialP1OnLeft: matchData['p1OnLeft'] ?? true,
            initialIsFinished: matchData['isFinished'] ?? false,
            initialSetSummaries: (matchData['setSummaries'] as List? ?? [])
                .map((s) => TennisSetSummary.fromMap(Map<String, dynamic>.from(s)))
                .toList(),
            initialLogs: (matchData['logs'] as List? ?? [])
                .map((l) => TennisLogEntry.fromMap(Map<String, dynamic>.from(l)))
                .toList(),
            initialMatchTimeSeconds: matchData['matchTimeSeconds'] ?? 0,
            activeTimerEndTime: matchData['timerEndTime'],
            activeTimerTitle: matchData['timerTitle'] ?? '',
            matchId: matchDoc.id,
            isHost: isHost,
            initialKeepRunningTimers: matchData['keepRunningTimers'] ?? true,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final data = matchDoc.data() as Map<String, dynamic>;
    bool isHost = data['hostUid'] == authService.currentUser?.uid;

    return Card(
      color: Colors.amber.withValues(alpha: 0.1),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.sports_tennis, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Match in Progress'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(isHost ? 'You are hosting a match.'.tr : 'You are participating in a match.'.tr, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isHost)
                  TextButton(
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Discard Match?'.tr),
                          content: Text('This will delete all match data. This action cannot be undone.'.tr),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Discard'.tr, style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await authService.deleteActiveMatch(matchDoc.id);
                        onForfeit?.call();
                      }
                    },
                    child: Text('Discard Match'.tr, style: const TextStyle(color: Colors.red)),
                  )
                else
                  TextButton(
                    onPressed: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Forfeit Match?'.tr),
                          content: Text('You will be marked as forfeited and this match will end for everyone. This cannot be undone.'.tr),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Forfeit'.tr, style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await authService.updateMatchStatus(matchDoc.id, 'forfeited');
                        onForfeit?.call();
                      }
                    },
                    child: Text('Forfeit'.tr, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _openMatch(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('View Match'.tr),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
