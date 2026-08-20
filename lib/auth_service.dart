import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsignin;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsignin_all;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal()
      : _googleSignInWindows = (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows)
            ? gsignin_all.GoogleSignIn(
                params: const gsignin_all.GoogleSignInParams(
                  clientId: _webClientId,
                ),
              )
            : null;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  // Mobile/Web Google Sign In
  final gsignin.GoogleSignIn _googleSignIn = gsignin.GoogleSignIn(
    clientId: kIsWeb ? _webClientId : null,
  );

  // For Windows support - Replace with your "Web Client ID" from Firebase Console
  // 1. Go to Firebase Console > Authentication > Sign-in method > Google
  // 2. Expand "Web SDK configuration" and copy the "Web client ID"
  static const String _webClientId = '965668657122-c97pt6jvop87momdllc1a0r4int0g4vp.apps.googleusercontent.com';

  final gsignin_all.GoogleSignIn? _googleSignInWindows;
  String? _currentSessionId;
  bool _ignoreSessionCheck = false;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _currentSessionId = prefs.getString('currentSessionId');
    
    // If this is a fresh install or cache was cleared, generate a persistent ID for this device
    if (_currentSessionId == null) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await prefs.setString('currentSessionId', _currentSessionId!);
    }
    print("Session: Device ID initialized: $_currentSessionId");
  }

  // Clear session ID (only used for full logout)
  Future<void> resetSessionId() async {
    // Note: We no longer clear the local ID on simple sign-out 
    // to maintain device identity for the next login attempt.
  }

  // Sync user data to Firestore
  Future<void> syncUserData(User? user, {String? username, bool isLogin = false}) async {
    if (user == null) return;
    
    if (isLogin) _ignoreSessionCheck = true;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      String? finalUsername = username ?? user.displayName;
      
      // If name is missing from auth, try to get from existing DB entry
      if (finalUsername == null || finalUsername.isEmpty) {
        final doc = await docRef.get();
        if (doc.exists) {
          finalUsername = doc.data()?['username'];
        }
      }

      if (finalUsername != null && finalUsername.isNotEmpty) {
        final Map<String, dynamic> dataToSync = {
          'uid': user.uid,
          'email': user.email,
          'username': finalUsername,
          'username_search': finalUsername.toLowerCase(),
          'lastActive': FieldValue.serverTimestamp(),
        };

        // On every sync (including resume), we ensure the cloud knows our ID.
        // During an explicit login, we 'force' this ID to be the active one.
        if (_currentSessionId != null) {
          dataToSync['currentSessionId'] = _currentSessionId;
        }

        await docRef.set(dataToSync, SetOptions(merge: true));
        print("Firestore: Synced with session ID: $_currentSessionId");
      }
    } catch (e) {
      print("Firestore Error syncing user data: $e");
    } finally {
      if (isLogin) {
        // Give it a tiny bit of time for the stream to process the update 
        // before we re-enable the check
        await Future.delayed(const Duration(milliseconds: 500));
        _ignoreSessionCheck = false;
      }
    }
  }

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    _ignoreSessionCheck = true;
    try {
      if (_googleSignInWindows != null) {
        // Windows specific flow
        final credentials = await _googleSignInWindows.signIn();
        if (credentials == null) return null;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: credentials.accessToken,
          idToken: credentials.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(credential);
        await syncUserData(result.user, isLogin: true);
        return result.user;
      } else {
        // Mobile/Web flow
        final gsignin.GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final gsignin.GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(credential);
        await syncUserData(result.user, isLogin: true);
        return result.user;
      }
    } catch (e) {
      print("Google Sign In Error: $e");
      _ignoreSessionCheck = false;
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    _ignoreSessionCheck = true;
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      await syncUserData(result.user, isLogin: true);
      return result.user;
    } catch (e) {
      print(e.toString());
      _ignoreSessionCheck = false;
      return null;
    }
  }

  // Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    _ignoreSessionCheck = true;
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      // Note: syncUserData is usually called in signup.dart after this
      return result.user;
    } catch (e) {
      print(e.toString());
      _ignoreSessionCheck = false;
      return null;
    }
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    if (_googleSignInWindows != null) {
      await _googleSignInWindows.signOut();
    } else {
      await _googleSignIn.signOut();
    }
    await resetSessionId();
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes (including profile updates)
  Stream<User?> get userStream => _auth.userChanges();

  Stream<bool> get sessionValidStream {
    return _auth.userChanges().asyncExpand((user) {
      if (user == null) {
        return Stream.value(true);
      }
      
      return _db.collection('users').doc(user.uid).snapshots().map((doc) {
        if (!doc.exists) return true;
        
        // If we are currently in the middle of a login/sync, ignore mismatches
        if (_ignoreSessionCheck) {
          return true;
        }

        final cloudSessionId = doc.data()?['currentSessionId'];
        
        // If no session is set in the cloud yet, we consider it valid.
        if (cloudSessionId == null) return true;

        // Strict check: Cloud session MUST match our local persistent device ID.
        bool isValid = cloudSessionId == _currentSessionId;
        
        if (!isValid) {
          print("Session: Mismatch detected for ${user.displayName}. Local=$_currentSessionId, Cloud=$cloudSessionId");
        }
        return isValid;
      });
    });
  }

  // --- Friend Request Logic ---

  Stream<QuerySnapshot> get friendsStream {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    return _db.collection('users').doc(user.uid).collection('friends').snapshots();
  }

  Future<void> sendFriendRequest(String targetUid) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Check if already friends
    final friendDoc = await _db
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(targetUid)
        .get();
    
    if (friendDoc.exists) {
      throw 'You are already friends with this user.';
    }

    // 2. Check if I already sent a request to them
    final sentRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: user.uid)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (sentRequest.docs.isNotEmpty) {
      throw 'Friend request already sent.';
    }

    // 3. Check if they already sent a request to me
    final receivedRequest = await _db
        .collection('friend_requests')
        .where('fromUid', isEqualTo: targetUid)
        .where('toUid', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (receivedRequest.docs.isNotEmpty) {
      throw 'This user has already sent you a friend request. Check your notifications.';
    }

    await _db.collection('friend_requests').add({
      'fromUid': user.uid,
      'fromUsername': user.displayName ?? 'Unknown',
      'toUid': targetUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> get incomingFriendRequests {
    return _db
        .collection('friend_requests')
        .where('toUid', isEqualTo: currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptFriendRequest(String requestId, String fromUid, String fromUsername) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Add to current user's friends
    await _db.collection('users').doc(user.uid).collection('friends').doc(fromUid).set({
      'uid': fromUid,
      'username': fromUsername,
      'addedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add current user to sender's friends
    await _db.collection('users').doc(fromUid).collection('friends').doc(user.uid).set({
      'uid': user.uid,
      'username': user.displayName ?? 'Unknown',
      'addedAt': FieldValue.serverTimestamp(),
    });

    // 3. Delete the request
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> removeFriend(String targetUid) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Remove from current user's friends
    await _db
        .collection('users')
        .doc(user.uid)
        .collection('friends')
        .doc(targetUid)
        .delete();

    // 2. Remove current user from target's friends
    await _db
        .collection('users')
        .doc(targetUid)
        .collection('friends')
        .doc(user.uid)
        .delete();
  }

  // --- Club Logic ---

  Future<void> createClub(String name, String sport) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Check if user already owns or is in a club
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    if (data?['ownedClubId'] != null || data?['joinedClubId'] != null) {
      throw 'You are already part of an organization. You must leave it to create your own.';
    }

    final docRef = await _db.collection('clubs').add({
      'name': name,
      'sport': sport,
      'ownerUid': user.uid,
      'ownerName': user.displayName ?? 'Unknown',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add owner as the first member
    await docRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'username': user.displayName ?? 'Unknown',
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 3. Mark user as owner in their profile
    await _db.collection('users').doc(user.uid).update({
      'ownedClubId': docRef.id,
    });
  }

  Stream<QuerySnapshot> get myOwnedClubs {
    return _db
        .collection('clubs')
        .where('ownerUid', isEqualTo: currentUser?.uid)
        .snapshots();
  }

  Stream<DocumentSnapshot> get myJoinedClub {
    final user = currentUser;
    if (user == null) return const Stream.empty();
    
    // We listen to the user doc to see what club they joined
    return _db.collection('users').doc(user.uid).snapshots().asyncExpand((userSnap) {
      final joinedId = userSnap.data()?['joinedClubId'];
      if (joinedId == null) return Stream.value(userSnap); // Return dummy
      return _db.collection('clubs').doc(joinedId).snapshots();
    });
  }

  Future<void> removeMemberFromClub(String clubId, String userUid) async {
    // 1. Remove from club
    await _db.collection('clubs').doc(clubId).collection('members').doc(userUid).delete();
    
    // 2. Clear from user's record
    await _db.collection('users').doc(userUid).update({
      'joinedClubId': FieldValue.delete(),
    });
  }

  Future<void> leaveClub(String clubId) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Remove self from club members
    await _db.collection('clubs').doc(clubId).collection('members').doc(user.uid).delete();

    // 2. Clear joinedClubId from profile
    await _db.collection('users').doc(user.uid).update({
      'joinedClubId': FieldValue.delete(),
    });
  }

  Future<void> deleteClub(String clubId) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Get all members to clear their profiles
    final membersSnap = await _db.collection('clubs').doc(clubId).collection('members').get();
    
    final batch = _db.batch();
    
    for (var doc in membersSnap.docs) {
      final mUid = doc.id;
      // Clear joinedClubId for members
      if (doc.data()['role'] == 'member') {
        batch.update(_db.collection('users').doc(mUid), {
          'joinedClubId': FieldValue.delete(),
        });
      }
      // Delete member doc
      batch.delete(doc.reference);
    }

    // 2. Delete all pending requests for this club
    final requestsSnap = await _db
        .collection('club_requests')
        .where('clubId', isEqualTo: clubId)
        .get();
    for (var doc in requestsSnap.docs) {
      batch.delete(doc.reference);
    }

    // 3. Clear owner's profile
    batch.update(_db.collection('users').doc(user.uid), {
      'ownedClubId': FieldValue.delete(),
    });

    // 4. Delete the club doc
    batch.delete(_db.collection('clubs').doc(clubId));

    await batch.commit();
  }

  Stream<QuerySnapshot> getClubMembers(String clubId) {
    return _db.collection('clubs').doc(clubId).collection('members').snapshots();
  }

  // --- Tournament Logic ---

  Future<void> createTournament({
    required String clubId,
    required String name,
    required String sport,
    required bool needsPermission,
  }) async {
    final user = currentUser;
    if (user == null) return;

    // Check club ownership
    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (!clubDoc.exists || clubDoc.data()?['ownerUid'] != user.uid) {
      throw 'Only the club owner can create tournaments.';
    }

    // Check limit of 3 active tournaments
    final existing = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .where('status', isNotEqualTo: 'completed')
        .get();
    
    if (existing.docs.length >= 3) {
      throw 'Clubs are limited to 3 active tournaments at a time.';
    }

    await _db.collection('clubs').doc(clubId).collection('tournaments').add({
      'name': name,
      'sport': sport,
      'needsPermission': needsPermission,
      'status': 'upcoming',
      'ownerUid': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getClubTournaments(String clubId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .snapshots();
  }

  Future<void> deleteTournament(String clubId, String tournamentId) async {
    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .delete();
  }

  // Club Request Logic
  Future<void> sendClubJoinRequest(String clubId, String clubName, String targetUid, String targetUsername) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Check if target user is already in a club
    final targetDoc = await _db.collection('users').doc(targetUid).get();
    final targetData = targetDoc.data();
    if (targetData?['ownedClubId'] != null || targetData?['joinedClubId'] != null) {
      throw 'This user is already part of another organization.';
    }

    // 2. Check if already a member of THIS club (redundant but safe)
    final memberDoc = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(targetUid)
        .get();
    
    if (memberDoc.exists) {
      throw 'User is already a member of this club.';
    }

    // 3. Check if a request is already pending
    final existing = await _db
        .collection('club_requests')
        .where('clubId', isEqualTo: clubId)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();
    
    if (existing.docs.isNotEmpty) {
      throw 'Invitation already sent to this user.';
    }

    await _db.collection('club_requests').add({
      'clubId': clubId,
      'clubName': clubName,
      'fromUid': user.uid,
      'toUid': targetUid,
      'toUsername': targetUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getSentClubRequests(String clubId) {
    return _db
        .collection('club_requests')
        .where('clubId', isEqualTo: clubId)
        .snapshots();
  }

  Stream<QuerySnapshot> get incomingClubRequests {
    return _auth.userChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream.empty();
      }
      // Only show pending invitations to the recipient
      return _db
          .collection('club_requests')
          .where('toUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    });
  }

  Future<void> acceptClubRequest(String requestId, String clubId, String clubName) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Double check current user isn't in a club
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    if (userData?['ownedClubId'] != null || userData?['joinedClubId'] != null) {
      throw 'You cannot join a club while you are an owner or member of another one.';
    }

    // 2. Add user to club members
    await _db.collection('clubs').doc(clubId).collection('members').doc(user.uid).set({
      'uid': user.uid,
      'username': user.displayName ?? 'Unknown',
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 3. Update user record
    await _db.collection('users').doc(user.uid).update({
      'joinedClubId': clubId,
    });

    // 4. Update the request status
    await _db.collection('club_requests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  Future<void> declineClubRequest(String requestId) async {
    await _db.collection('club_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  Future<void> deleteClubRequest(String requestId) async {
    await _db.collection('club_requests').doc(requestId).delete();
  }

  // --- Match Request Logic ---

  // Check if a username is already taken (case-insensitive)
  Future<bool> isUsernameTaken(String username) async {
    final result = await _db
        .collection('users')
        .where('username_search', isEqualTo: username.trim().toLowerCase())
        .limit(1)
        .get();
    return result.docs.isNotEmpty;
  }

  // Search for a user by exact username (resilient search)
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) return null;
    
    print("Search: Looking for user '$trimmed'...");

    // 1. Try case-insensitive searchable field
    var result = await _db
        .collection('users')
        .where('username_search', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final data = result.docs.first.data();
      data['uid'] = result.docs.first.id; // Ensure UID is always present
      print("Search: Found by username_search: ${data['username']}");
      return data;
    }

    // 2. Try original username (case-sensitive) just in case index is lagging
    result = await _db
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final data = result.docs.first.data();
      data['uid'] = result.docs.first.id;
      print("Search: Found by case-sensitive username: ${data['username']}");
      return data;
    }

    // 3. Try email just in case
    if (trimmed.contains('@')) {
      result = await _db
          .collection('users')
          .where('email', isEqualTo: trimmed.toLowerCase())
          .limit(1)
          .get();
      if (result.docs.isNotEmpty) {
        final data = result.docs.first.data();
        data['uid'] = result.docs.first.id;
        print("Search: Found by email: ${data['email']}");
        return data;
      }
    }

    print("Search: No user found matching '$trimmed'");
    return null;
  }

  // Send a match request
  Future<String> sendMatchRequest({
    required String targetUid,
    required String sport,
    required bool isDoubles,
    required String p1Name,
    required String p2Name,
    required String p3Name,
    required String p4Name,
    int? setsToWin,
  }) async {
    final user = currentUser;
    if (user == null) return '';

    final docRef = await _db.collection('match_requests').add({
      'fromUid': user.uid,
      'fromUsername': user.displayName ?? 'Unknown',
      'toUid': targetUid,
      'sport': sport,
      'isDoubles': isDoubles,
      'p1Name': p1Name,
      'p2Name': p2Name,
      'p3Name': p3Name,
      'p4Name': p4Name,
      'setsToWin': setsToWin,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    print("Firestore: Match request sent to $targetUid (ID: ${docRef.id})");
    return docRef.id;
  }

  // Respond to a match request
  Future<void> respondToRequest(String requestId, String status) async {
    try {
      final docRef = _db.collection('match_requests').doc(requestId);
      final doc = await docRef.get();
      if (!doc.exists) {
        print("Firestore: Cannot respond to request $requestId, it no longer exists.");
        return;
      }
      await docRef.update({'status': status});
    } catch (e) {
      print("Firestore Error responding to request: $e");
    }
  }

  // Delete a match request
  Future<void> deleteMatchRequest(String requestId) async {
    try {
      await _db.collection('match_requests').doc(requestId).delete();
    } catch (e) {
      print("Firestore Error deleting request: $e");
    }
  }

  // Listen for requests sent TO the current user
  Stream<QuerySnapshot> get incomingMatchRequests {
    return _auth.userChanges().asyncExpand((user) {
      if (user == null) {
        return const Stream.empty();
      }
      // Useful for debugging Web connectivity
      if (kIsWeb) {
        print("Firestore: Initializing real-time listener for user: ${user.uid}");
      }
      return _db
          .collection('match_requests')
          .where('toUid', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots();
    });
  }

  // Listen for the status of a request sent BY the current user
  Stream<DocumentSnapshot> listenToRequest(String requestId) {
    return _db.collection('match_requests').doc(requestId).snapshots();
  }

  // Clean up all match requests sent by the current user
  Future<void> cleanupSentRequests() async {
    final user = currentUser;
    if (user == null) return;
    
    final result = await _db
        .collection('match_requests')
        .where('fromUid', isEqualTo: user.uid)
        .get();
    
    for (var doc in result.docs) {
      await doc.reference.delete();
    }
  }

  // Clean up any non-playing matches hosted by the user
  Future<void> cleanupOldHostedMatches() async {
    final user = currentUser;
    if (user == null) return;

    final result = await _db
        .collection('active_matches')
        .where('hostUid', isEqualTo: user.uid)
        .get();
    
    for (var doc in result.docs) {
      final status = doc.get('status');
      if (status != 'playing') {
        await doc.reference.delete();
      }
    }
  }

  // --- Active Match Tracking ---

  // Create an active match document
  Future<String> createActiveMatch({
    required String sport,
    required List<String> participantUids,
    required String hostUid,
    required Map<String, dynamic> initialData,
  }) async {
    final docRef = await _db.collection('active_matches').add({
      'sport': sport,
      'participantUids': participantUids,
      'hostUid': hostUid,
      'status': 'playing',
      'matchData': initialData,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Update match data (e.g., forfeit)
  Future<void> updateMatchStatus(String matchId, String status) async {
    await _db.collection('active_matches').doc(matchId).update({
      'status': status,
    });
  }

  // Permanently delete an active match document
  Future<void> deleteActiveMatch(String matchId) async {
    try {
      await _db.collection('active_matches').doc(matchId).delete();
    } catch (e) {
      print("Error deleting match: $e");
    }
  }

  // Check if user is in an active match
  Stream<QuerySnapshot> get myActiveMatches {
    return _db
        .collection('active_matches')
        .where('participantUids', arrayContains: currentUser?.uid)
        .where('status', isEqualTo: 'playing')
        .snapshots();
  }

  // Check if a specific user is currently in an active match or has a pending request
  Future<bool> isUserInMatch(String uid) async {
    // 1. Check if in an active "playing" match
    final activeMatch = await _db
        .collection('active_matches')
        .where('participantUids', arrayContains: uid)
        .where('status', isEqualTo: 'playing')
        .limit(1)
        .get();
    
    if (activeMatch.docs.isNotEmpty) return true;

    // 2. Check if they have a pending invitation they haven't answered yet
    final pendingRequest = await _db
        .collection('match_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    return pendingRequest.docs.isNotEmpty;
  }
}
