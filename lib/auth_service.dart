import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Sync user data to Firestore
  Future<void> syncUserData(User? user, {String? username}) async {
    if (user == null) return;

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
      try {
        await docRef.set({
          'uid': user.uid,
          'email': user.email,
          'username': finalUsername,
          'username_search': finalUsername.toLowerCase(),
          'lastActive': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print("Firestore: User data synced successfully for $finalUsername");
      } catch (e) {
        print("Firestore Error syncing user data: $e");
      }
    }
  }

  // Google Sign In
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      await syncUserData(result.user);
      return result.user;
    } catch (e) {
      print("Google Sign In Error: $e");
      return null;
    }
  }

  // Sign in with email and password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email, 
        password: password
      );
      await syncUserData(result.user);
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Sign up with email and password
  Future<User?> signUp(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email, 
        password: password
      );
      return result.user;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  // Send password reset email
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes (including profile updates)
  Stream<User?> get userStream => _auth.userChanges();

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
    
    // 1. Try case-insensitive searchable field
    var result = await _db
        .collection('users')
        .where('username_search', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();
    
    if (result.docs.isNotEmpty) {
      final data = result.docs.first.data();
      data['uid'] = result.docs.first.id; // Ensure UID is always present
      return data;
    }

    // 2. Try original username (case-sensitive)
    result = await _db
        .collection('users')
        .where('username', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final data = result.docs.first.data();
      data['uid'] = result.docs.first.id;
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
        return data;
      }
    }

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
    await _db.collection('match_requests').doc(requestId).update({
      'status': status,
    });
  }

  // Delete a match request
  Future<void> deleteMatchRequest(String requestId) async {
    try {
      await _db.collection('match_requests').doc(requestId).delete();
    } catch (e) {
      print("Error deleting request: $e");
    }
  }

  // Listen for requests sent TO the current user
  Stream<QuerySnapshot> get incomingMatchRequests {
    return _db
        .collection('match_requests')
        .where('toUid', isEqualTo: currentUser?.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
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
