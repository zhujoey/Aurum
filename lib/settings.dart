// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sportspro/auth_service.dart';
import 'package:sportspro/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _authService = AuthService();
  final _themeService = ThemeService();
  final _usernameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = _authService.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _updateUsername() async {
    final newUsername = _usernameController.text.trim();
    if (newUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    if (newUsername == _authService.currentUser?.displayName) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username is same as current')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isTaken = await _authService.isUsernameTaken(newUsername);
      if (isTaken) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username is already taken')),
        );
        return;
      }

      await _authService.currentUser?.updateDisplayName(newUsername);
      await _authService.syncUserData(_authService.currentUser, username: newUsername);
      await _authService.currentUser?.reload();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating username: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: ListView(
            children: [
              _buildSectionHeader('Account'),
              ListTile(
                title: const Text('Change Username'),
                subtitle: Text(_authService.currentUser?.displayName ?? 'Not set'),
                leading: const Icon(Icons.person_outline),
                onTap: _showChangeUsernameDialog,
              ),
              ListTile(
                title: const Text('Gender'),
                subtitle: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(_authService.currentUser?.uid).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Text('Loading...');
                    final data = snapshot.data!.data() as Map<String, dynamic>?;
                    return Text(data?['gender'] ?? 'Not set');
                  },
                ),
                leading: const Icon(Icons.wc),
                onTap: _showSelectGenderDialog,
              ),
              const Divider(),
              _buildSectionHeader('Appearance'),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: _themeService.themeMode,
                builder: (context, mode, child) {
                  return Column(
                    children: [
                      ListTile(
                        title: const Text('Light Mode'),
                        trailing: Icon(
                          mode == ThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: mode == ThemeMode.light ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        onTap: () => _themeService.setTheme(ThemeMode.light),
                      ),
                      ListTile(
                        title: const Text('Dark Mode'),
                        trailing: Icon(
                          mode == ThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: mode == ThemeMode.dark ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        onTap: () => _themeService.setTheme(ThemeMode.dark),
                      ),
                      ListTile(
                        title: const Text('System Default'),
                        trailing: Icon(
                          mode == ThemeMode.system ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: mode == ThemeMode.system ? Theme.of(context).colorScheme.primary : Colors.grey,
                        ),
                        onTap: () => _themeService.setTheme(ThemeMode.system),
                      ),
                      ValueListenableBuilder<bool>(
                        valueListenable: _themeService.useTrueDark,
                        builder: (context, trueDark, child) {
                          return SwitchListTile(
                            title: const Text('AMOLED Mode (Pure Black)'),
                            subtitle: const Text('Saves battery on OLED screens'),
                            value: trueDark,
                            onChanged: mode == ThemeMode.light ? null : (val) => _themeService.setTrueDark(val),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
              const Divider(),
              _buildSectionHeader('Accent Color'),
              ValueListenableBuilder<Color>(
                valueListenable: _themeService.seedColor,
                builder: (context, currentSeed, child) {
                  final List<Color> availableColors = [
                    Colors.blue,
                    Colors.indigo,
                    Colors.deepPurple,
                    Colors.purple,
                    Colors.pink,
                    Colors.red,
                    Colors.deepOrange,
                    Colors.orange,
                    Colors.amber,
                    Colors.yellow,
                    Colors.lime,
                    Colors.lightGreen,
                    Colors.green,
                    Colors.teal,
                    Colors.cyan,
                    Colors.lightBlue,
                    Colors.blueGrey,
                    Colors.brown,
                  ];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: availableColors.map((color) {
                        // Use toARGB32() or compare directly to avoid .value deprecation
                        final bool isSelected = currentSeed.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () => _themeService.setColor(color),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                                  : null,
                            ),
                            child: isSelected
                                ? const Icon(Icons.check, color: Colors.white)
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_isLoading)
          Container(
            color: Colors.black45,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showChangeUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Username'),
        content: TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: 'New Username',
            hintText: 'Enter new username',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUsername();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showSelectGenderDialog() {
    String selectedGender = 'Male';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Gender'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Male'),
                trailing: Icon(
                  selectedGender == 'Male' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selectedGender == 'Male' ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                onTap: () => setDialogState(() => selectedGender = 'Male'),
              ),
              ListTile(
                title: const Text('Female'),
                trailing: Icon(
                  selectedGender == 'Female' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: selectedGender == 'Female' ? Theme.of(context).colorScheme.primary : Colors.grey,
                ),
                onTap: () => setDialogState(() => selectedGender = 'Female'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _authService.updateUserGender(selectedGender);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Gender updated successfully')),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error updating gender: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
