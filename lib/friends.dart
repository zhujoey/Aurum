import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/friend_requests.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _searchResults = [];
  Set<String> _friendUids = {};
  bool _isSearching = false;
  StreamSubscription? _friendsSub;

  @override
  void initState() {
    super.initState();
    _listenToFriends();
  }

  @override
  void dispose() {
    _friendsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _listenToFriends() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return;

    _friendsSub = _db
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _friendUids = snapshot.docs.map((doc) => doc.id).toSet();
        });
      }
    });
  }

  void _searchUsers(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final String searchKey = trimmed.toLowerCase();

    // Exact match search to prevent browsing/spamming users
    final results = await _db
        .collection('users')
        .where('username_search', isEqualTo: searchKey)
        .limit(1)
        .get();

    setState(() {
      _searchResults = results.docs
          .map((doc) => doc.data())
          .where((user) => user['uid'] != _authService.currentUser?.uid) // Don't show myself
          .toList();
      _isSearching = false;
    });
  }

  Future<void> _sendFriendRequest(String targetUid, String friendName) async {
    try {
      await _authService.sendFriendRequest(targetUid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $friendName!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _unfriend(String targetUid, String friendName) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend?'),
        content: Text('Are you sure you want to remove $friendName from your friends list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _authService.removeFriend(targetUid);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$friendName removed from friends.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendRequestsPage()),
                ),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: _authService.incomingFriendRequests,
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    return Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text(
                          '${snapshot.data!.docs.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 8),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Enter exact username...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: () => _searchUsers(_searchController.text),
                    ),
                  ],
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onSubmitted: _searchUsers,
              textInputAction: TextInputAction.search,
            ),
          ),
          if (_isSearching) const LinearProgressIndicator(),
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResults()
                : _buildFriendsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty && !_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text(
            'No user found with that exact username.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        final bool isAlreadyFriend = _friendUids.contains(user['uid']);

        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user['username']),
          subtitle: const Text('Exact match found'),
          trailing: isAlreadyFriend
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.person_add, color: Colors.blue),
                  onPressed: () => _sendFriendRequest(user['uid'], user['username']),
                ),
        );
      },
    );
  }

  Widget _buildFriendsList() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final friends = snapshot.data!.docs;

        if (friends.isEmpty) {
          return const Center(child: Text('You haven\'t added any friends yet.'));
        }

        return ListView.builder(
          itemCount: friends.length,
          itemBuilder: (context, index) {
            final friend = friends[index].data() as Map<String, dynamic>;
            final String friendUid = friends[index].id;
            final String friendName = friend['username'] ?? 'Unknown';

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(friendName),
              trailing: IconButton(
                icon: const Icon(Icons.person_remove, color: Colors.grey),
                onPressed: () => _unfriend(friendUid, friendName),
              ),
              onTap: () {
                // Show friend stats/profile later
              },
            );
          },
        );
      },
    );
  }
}
