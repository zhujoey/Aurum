import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/widgets/user_avatar.dart';

void showUserProfileSheet(
  BuildContext context, {
  required String uid,
  String? username,
  String? photoUrl,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => UserProfileSheet(
      uid: uid,
      initialUsername: username,
      initialPhotoUrl: photoUrl,
    ),
  );
}

class UserProfileSheet extends StatefulWidget {
  final String uid;
  final String? initialUsername;
  final String? initialPhotoUrl;

  const UserProfileSheet({
    super.key,
    required this.uid,
    this.initialUsername,
    this.initialPhotoUrl,
  });

  @override
  State<UserProfileSheet> createState() => _UserProfileSheetState();
}

class _UserProfileSheetState extends State<UserProfileSheet> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentUser?.uid;
    final bool isSelf = currentUserId == widget.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('users').doc(widget.uid).snapshots(),
      builder: (context, snapshot) {
        Map<String, dynamic>? userData;
        if (snapshot.hasData && snapshot.data!.exists) {
          userData = snapshot.data!.data() as Map<String, dynamic>?;
        }

        final String name = userData?['username'] ?? widget.initialUsername ?? 'Player'.tr;
        final String? avatar = userData?['photoUrl'] ?? widget.initialPhotoUrl;
        final int points = userData?['points_open_singles'] ?? 0;
        final int elo = userData?['elo_open_singles'] ?? 800;
        final int glicko = userData?['glicko_open_singles'] ?? 800;

        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Profile Avatar
              UserAvatar(
                photoUrl: avatar,
                uid: widget.uid,
                username: name,
                radius: 44,
              ),
              const SizedBox(height: 12),

              // Username
              Text(
                name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Rating Stats Container
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(context, 'Points'.tr, '$points', Icons.emoji_events, Colors.amber),
                    _buildStatItem(context, 'Elo'.tr, '$elo', Icons.leaderboard, Colors.blue),
                    _buildStatItem(context, 'Glicko'.tr, '$glicko', Icons.star, Colors.purple),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Friend Action Button (if not inspecting self)
              if (!isSelf && currentUserId != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: _db
                      .collection('users')
                      .doc(currentUserId)
                      .collection('friends')
                      .doc(widget.uid)
                      .snapshots(),
                  builder: (context, friendSnap) {
                    final bool isFriend = friendSnap.hasData && friendSnap.data!.exists;

                    if (isFriend) {
                      return OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check, color: Colors.green),
                        label: Text('Friends'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          await _authService.removeFriend(widget.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Removed $name from friends.'.tr)),
                            );
                          }
                        },
                      );
                    }

                    return ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.person_add),
                      label: Text('Add Friend'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () async {
                        try {
                          await _authService.sendFriendRequest(widget.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Friend request sent to $name!'.tr)),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString().tr)),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodySmall?.color),
        ),
      ],
    );
  }
}
