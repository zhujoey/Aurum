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
  bool _isSearching = false;

  void _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    final String searchKey = query.toLowerCase().trim();

    final results = await _db
        .collection('users')
        .where('username_search', isGreaterThanOrEqualTo: searchKey)
        .where('username_search', isLessThanOrEqualTo: '$searchKey\uf8ff')
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
          SnackBar(content: Text('Friend request sent to $friendName!')),
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
                hintText: 'Search users by username...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _searchUsers('');
                  },
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: _searchUsers,
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
      return const Center(child: Text('No users found.'));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user['username']),
          trailing: IconButton(
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
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(friend['username']),
              trailing: const Icon(Icons.chevron_right),
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
