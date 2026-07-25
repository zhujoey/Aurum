import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sync user data to Firestore
  Future<void> syncUserData(User? user, {String? username}) async {
    if (user != null) {
      await _db.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'username': username ?? user.displayName ?? '',
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
    await _auth.signOut();
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes (including profile updates)
  Stream<User?> get userStream => _auth.userChanges();

  // --- Match Request Logic ---

  // Search for a user by exact username
  Future<Map<String, dynamic>?> findUserByUsername(String username) async {
    final result = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    
    if (result.docs.isNotEmpty) {
      return result.docs.first.data();
    }
    return null;
  }

  // Send a match request
  Future<String> sendMatchRequest({
    required String targetUid,
    required String sport,
    int? setsToWin,
  }) async {
    final user = currentUser;
    if (user == null) return '';

    final docRef = await _db.collection('match_requests').add({
      'fromUid': user.uid,
      'fromUsername': user.displayName ?? 'Unknown',
      'toUid': targetUid,
      'sport': sport,
      'setsToWin': setsToWin,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Respond to a match request
  Future<void> respondToRequest(String requestId, String status) async {
    await _db.collection('match_requests').doc(requestId).update({
      'status': status,
    });
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
}
