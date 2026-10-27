// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurum/auth_service.dart';
import 'package:aurum/theme_service.dart';
import 'package:aurum/language_service.dart';
import 'package:aurum/friends.dart';
import 'package:aurum/login.dart';

void _showAppSnackBar(BuildContext context, SnackBar snackBar) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: snackBar.backgroundColor,
      duration: snackBar.duration,
      behavior: SnackBarBehavior.floating,
      content: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => messenger.hideCurrentSnackBar(),
        child: Container(
          color: Colors.transparent,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: snackBar.content,
        ),
      ),
    ),
  );
}

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
      _showAppSnackBar(context, 
        SnackBar(content: Text('Username cannot be empty'.tr)),
      );
      return;
    }

    if (newUsername == _authService.currentUser?.displayName) {
      _showAppSnackBar(context, 
        SnackBar(content: Text('Username is same as current'.tr)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isTaken = await _authService.isUsernameTaken(newUsername);
      if (isTaken) {
        if (!mounted) return;
        _showAppSnackBar(context, 
          SnackBar(content: Text('Username is already taken'.tr)),
        );
        return;
      }

      await _authService.currentUser?.updateDisplayName(newUsername);
      await _authService.syncUserData(_authService.currentUser, username: newUsername);
      await _authService.currentUser?.reload();

      if (!mounted) return;
      _showAppSnackBar(context, 
        SnackBar(content: Text('Username updated successfully'.tr)),
      );
    } catch (e) {
      if (!mounted) return;
      _showAppSnackBar(context, 
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
            title: AnimatedBuilder(
              animation: Listenable.merge([
                LanguageService().currentLocale,
                LanguageService().appLanguageVersion,
              ]),
              builder: (context, child) => Text('Settings'.tr),
            ),
            centerTitle: true,
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(_authService.currentUser?.uid)
                .snapshots(),
            builder: (context, snapshot) {
              final userData = snapshot.hasData && snapshot.data!.exists
                  ? snapshot.data!.data() as Map<String, dynamic>? ?? {}
                  : {};

              final user = _authService.currentUser;
              final String username = userData['username'] ?? user?.displayName ?? 'User Name';
              final String email = user?.email ?? 'user@example.com';
              final String? photoUrl = userData['photoUrl'] ?? user?.photoURL;

              return ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 16),
                  // Profile Avatar Header
                  Center(
                    child: GestureDetector(
                      onTap: () => _showProfilePictureDialog(photoUrl),
                      child: Stack(
                        children: [
                          _buildAvatar(photoUrl, radius: 52),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  const Divider(),

                  // Friends Section
                  ListTile(
                    leading: const Icon(Icons.people, color: Colors.blue),
                    title: Text('Friends'.tr, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('Manage friends & send requests'.tr),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendsPage()),
                      );
                    },
                  ),
                  const Divider(),

                  // Account Section
                  _buildSectionHeader('Account'.tr),
                  ListTile(
                    title: Text('Change Username'.tr),
                    subtitle: Text(username),
                    leading: const Icon(Icons.person_outline),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showChangeUsernameDialog,
                  ),
                  ListTile(
                    title: Text('Gender'.tr),
                    subtitle: Text((userData['gender'] as String? ?? 'Not set').tr),
                    leading: const Icon(Icons.wc),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showSelectGenderDialog,
                  ),
                  ListTile(
                    title: Text('Email Verification Status'.tr),
                    subtitle: Text(email),
                    leading: const Icon(Icons.verified_user_outlined),
                    trailing: Chip(
                      avatar: Icon(
                        (user?.emailVerified ?? false) ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: (user?.emailVerified ?? false) ? Colors.green : Colors.orange,
                        size: 16,
                      ),
                      label: Text(
                        (user?.emailVerified ?? false) ? 'Verified'.tr : 'Unverified'.tr,
                        style: TextStyle(
                          color: (user?.emailVerified ?? false) ? Colors.green : Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    onTap: _showAccountVerificationDialog,
                  ),
                  const Divider(),

                  // Language Section
                  _buildSectionHeader('Language'.tr),
                  ValueListenableBuilder<Locale>(
                    valueListenable: LanguageService().currentLocale,
                    builder: (context, locale, child) {
                      final info = LanguageService().currentLanguageInfo;
                      return ListTile(
                        title: Text('${info['native']} (${info['name']})'),
                        trailing: const Icon(Icons.language),
                        onTap: _showSelectLanguageDialog,
                      );
                    },
                  ),
                  const Divider(),

                  // Appearance Section
                  _buildSectionHeader('Appearance'.tr),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: _themeService.themeMode,
                    builder: (context, mode, child) {
                      return Column(
                        children: [
                          ListTile(
                            title: Text('Dark Mode (recommended)'.tr),
                            trailing: Icon(
                              mode == ThemeMode.dark ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: mode == ThemeMode.dark ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            onTap: () => _themeService.setTheme(ThemeMode.dark),
                          ),
                          ListTile(
                            title: Text('Light Mode'.tr),
                            trailing: Icon(
                              mode == ThemeMode.light ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: mode == ThemeMode.light ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            onTap: () => _themeService.setTheme(ThemeMode.light),
                          ),
                          ListTile(
                            title: Text('System Default'.tr),
                            trailing: Icon(
                              mode == ThemeMode.system ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: mode == ThemeMode.system ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            onTap: () => _themeService.setTheme(ThemeMode.system),
                          ),
                        ],
                      );
                    },
                  ),
                  const Divider(),

                  // Accent Color Section
                  _buildSectionHeader('Accent Color'.tr),
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
                  const Divider(height: 32),

                  // Logout Section
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: Text('Logout'.tr, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    onTap: () async {
                      bool? confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Logout'.tr),
                          content: Text('Are you sure you want to log out?'.tr),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr)),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Logout'.tr, style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _authService.signOut();
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => const Login()),
                          (route) => false,
                        );
                      }
                    },
                  ),
                ],
              );
            },
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

  Widget _buildAvatar(String? photoUrl, {required double radius}) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      if (photoUrl.startsWith('data:image')) {
        try {
          final String base64Data = photoUrl.split(',').last;
          final Uint8List bytes = base64Decode(base64Data);
          return CircleAvatar(
            radius: radius,
            backgroundImage: MemoryImage(bytes),
          );
        } catch (e) {
          debugPrint("Error decoding base64 avatar: $e");
        }
      } else if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(photoUrl),
        );
      } else {
        // Emoji or character avatar
        return CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            photoUrl,
            style: TextStyle(fontSize: radius * 0.9),
          ),
        );
      }
    }
    return CircleAvatar(
      radius: radius,
      child: Icon(Icons.person, size: radius * 1.1),
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

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );

      if (image != null) {
        final Uint8List bytes = await image.readAsBytes();
        final String base64String = base64Encode(bytes);
        final String mimeType = image.mimeType ?? 'image/jpeg';
        final String dataUrl = 'data:$mimeType;base64,$base64String';

        setState(() => _isLoading = true);
        await _authService.updateUserPhotoUrl(dataUrl);
        if (mounted) {
          _showAppSnackBar(context, SnackBar(content: Text('Profile picture updated!'.tr)));
        }
      }
    } catch (e) {
      if (mounted) {
        _showAppSnackBar(context, SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showProfilePictureDialog(String? currentPhotoUrl) {
    final urlController = TextEditingController(
      text: (currentPhotoUrl != null && currentPhotoUrl.startsWith('http')) ? currentPhotoUrl : '',
    );
    final List<String> sportsEmojis = [
      '🏓', '🏸', '🎾', '🏆', '🥇', '🥈', '🥉', '⚡', '🔥', '🦁', '🦅', '🛡️', '🎯', '🏅'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Profile Picture Customization'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload From Device:'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library, size: 18),
                  label: Text('Gallery'.tr),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Or Enter Image URL:'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: urlController,
                decoration: InputDecoration(
                  labelText: 'Image URL'.tr,
                  hintText: 'https://example.com/avatar.png',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Text('Preset Sports Avatars:'.tr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: sportsEmojis.map((emoji) {
                  final bool isSelected = currentPhotoUrl == emoji;
                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);
                      try {
                        await _authService.updateUserPhotoUrl(emoji);
                        if (mounted) {
                          _showAppSnackBar(context, SnackBar(content: Text('Profile picture updated!'.tr)));
                        }
                      } catch (e) {
                        if (mounted) {
                          _showAppSnackBar(context, SnackBar(content: Text('$e')));
                        }
                      } finally {
                        if (mounted) setState(() => _isLoading = false);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              final String url = urlController.text.trim();
              if (url.isEmpty) return;
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                await _authService.updateUserPhotoUrl(url);
                if (mounted) {
                  _showAppSnackBar(context, SnackBar(content: Text('Profile picture updated!'.tr)));
                }
              } catch (e) {
                if (mounted) {
                  _showAppSnackBar(context, SnackBar(content: Text('$e')));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
  }

  void _showChangeUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Username'.tr),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'New Username'.tr,
            hintText: 'Enter new username'.tr,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateUsername();
            },
            child: Text('Save'.tr),
          ),
        ],
      ),
    );
  }

  void _showSelectGenderDialog() {
    String selectedGender = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Select Gender'.tr),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.male, size: 18, color: selectedGender == 'Male' ? Colors.white : Colors.blue),
                      label: Text('Male'.tr),
                      selected: selectedGender == 'Male',
                      selectedColor: Colors.blue,
                      labelStyle: TextStyle(color: selectedGender == 'Male' ? Colors.white : null, fontWeight: FontWeight.bold),
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedGender = 'Male');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      avatar: Icon(Icons.female, size: 18, color: selectedGender == 'Female' ? Colors.white : Colors.pink),
                      label: Text('Female'.tr),
                      selected: selectedGender == 'Female',
                      selectedColor: Colors.pink,
                      labelStyle: TextStyle(color: selectedGender == 'Female' ? Colors.white : null, fontWeight: FontWeight.bold),
                      onSelected: (selected) {
                        if (selected) setDialogState(() => selectedGender = 'Female');
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr)),
            ElevatedButton(
              onPressed: () async {
                if (selectedGender.isEmpty) {
                  _showAppSnackBar(context, SnackBar(content: Text('Please select a gender (Male or Female) before saving.'.tr)));
                  return;
                }
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await _authService.updateUserGender(selectedGender);
                  if (context.mounted) {
                    _showAppSnackBar(context, 
                      SnackBar(content: Text('Gender updated successfully'.tr)),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showAppSnackBar(context, 
                      SnackBar(content: Text('Error updating gender: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: Text('Save'.tr),
            ),
          ],
        ),
      ),
    );
  }

  void _showAccountVerificationDialog() async {
    await _authService.reloadUser();
    final user = _authService.currentUser;
    final bool isVerified = user?.emailVerified ?? false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Email Verification'.tr),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${"Account Email:".tr} ${user?.email ?? "Unknown".tr}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${"Status:".tr} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  isVerified ? 'Verified ✓'.tr : 'Unverified ⚠️'.tr,
                  style: TextStyle(
                    color: isVerified ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isVerified
                  ? 'Your email address is verified. You have full account access.'.tr
                  : 'Your email address is not verified yet. Click below to send a verification link to your email.'.tr,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'.tr)),
          if (!isVerified)
            ElevatedButton(
              onPressed: () async {
                try {
                  await _authService.sendEmailVerification();
                  if (context.mounted) {
                    Navigator.pop(context);
                    _showAppSnackBar(context, 
                      SnackBar(content: Text('${"Verification email sent to".tr} ${user?.email}! ${"Please check your inbox.".tr}')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showAppSnackBar(context, 
                      SnackBar(content: Text('$e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              },
              child: const Text('Send Verification Email'),
            ),
        ],
      ),
    );
  }

  void _showSelectLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Language'.tr),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: LanguageService.supportedLanguages.entries.map((entry) {
              final code = entry.key;
              final info = entry.value;
              final bool isSelected = LanguageService().currentLocale.value.languageCode == code;

              return ListTile(
                title: Text('${info['native']} (${info['name']})'),
                trailing: isSelected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
                onTap: () {
                  LanguageService().setLanguage(code);
                  Navigator.pop(context);
                  _showAppSnackBar(context, SnackBar(content: Text('${"Language changed to".tr} ${info['native']}')));
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close'.tr)),
        ],
      ),
    );
  }


}
