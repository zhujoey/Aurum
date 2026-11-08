import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:aurum/settings.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/new_match.dart';
import 'package:aurum/clubs.dart';
import 'package:aurum/tournaments.dart';
import 'package:aurum/rankings.dart';
import 'package:aurum/language_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/ui_helpers.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final AuthService _authService = AuthService();
  late final int _quoteIndex;
  static const int _totalQuotes = 18;

  String _getQuote(int index, String displayName) {
    switch (index) {
      case 0:
        return "${"Ready to make today count".tr}, $displayName?";
      case 1:
        return "${"Small daily wins add up".tr}, $displayName.";
      case 2:
        return "Focus on progress, not perfection.".tr;
      case 3:
        return "Your next personal best starts right now.".tr;
      case 4:
        return "${"Keep pushing your limits today".tr}, $displayName.";
      case 5:
        return "Every match makes you sharper.".tr;
      case 6:
        return "${"Time to put in the work".tr}, $displayName.";
      case 7:
        return "Stay sharp, stay hungry.".tr;
      case 8:
        return "Consistency is your superpower.".tr;
      case 9:
        return "${"One step closer to your goals".tr}, $displayName.";
      case 10:
        return "${"Let's make today productive".tr}, $displayName.";
      case 11:
        return "Trust the process and play your game.".tr;
      case 12:
        return "${"Discipline beats motivation".tr}, $displayName.";
      case 13:
        return "Own your momentum today.".tr;
      case 14:
        return "${"Greatness is built one step at a time".tr}, $displayName.";
      case 15:
        return "${"Keep moving forward".tr}, $displayName.";
      case 16:
        return "Chasing excellence, one day at a time.".tr;
      case 17:
        return "${"Your potential is endless".tr}, $displayName.";
      default:
        return "Focus on progress, not perfection.".tr;
    }
  }

  @override
  void initState() {
    super.initState();
    _initialSync();
    _quoteIndex = Random().nextInt(_totalQuotes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prewarmQuoteTranslations();
    });
  }

  void _prewarmQuoteTranslations() {
    final lang = LanguageService().currentLocale.value.languageCode;
    if (lang == 'en') return;
    const phrases = [
      "Ready to make today count",
      "Small daily wins add up",
      "Focus on progress, not perfection.",
      "Your next personal best starts right now.",
      "Keep pushing your limits today",
      "Every match makes you sharper.",
      "Time to put in the work",
      "Stay sharp, stay hungry.",
      "Consistency is your superpower.",
      "One step closer to your goals",
      "Let's make today productive",
      "Trust the process and play your game.",
      "Discipline beats motivation",
      "Own your momentum today.",
      "Greatness is built one step at a time",
      "Keep moving forward",
      "Chasing excellence, one day at a time.",
      "Your potential is endless",
    ];
    for (final p in phrases) {
      p.tr;
    }
  }

  Future<void> _initialSync() async {
    final user = _authService.currentUser;
    if (user != null) {
      if (user.displayName == null || user.displayName!.isEmpty) {
        user.reload().then((_) {
          _authService.syncUserData(_authService.currentUser);
        }).catchError((e) {
          debugPrint("Error reloading user on startup: $e");
        });
      } else {
        _authService.syncUserData(user);
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authService.currentUser?.uid;
    return ValueListenableBuilder<int>(
      valueListenable: LanguageService().appLanguageVersion,
      builder: (context, version, child) {
        return StreamBuilder<User?>(
          stream: _authService.userStream,
          builder: (context, snapshot) {
            final user = snapshot.data;
            final String displayName = user?.displayName?.isNotEmpty == true
                ? user!.displayName!
                : (user?.email?.split('@').first ?? 'Player');

            final quote = _getQuote(_quoteIndex, displayName);

            return Scaffold(
              appBar: AppBar(
            title: const Icon(Icons.home),
            actions: [
              StreamBuilder<QuerySnapshot>(
                stream: _authService.incomingFriendRequests,
                builder: (context, snapshot) {
                  final bool hasRequests = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings),
                        onPressed: () {
                          UIHelpers.smoothPush(context, const SettingsPage());
                        },
                      ),
                      if (hasRequests)
                        Positioned(
                          right: 11,
                          top: 11,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quote,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.78,
                  children: [
                    StreamBuilder<DocumentSnapshot>(
                      stream: currentUid != null
                          ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
                          : const Stream.empty(),
                      builder: (context, userSnap) {
                        final userData = userSnap.hasData ? userSnap.data!.data() as Map<String, dynamic>? ?? {} : {};
                        final String? clubId = userData['ownedClubId'] ?? userData['joinedClubId'] ?? userData['selectedClubId'];

                        if (clubId == null || clubId.isEmpty) {
                          return _buildHubCard(
                            context: context,
                            categoryTitle: 'Rankings',
                            accentColor: Colors.orange,
                            title: 'Leaderboard',
                            subtitle: 'Join a club to view rankings',
                            icon: Icons.leaderboard,
                            onTap: () => UIHelpers.smoothPush(context, const RankingsPage()),
                            previewContent: const Text('No club joined', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          );
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('clubs')
                              .doc(clubId)
                              .collection('members')
                              .orderBy('points_open_singles', descending: true)
                              .snapshots(),
                          builder: (context, membersSnap) {
                            if (!membersSnap.hasData || membersSnap.data!.docs.isEmpty) {
                              return _buildHubCard(
                                context: context,
                                categoryTitle: 'Rankings',
                                accentColor: Colors.orange,
                                title: 'Leaderboard',
                                subtitle: 'No ranked members yet',
                                icon: Icons.leaderboard,
                                onTap: () => UIHelpers.smoothPush(context, const RankingsPage()),
                                previewContent: const Text('No rankings available', style: TextStyle(fontSize: 11, color: Colors.white70)),
                              );
                            }

                            final docs = membersSnap.data!.docs;
                            int myRank = 1;
                            int myPoints = 0;
                            for (int i = 0; i < docs.length; i++) {
                              final data = docs[i].data() as Map<String, dynamic>;
                              final uId = data['uid'] ?? docs[i].id;
                              if (uId == currentUid || docs[i].id == currentUid) {
                                myRank = i + 1;
                                myPoints = data['points_open_singles'] ?? 0;
                                break;
                              }
                            }

                            final top3 = docs.take(3).toList();

                            return _buildHubCard(
                              context: context,
                              categoryTitle: 'Rankings',
                              accentColor: Colors.orange,
                              title: 'Leaderboard',
                              subtitle: 'Rank: #$myRank • $myPoints pts',
                              icon: Icons.leaderboard,
                              onTap: () => UIHelpers.smoothPush(context, const RankingsPage()),
                              previewContent: Column(
                                children: top3.asMap().entries.map((entry) {
                                  int idx = entry.key;
                                  var doc = entry.value;
                                  final data = doc.data() as Map<String, dynamic>;
                                  final name = data['username'] ?? data['displayName'] ?? 'Player';
                                  final pts = data['points_open_singles'] ?? 0;
                                  final uId = data['uid'] ?? doc.id;
                                  final bool isMe = uId == currentUid || doc.id == currentUid;
                                  return _buildRankRow(
                                    '${idx + 1}',
                                    isMe ? '$name (You)' : name,
                                    '$pts pts',
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        );
                      },
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: currentUid != null
                          ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
                          : const Stream.empty(),
                      builder: (context, userSnap) {
                        final userData = userSnap.hasData ? userSnap.data!.data() as Map<String, dynamic>? ?? {} : {};
                        final String? clubId = userData['ownedClubId'] ?? userData['joinedClubId'] ?? userData['selectedClubId'];

                        if (clubId == null || clubId.isEmpty) {
                          return _buildHubCard(
                            context: context,
                            categoryTitle: 'Clubs',
                            accentColor: Colors.blue,
                            title: 'Clubs',
                            subtitle: 'No club joined',
                            icon: Icons.groups,
                            onTap: () => UIHelpers.smoothPush(context, const ClubsPage()),
                            previewContent: const Text('Join or create a club', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          );
                        }

                        return StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance.collection('clubs').doc(clubId).snapshots(),
                          builder: (context, clubSnap) {
                            final clubData = clubSnap.hasData ? clubSnap.data!.data() as Map<String, dynamic>? ?? {} : {};
                            final clubName = clubData['name'] ?? 'Club';
                            final clubSport = clubData['sport'] ?? 'Multi-sport';

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('clubs')
                                  .doc(clubId)
                                  .collection('members')
                                  .snapshots(),
                              builder: (context, membersSnap) {
                                final memberCount = membersSnap.hasData ? membersSnap.data!.docs.length : 0;

                                return _buildHubCard(
                                  context: context,
                                  categoryTitle: 'Clubs',
                                  accentColor: Colors.blue,
                                  title: clubName,
                                  subtitle: '$memberCount Member(s) • $clubSport',
                                  icon: Icons.groups,
                                  onTap: () => UIHelpers.smoothPush(context, const ClubsPage()),
                                  previewContent: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      'Tap to manage club & members',
                                      style: TextStyle(fontSize: 11, color: Colors.white70),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: _authService.myActiveMatches,
                      builder: (context, matchSnap) {
                        final bool hasActiveMatch = matchSnap.hasData && matchSnap.data!.docs.isNotEmpty;
                        return _buildHubCard(
                          context: context,
                          categoryTitle: 'Quick Match',
                          accentColor: Colors.green,
                          title: hasActiveMatch ? 'Active Match' : 'Instant Match',
                          subtitle: hasActiveMatch ? 'Match in progress' : 'GPS Ready • Finding opponent',
                          icon: Icons.sports_tennis,
                          onTap: () => UIHelpers.smoothPush(context, const NewMatch()),
                          previewContent: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                hasActiveMatch ? 'Tap to Resume Match' : 'Ready to Play',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent),
                              ),
                              Icon(hasActiveMatch ? Icons.play_arrow : Icons.explore, color: Colors.greenAccent, size: 22),
                            ],
                          ),
                        );
                      },
                    ),
                    StreamBuilder<DocumentSnapshot>(
                      stream: currentUid != null
                          ? FirebaseFirestore.instance.collection('users').doc(currentUid).snapshots()
                          : const Stream.empty(),
                      builder: (context, userSnap) {
                        final userData = userSnap.hasData ? userSnap.data!.data() as Map<String, dynamic>? ?? {} : {};
                        final String? clubId = userData['ownedClubId'] ?? userData['joinedClubId'] ?? userData['selectedClubId'];

                        if (clubId == null || clubId.isEmpty) {
                          return _buildHubCard(
                            context: context,
                            categoryTitle: 'Tournaments',
                            accentColor: Colors.redAccent,
                            title: 'Tournaments',
                            subtitle: 'Join a club to view tournaments',
                            icon: Icons.military_tech,
                            onTap: () => UIHelpers.smoothPush(context, TournamentsPage()),
                            previewContent: const Text('No active tournaments', style: TextStyle(fontSize: 11, color: Colors.white70)),
                          );
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('clubs')
                              .doc(clubId)
                              .collection('tournaments')
                              .snapshots(),
                          builder: (context, tourSnap) {
                            final tours = tourSnap.hasData ? tourSnap.data!.docs : [];
                            
                            var ongoing = <QueryDocumentSnapshot>[];
                            var upcoming = <QueryDocumentSnapshot>[];
                            var finished = <QueryDocumentSnapshot>[];

                            for (var doc in tours) {
                              final d = doc.data() as Map<String, dynamic>;
                              final status = (d['status'] ?? 'upcoming').toString().toLowerCase();
                              if (status == 'active' || status == 'playing' || status == 'in_progress') {
                                ongoing.add(doc);
                              } else if (status == 'completed' || status == 'finished') {
                                finished.add(doc);
                              } else {
                                upcoming.add(doc);
                              }
                            }

                            String title = 'Tournaments';
                            String subtitle = 'No tournaments';
                            String previewText = 'Tap to view tournaments';

                            if (ongoing.isNotEmpty) {
                              final d = ongoing.first.data() as Map<String, dynamic>;
                              title = d['name'] ?? 'Tournament';
                              subtitle = 'Live Now';
                              previewText = '${ongoing.length} Ongoing Tourney(s)';
                            } else if (upcoming.isNotEmpty) {
                              final d = upcoming.first.data() as Map<String, dynamic>;
                              title = d['name'] ?? 'Tournament';
                              subtitle = 'Upcoming';
                              previewText = '${upcoming.length} Upcoming Tourney(s)';
                            } else if (finished.isNotEmpty) {
                              final d = finished.first.data() as Map<String, dynamic>;
                              title = d['name'] ?? 'Tournament';
                              subtitle = 'Finished';
                              previewText = '${finished.length} Finished Tourney(s)';
                            }

                            return _buildHubCard(
                              context: context,
                              categoryTitle: 'Tournaments',
                              accentColor: Colors.redAccent,
                              title: title,
                              subtitle: subtitle,
                              icon: Icons.military_tech,
                              onTap: () => UIHelpers.smoothPush(context, TournamentsPage()),
                              previewContent: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    previewText,
                                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                                  ),
                                  const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
          },
        );
      },
    );
  }

  Widget _buildHubCard({
    required BuildContext context,
    required String categoryTitle,
    required Color accentColor,
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget previewContent,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryTitle.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: PressableCard(
            onTap: () {
              UIHelpers.hapticDoublePulse();
              onTap();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.8),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.28),
                    blurRadius: 18,
                    spreadRadius: 1,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentColor.withValues(alpha: 0.30),
                          accentColor.withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          bottom: -10,
                          child: Icon(
                            icon,
                            size: 75,
                            color: accentColor.withValues(alpha: 0.1),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.7), size: 20),
                              ],
                            ),
                            const Spacer(),
                            previewContent,
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRankRow(String pos, String name, String rank) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(pos, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
            ],
          ),
          Text(rank, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        ],
      ),
    );
  }
}

