import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? uid;
  final String? username;
  final double radius;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.uid,
    this.username,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return _buildFromPhotoUrl(context, photoUrl!);
    }

    if (uid != null && uid!.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          String? fetchedUrl;
          String? fetchedName = username;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            fetchedUrl = data?['photoUrl'] as String?;
            fetchedName = (data?['username'] as String?) ?? username;
          }

          if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
            return _buildFromPhotoUrl(context, fetchedUrl);
          }

          return _buildFallback(context, fetchedName);
        },
      );
    }

    return _buildFallback(context, username);
  }

  Widget _buildFromPhotoUrl(BuildContext context, String url) {
    if (url.startsWith('data:image')) {
      try {
        final String base64Data = url.split(',').last;
        final Uint8List bytes = base64Decode(base64Data);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (e) {
        debugPrint("Error decoding base64 avatar: $e");
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(url),
      );
    } else {
      // Emoji or preset avatar string
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          url,
          style: TextStyle(fontSize: radius * 0.9),
        ),
      );
    }

    return _buildFallback(context, username);
  }

  Widget _buildFallback(BuildContext context, String? name) {
    if (name != null && name.trim().isNotEmpty) {
      final String initial = name.trim()[0].toUpperCase();
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          initial,
          style: TextStyle(
            fontSize: radius * 0.85,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      child: Icon(Icons.person, size: radius * 1.1),
    );
  }
}
