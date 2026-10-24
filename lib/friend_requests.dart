import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/language_service.dart';

class FriendRequestsPage extends StatelessWidget {
  const FriendRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return Scaffold(
      appBar: AppBar(title: Text('Friend Requests'.tr)),
      body: StreamBuilder<QuerySnapshot>(
        stream: authService.incomingFriendRequests,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No pending requests.'.tr));
          }

          final requests = snapshot.data!.docs;

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final data = req.data() as Map<String, dynamic>;
              final fromUsername = data['fromUsername'] ?? 'Unknown';
              final fromUid = data['fromUid'];

              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(fromUsername),
                subtitle: Text('wants to be your friend'.tr),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () => authService.acceptFriendRequest(req.id, fromUid, fromUsername),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => authService.declineFriendRequest(req.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
