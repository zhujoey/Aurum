import 'package:flutter/material.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/login.dart';
import 'package:sportspro/friends.dart';
import 'package:sportspro/settings.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Profile extends StatelessWidget {
  const Profile({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    
    return StreamBuilder<User?>(
      stream: authService.userStream,
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profile'),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                const Center(
                  child: CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  user?.displayName ?? 'User Name',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(user?.email ?? 'user@example.com'),
                const SizedBox(height: 30),
                const Divider(),
                _buildListTile(
                  context,
                  Icons.people,
                  'Friends',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const FriendsPage()),
                    );
                  },
                ),
                _buildListTile(
                  context,
                  Icons.sync,
                  'Sync Account Data',
                  onTap: () async {
                    await authService.syncUserData(authService.currentUser);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                        const SnackBar(content: Text('Account data synced with cloud.')),
                      );
                    }
                  },
                ),
                _buildListTile(
                  context,
                  Icons.settings,
                  'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SettingsPage()),
                    );
                  },
                ),
                const Divider(),
                _buildListTile(
                  context, 
                  Icons.logout, 
                  'Logout', 
                  textColor: Colors.red,
                  onTap: () async {
                    await authService.signOut();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const Login()),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, {Color? textColor, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap ?? () {
        // Handle tap
      },
    );
  }
}
