import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsignin;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart' as gsignin_all;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurum/language_service.dart';

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

  Future<void> init([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    _currentSessionId = p.getString('currentSessionId');
    
    // If this is a fresh install or cache was cleared, generate a persistent ID for this device
    if (_currentSessionId == null) {
      _currentSessionId = DateTime.now().millisecondsSinceEpoch.toString();
      await p.setString('currentSessionId', _currentSessionId!);
    }
    debugPrint("Session: Device ID initialized: $_currentSessionId");
  }

  // Clear session ID (only used for full logout)
  Future<void> resetSessionId() async {
    // Note: We no longer clear the local ID on simple sign-out 
    // to maintain device identity for the next login attempt.
  }

  // Sync user data to Firestore
  Future<void> syncUserData(User? user, {String? username, String? gender, bool isLogin = false}) async {
    if (user == null) return;
    
    if (isLogin) _ignoreSessionCheck = true;

    try {
      final docRef = _db.collection('users').doc(user.uid);
      String? finalUsername = username ?? user.displayName;
      
      // Try cache first for instant response, falling back to server if cache misses
      DocumentSnapshot? doc;
      try {
        doc = await docRef.get(const GetOptions(source: Source.cache));
      } catch (_) {
        doc = await docRef.get();
      }

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (finalUsername == null || finalUsername.isEmpty) {
          finalUsername = data?['username'];
        }
        final String? savedLang = data?['selectedLanguage'] as String?;
        if (savedLang != null && savedLang.isNotEmpty) {
          LanguageService().setLanguage(savedLang, updateFirestore: false);
        }
      }

      if (finalUsername != null && finalUsername.isNotEmpty) {
        final Map<String, dynamic> dataToSync = {
          'uid': user.uid,
          'email': user.email,
          'username': finalUsername,
          'username_search': finalUsername.toLowerCase(),
          if (gender != null) 'gender': gender,
          'lastActive': FieldValue.serverTimestamp(),
        };

        // On every sync (including resume), we ensure the cloud knows our ID.
        // During an explicit login, we 'force' this ID to be the active one.
        if (_currentSessionId != null) {
          dataToSync['currentSessionId'] = _currentSessionId;
        }

        await docRef.set(dataToSync, SetOptions(merge: true));
        debugPrint("Firestore: Synced with session ID: $_currentSessionId");
      }
    } catch (e) {
      debugPrint("Firestore Error syncing user data: $e");
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
      debugPrint("Google Sign In Error: $e");
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
      debugPrint(e.toString());
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
      debugPrint(e.toString());
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

  // Send email verification to current user
  Future<void> sendEmailVerification() async {
    final user = currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Reload current user profile to refresh emailVerified status
  Future<void> reloadUser() async {
    final user = currentUser;
    if (user != null) {
      await user.reload();
    }
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
          debugPrint("Session: Mismatch detected for ${user.displayName}. Local=$_currentSessionId, Cloud=$cloudSessionId");
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

    // Parallelize all checks
    final results = await Future.wait([
      _db.collection('users').doc(user.uid).collection('friends').doc(targetUid).get(),
      _db.collection('friend_requests').where('fromUid', isEqualTo: user.uid).where('toUid', isEqualTo: targetUid).where('status', isEqualTo: 'pending').get(),
      _db.collection('friend_requests').where('fromUid', isEqualTo: targetUid).where('toUid', isEqualTo: user.uid).where('status', isEqualTo: 'pending').get(),
    ]);

    final friendDoc = results[0] as DocumentSnapshot;
    final sentRequest = results[1] as QuerySnapshot;
    final receivedRequest = results[2] as QuerySnapshot;

    if (friendDoc.exists) throw 'You are already friends with this user.';
    if (sentRequest.docs.isNotEmpty) throw 'Friend request already sent.';
    if (receivedRequest.docs.isNotEmpty) throw 'This user has already sent you a friend request. Check your notifications.';

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

    final batch = _db.batch();
    batch.set(_db.collection('users').doc(user.uid).collection('friends').doc(fromUid), {
      'uid': fromUid,
      'username': fromUsername,
      'addedAt': FieldValue.serverTimestamp(),
    });
    batch.set(_db.collection('users').doc(fromUid).collection('friends').doc(user.uid), {
      'uid': user.uid,
      'username': user.displayName ?? 'Unknown',
      'addedAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_db.collection('friend_requests').doc(requestId));
    await batch.commit();
  }

  Future<void> declineFriendRequest(String requestId) async {
    await _db.collection('friend_requests').doc(requestId).delete();
  }

  Future<void> removeFriend(String targetUid) async {
    final user = currentUser;
    if (user == null) return;

    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(user.uid).collection('friends').doc(targetUid));
    batch.delete(_db.collection('users').doc(targetUid).collection('friends').doc(user.uid));
    await batch.commit();
  }

  // --- Club Logic ---

  Future<void> createClub(String name, String sport) async {
    final user = currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final data = userDoc.data();
    if (data?['ownedClubId'] != null) {
      throw 'You already own a club. You can only create 1 club, but you can join as many clubs as you wish.';
    }

    String username = user.displayName ?? '';
    if (username.isEmpty) {
      username = data?['username'] ?? 'Unknown';
    }

    // 2. Check if a club with the same name already exists system-wide (case-insensitive)
    final existingClubs = await _db.collection('clubs').get();
    for (var clubDoc in existingClubs.docs) {
      final String clubName = (clubDoc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (clubName == name.trim().toLowerCase()) {
        throw 'A club named "$name" already exists. Please choose a unique club name.';
      }
    }

    final docRef = await _db.collection('clubs').add({
      'name': name,
      'sport': sport,
      'ownerUid': user.uid,
      'ownerName': username,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Add owner as the first member
    await docRef.collection('members').doc(user.uid).set({
      'uid': user.uid,
      'username': username,
      'role': 'owner',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 3. Mark user as owner in their profile (using merge: true to prevent NOT_FOUND if doc is missing)
    await userRef.set({
      'ownedClubId': docRef.id,
      'uid': user.uid,
      'email': user.email ?? '',
      'username': username,
    }, SetOptions(merge: true));
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
    final batch = _db.batch();
    batch.delete(_db.collection('clubs').doc(clubId).collection('members').doc(userUid));
    if (userUid.startsWith('member_')) {
      batch.delete(_db.collection('users').doc(userUid));
    } else {
      batch.update(_db.collection('users').doc(userUid), {
        'joinedClubId': FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  Future<void> leaveClub(String clubId) async {
    final user = currentUser;
    if (user == null) return;

    final batch = _db.batch();
    batch.delete(_db.collection('clubs').doc(clubId).collection('members').doc(user.uid));
    if (user.uid.startsWith('member_')) {
      batch.delete(_db.collection('users').doc(user.uid));
    } else {
      batch.update(_db.collection('users').doc(user.uid), {
        'joinedClubId': FieldValue.delete(),
      });
    }
    await batch.commit();
  }

  Future<void> deleteClub(String clubId) async {
    final user = currentUser;
    if (user == null) return;

    // 1. Get all members to clear their profiles
    final membersSnap = await _db.collection('clubs').doc(clubId).collection('members').get();
    
    final batch = _db.batch();
    
    for (var doc in membersSnap.docs) {
      final mUid = doc.id;
      // Delete user doc if local club registered member, otherwise clear joinedClubId for real members
      if (mUid.startsWith('member_')) {
        batch.delete(_db.collection('users').doc(mUid));
      } else if (doc.data()['role'] == 'member') {
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

  Future<void> addRealMemberToClub({
    required String clubId,
    required String name,
    required String gender,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (!clubDoc.exists) throw 'Club not found.';

    final String clubName = clubDoc.data()?['name'] ?? 'Club';
    final String cleanName = name.trim();
    if (cleanName.isEmpty) throw 'Member name cannot be empty.';

    final String newUid = 'member_${clubId}_${DateTime.now().millisecondsSinceEpoch}';

    final batch = _db.batch();

    // 1. Create real user profile document in 'users' collection (isBot: false)
    final userRef = _db.collection('users').doc(newUid);
    batch.set(userRef, {
      'username': cleanName,
      'displayName': cleanName,
      'gender': gender,
      'isBot': false,
      'joinedClubId': clubId,
      'joinedClubName': clubName,
      'points_open_singles': 0,
      'elo_open_singles': 800,
      'glicko_open_singles': 800,
      'wins': 0,
      'losses': 0,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Add as a real member in club's members subcollection
    final memberRef = _db.collection('clubs').doc(clubId).collection('members').doc(newUid);
    batch.set(memberRef, {
      'uid': newUid,
      'username': cleanName,
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> createTournament({
    required String clubId,
    required String name,
    String description = '',
    required String sport,
    bool isOpen = false,
    int rankingPoints = 1000,
    String tournamentStyle = 'Single Elimination',
    String seedingMethod = 'ITTF Seeded',
    bool hasThirdPlacePlayoff = false,
    String singlesType = 'everyone',
    String doublesType = 'none',
    String teamType = 'none',
    String teamMatchSystem = 'Olympic System (1 Doubles + 4 Singles)',
    String pointsExpiration = '1_year',
    bool keepRunningTimers = true,
    Map<String, dynamic>? pointsBreakdown,
  }) async {
    final user = currentUser;
    if (user == null) return;

    // Check club ownership
    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (!clubDoc.exists || clubDoc.data()?['ownerUid'] != user.uid) {
      throw 'Only the club owner can create tournaments.';
    }

    // Check limit of 7 tournaments
    final existing = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .get();
    
    if (existing.docs.length >= 7) {
      throw 'Clubs are limited to 7 tournaments at a time.';
    }

    // Check for duplicate tournament name in this club
    for (var tDoc in existing.docs) {
      final String tName = (tDoc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (tName == name.trim().toLowerCase()) {
        throw 'A tournament named "$name" already exists in this club. Please choose a unique name.';
      }
    }

    final bool resolvedOpenDoubles = doublesType == 'open';
    final bool resolvedGenderDoubles = doublesType == 'gendered' || doublesType == 'all';
    final bool resolvedMixedDoubles = doublesType == 'mixed_only' || doublesType == 'all';

    final breakdown = pointsBreakdown ?? {
      'winner': rankingPoints,
      'finalist': (rankingPoints * 0.7).round(),
      'semifinalist': (rankingPoints * 0.35).round(),
      'quarterfinalist': (rankingPoints * 0.175).round(),
      'roundOf16': (rankingPoints * 0.0875).round(),
    };

    await _db.collection('clubs').doc(clubId).collection('tournaments').add({
      'name': name,
      'description': description,
      'sport': sport,
      'isOpen': isOpen,
      'needsPermission': !isOpen,
      'rankingPoints': rankingPoints,
      'tournamentStyle': tournamentStyle,
      'seedingMethod': seedingMethod,
      'hasThirdPlacePlayoff': hasThirdPlacePlayoff,
      'singlesType': singlesType,
      'doublesType': doublesType,
      'teamType': teamType,
      'teamMatchSystem': teamMatchSystem,
      'pointsExpiration': pointsExpiration,
      'keepRunningTimers': keepRunningTimers,
      'pointsBreakdown': breakdown,
      'hasMixedDoubles': resolvedMixedDoubles,
      'hasGenderDoubles': resolvedGenderDoubles,
      'hasOpenDoubles': resolvedOpenDoubles,
      'isStarted': false,
      'ownerUid': user.uid,
      'participants': [],
      'participantUids': [],
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

  Stream<DocumentSnapshot> getTournamentStream(String clubId, String tournamentId) {
    return _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .snapshots();
  }

  // Update tournament settings
  Future<void> updateTournamentSettings({
    required String clubId,
    required String tournamentId,
    required String name,
    required String description,
    required bool isOpen,
    required int rankingPoints,
    required String tournamentStyle,
    required String seedingMethod,
    required bool hasThirdPlacePlayoff,
    required String singlesType,
    required String doublesType,
    String teamType = 'none',
    String teamMatchSystem = 'Olympic System (1 Doubles + 4 Singles)',
    String pointsExpiration = '1_year',
    bool keepRunningTimers = true,
    Map<String, dynamic>? pointsBreakdown,
  }) async {
    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    // Check if another tournament in this club already has this name
    final existingTours = await _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .get();

    for (var tDoc in existingTours.docs) {
      if (tDoc.id != tournamentId) {
        final String tName = (tDoc.data()['name'] as String? ?? '').trim().toLowerCase();
        if (tName == name.trim().toLowerCase()) {
          throw 'Another tournament named "$name" already exists in this club. Please choose a unique name.';
        }
      }
    }

    final bool resolvedOpenDoubles = doublesType == 'open';
    final bool resolvedGenderDoubles = doublesType == 'gendered' || doublesType == 'all';
    final bool resolvedMixedDoubles = doublesType == 'mixed_only' || doublesType == 'all';

    final breakdown = pointsBreakdown ?? {
      'winner': rankingPoints,
      'finalist': (rankingPoints * 0.7).round(),
      'semifinalist': (rankingPoints * 0.35).round(),
      'quarterfinalist': (rankingPoints * 0.175).round(),
      'roundOf16': (rankingPoints * 0.0875).round(),
    };

    await docRef.update({
      'name': name,
      'description': description,
      'isOpen': isOpen,
      'needsPermission': !isOpen,
      'rankingPoints': rankingPoints,
      'tournamentStyle': tournamentStyle,
      'seedingMethod': seedingMethod,
      'hasThirdPlacePlayoff': hasThirdPlacePlayoff,
      'singlesType': singlesType,
      'doublesType': doublesType,
      'teamType': teamType,
      'teamMatchSystem': teamMatchSystem,
      'pointsExpiration': pointsExpiration,
      'keepRunningTimers': keepRunningTimers,
      'pointsBreakdown': breakdown,
      'hasMixedDoubles': resolvedMixedDoubles,
      'hasGenderDoubles': resolvedGenderDoubles,
      'hasOpenDoubles': resolvedOpenDoubles,
    });
  }

  Future<void> startTournament({
    required String clubId,
    required String tournamentId,
    required String seedingMethod,
    required bool hasThirdPlacePlayoff,
  }) async {
    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await docRef.get();
    if (!doc.exists) throw 'Tournament not found.';

    final data = doc.data() as Map<String, dynamic>;
    List participants = List.from(data['participants'] ?? []);
    if (participants.length < 2) {
      throw 'At least 2 participants are required to start a tournament.';
    }

    if (seedingMethod == 'Random') {
      participants.shuffle();
    }

    // Calculate ITTF Bracket Size M (next power of 2)
    int m = 2;
    while (m < participants.length) {
      m *= 2;
    }
    final int numByes = m - participants.length;

    // Calculate total rounds (log2(M))
    int totalRounds = 0;
    int tempM = m;
    while (tempM > 1) {
      tempM ~/= 2;
      totalRounds++;
    }

    // Filter out incomplete teams/pairs before starting bracket
    final doublesSnap = await docRef.collection('doubles_requests').get();
    for (var dDoc in doublesSnap.docs) {
      final dData = dDoc.data();
      final String status = dData['status'] ?? 'pending';
      final String eventType = dData['eventType'] ?? '';

      if (status != 'accepted') {
        int requiredMembers = 2;
        if (eventType == 'mixed_team') {
          requiredMembers = 8;
        } else if (eventType.endsWith('_team')) {
          requiredMembers = 5;
        }

        final List acceptedUids = List.from(dData['acceptedUids'] ?? []);
        if (acceptedUids.length < requiredMembers) {
          await dDoc.reference.delete();
        }
      }
    }

    final batch = _db.batch();

    batch.update(docRef, {
      'isStarted': true,
      'seedingMethod': seedingMethod,
      'hasThirdPlacePlayoff': hasThirdPlacePlayoff,
      'participants': participants,
      'bracketSize': m,
      'totalRounds': totalRounds,
      'startedAt': FieldValue.serverTimestamp(),
    });

    // Generate Round 1 Match Documents & Auto-Advance BYEs
    for (int i = 0; i < m / 2; i++) {
      Map<String, dynamic> p1;
      Map<String, dynamic> p2;

      if (i < numByes) {
        // Top seeds get BYE
        p1 = Map<String, dynamic>.from(participants[i]);
        p2 = {'username': 'BYE', 'uid': ''};
      } else {
        final int realIdx1 = numByes + (i - numByes) * 2;
        final int realIdx2 = realIdx1 + 1;
        p1 = realIdx1 < participants.length ? Map<String, dynamic>.from(participants[realIdx1]) : {'username': 'BYE', 'uid': ''};
        p2 = realIdx2 < participants.length ? Map<String, dynamic>.from(participants[realIdx2]) : {'username': 'BYE', 'uid': ''};
      }

      final int matchNum = i + 1;
      final String matchId = 'match_r1_m$matchNum';
      final bool isByeMatch = p2['username'] == 'BYE';
      final matchRef = docRef.collection('matches').doc(matchId);

      batch.set(matchRef, {
        'roundNum': 1,
        'matchNum': matchNum,
        'p1Uid': p1['uid'] ?? '',
        'p1Name': p1['username'] ?? 'TBD',
        'p2Uid': p2['uid'] ?? '',
        'p2Name': p2['username'] ?? 'BYE',
        'status': isByeMatch ? 'completed' : 'scheduled',
        'winnerUid': isByeMatch ? p1['uid'] : '',
        'winnerName': isByeMatch ? p1['username'] : '',
        'scoreText': isByeMatch ? 'BYE' : '',
      });

      // If BYE match, auto-advance winner to Round 2!
      if (isByeMatch) {
        final int nextMatchNum = (matchNum + 1) ~/ 2;
        final String nextMatchId = 'match_r2_m$nextMatchNum';
        final bool isP1 = matchNum % 2 != 0;
        final nextRef = docRef.collection('matches').doc(nextMatchId);

        if (isP1) {
          batch.set(nextRef, {
            'roundNum': 2,
            'matchNum': nextMatchNum,
            'p1Uid': p1['uid'],
            'p1Name': p1['username'],
            'status': 'scheduled',
          }, SetOptions(merge: true));
        } else {
          batch.set(nextRef, {
            'roundNum': 2,
            'matchNum': nextMatchNum,
            'p2Uid': p1['uid'],
            'p2Name': p1['username'],
            'status': 'scheduled',
          }, SetOptions(merge: true));
        }
      }
    }

    await batch.commit();
  }

  Future<void> joinTournament({
    required String clubId,
    required String tournamentId,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    final String clubOwnerUid = clubDoc.data()?['ownerUid'] ?? '';

    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await docRef.get();
    if (!doc.exists) throw 'Tournament not found.';

    final data = doc.data() as Map<String, dynamic>;
    final bool isOpen = data['isOpen'] ?? false;
    final String tournamentOwnerUid = data['ownerUid'] ?? '';

    // Check if current user is club owner, tournament owner, or manager
    bool isOwnerOrManager = (user.uid == clubOwnerUid || user.uid == tournamentOwnerUid);
    if (!isOwnerOrManager) {
      final memberDoc = await _db
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .doc(user.uid)
          .get();
      final role = memberDoc.data()?['role'] ?? 'member';
      isOwnerOrManager = role == 'owner' || role == 'manager';
    }

    if (!isOpen && !isOwnerOrManager) {
      throw 'This tournament is closed. An owner or manager must invite you.';
    }

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data();
    final String gender = userData?['gender'] ?? 'Not set';
    if (gender == 'Not set') {
      throw 'Please set your gender in Settings before joining tournaments.';
    }

    final String username = user.displayName ?? 'Member';
    final participantEntry = {
      'uid': user.uid,
      'username': username,
      'joinedAt': DateTime.now().toIso8601String(),
    };

    await docRef.update({
      'participants': FieldValue.arrayUnion([participantEntry]),
      'participantUids': FieldValue.arrayUnion([user.uid]),
    });
  }

  Future<void> leaveTournament({
    required String clubId,
    required String tournamentId,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final List participants = List.from(data['participants'] ?? []);
    final matchingEntry = participants.firstWhere(
      (p) => (p as Map)['uid'] == user.uid,
      orElse: () => null,
    );

    if (matchingEntry != null) {
      await docRef.update({
        'participants': FieldValue.arrayRemove([matchingEntry]),
        'participantUids': FieldValue.arrayRemove([user.uid]),
      });

      // Clean up tournament requests
      final reqs = await _db
          .collection('tournament_requests')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('toUid', isEqualTo: user.uid)
          .get();
      for (var req in reqs.docs) {
        await req.reference.delete();
      }
    }
  }

  Future<void> removeParticipantFromTournament({
    required String clubId,
    required String tournamentId,
    required String targetUid,
  }) async {
    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final List participants = List.from(data['participants'] ?? []);
    final matchingEntry = participants.firstWhere(
      (p) => (p as Map)['uid'] == targetUid,
      orElse: () => null,
    );

    if (matchingEntry != null) {
      final batch = _db.batch();
      batch.update(docRef, {
        'participants': FieldValue.arrayRemove([matchingEntry]),
        'participantUids': FieldValue.arrayRemove([targetUid]),
      });

      // If target is a test bot player, delete their entire user profile and rankings
      final bool isBot = targetUid.contains('test_bot') || ((matchingEntry as Map)['isBot'] == true);
      if (isBot) {
        batch.delete(_db.collection('users').doc(targetUid));
      }

      await batch.commit();

      // Clean up tournament requests
      final reqs = await _db
          .collection('tournament_requests')
          .where('tournamentId', isEqualTo: tournamentId)
          .where('toUid', isEqualTo: targetUid)
          .get();
      for (var req in reqs.docs) {
        await req.reference.delete();
      }
    }
  }

  Future<void> deleteAllTestUsers() async {
    try {
      final botUsersSnap = await _db
          .collection('users')
          .where('isBot', isEqualTo: true)
          .get();

      final batch = _db.batch();

      for (var doc in botUsersSnap.docs) {
        batch.delete(doc.reference);
      }

      // Clean up test_bot users that might not have isBot flag set
      final allUsers = await _db.collection('users').get();
      for (var userDoc in allUsers.docs) {
        if (userDoc.id.contains('test_bot')) {
          batch.delete(userDoc.reference);
        }
      }

      final clubsSnap = await _db.collection('clubs').get();
      for (var clubDoc in clubsSnap.docs) {
        final toursSnap = await _db.collection('clubs').doc(clubDoc.id).collection('tournaments').get();
        for (var tourDoc in toursSnap.docs) {
          final data = tourDoc.data();
          final List participants = List.from(data['participants'] ?? []);
          final List participantUids = List.from(data['participantUids'] ?? []);

          List filteredParticipants = participants.where((p) {
            final uid = (p as Map)['uid'] as String? ?? '';
            return !uid.contains('test_bot') && (p['isBot'] != true);
          }).toList();

          List filteredUids = participantUids.where((u) {
            final uid = u as String;
            return !uid.contains('test_bot');
          }).toList();

          if (filteredParticipants.length != participants.length || filteredUids.length != participantUids.length) {
            batch.update(tourDoc.reference, {
              'participants': filteredParticipants,
              'participantUids': filteredUids,
            });
          }
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error purging test users: $e");
    }
  }

  Future<void> addTestParticipantsToTournament({
    required String clubId,
    required String tournamentId,
    int count = 7,
  }) async {
    final tourRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await tourRef.get();
    if (!doc.exists) throw 'Tournament not found.';

    final data = doc.data() as Map<String, dynamic>;
    final List participants = List.from(data['participants'] ?? []);
    final List participantUids = List.from(data['participantUids'] ?? []);

    final String singlesType = data['singlesType'] ?? 'everyone';
    final String tourName = data['name'] ?? 'Tournament';
    final batch = _db.batch();

    for (int i = 1; i <= count; i++) {
      final String botUid = 'test_bot_${tournamentId}_$i';
      final String gender = (singlesType == 'separate_gender' && i % 2 == 0) ? 'Female' : 'Male';
      final String botName = 'Test Player $i (${gender[0]}) • $tourName';

      if (!participantUids.contains(botUid)) {
        participantUids.add(botUid);
        participants.add({
          'uid': botUid,
          'username': botName,
          'gender': gender,
          'isBot': true,
          'joinedAt': DateTime.now().toIso8601String(),
        });

        // Ensure test user document exists in 'users' collection so gender & ratings work
        final userDocRef = _db.collection('users').doc(botUid);
        batch.set(userDocRef, {
          'username': botName,
          'displayName': botName,
          'gender': gender,
          'isBot': true,
          'points_open_singles': 0,
          'elo_open_singles': 800,
          'glicko_open_singles': 800,
          'wins': 0,
          'losses': 0,
        }, SetOptions(merge: true));
      }
    }

    batch.update(tourRef, {
      'participants': participants,
      'participantUids': participantUids,
    });

    await batch.commit();
  }

  Future<void> deleteTournament(String clubId, String tournamentId) async {
    final tourRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final batch = _db.batch();

    // 1. Delete all test user profiles belonging to this tournament from 'users'
    final botUsersSnap = await _db.collection('users').get();
    for (var uDoc in botUsersSnap.docs) {
      if (uDoc.id.startsWith('test_bot_${tournamentId}_')) {
        batch.delete(uDoc.reference);
      }
    }

    // 2. Clean up matches subcollection
    final matches = await tourRef.collection('matches').get();
    for (var doc in matches.docs) {
      batch.delete(doc.reference);
    }

    // 3. Clean up doubles_requests subcollection
    final doublesReqs = await tourRef.collection('doubles_requests').get();
    for (var doc in doublesReqs.docs) {
      batch.delete(doc.reference);
    }

    // 4. Clean up pending invitations in tournament_requests
    final pendingInvites = await _db
        .collection('tournament_requests')
        .where('tournamentId', isEqualTo: tournamentId)
        .get();
    for (var doc in pendingInvites.docs) {
      batch.delete(doc.reference);
    }

    // 5. Delete tournament document
    batch.delete(tourRef);

    await batch.commit();
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
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('club_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
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

  // --- Tournament Request Logic ---

  Future<void> inviteMemberToTournament({
    required String clubId,
    required String tournamentId,
    required String tournamentName,
    required String targetUid,
    required String targetUsername,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final doc = await docRef.get();
    if (!doc.exists) throw 'Tournament not found.';

    final data = doc.data() as Map<String, dynamic>;
    final List participantUids = List.from(data['participantUids'] ?? []);
    if (participantUids.contains(targetUid)) {
      throw 'This member is already in the tournament.';
    }

    // Auto-add club registered local members (member_...) directly!
    if (targetUid.startsWith('member_')) {
      await docRef.update({
        'participantUids': FieldValue.arrayUnion([targetUid]),
        'participants': FieldValue.arrayUnion([
          {
            'uid': targetUid,
            'username': targetUsername,
            'joinedAt': DateTime.now().toIso8601String(),
          }
        ]),
      });
      return;
    }

    // Check if invitation already pending
    final existing = await _db
        .collection('tournament_requests')
        .where('tournamentId', isEqualTo: tournamentId)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) {
      throw 'Invitation already sent to this user for this tournament.';
    }

    await _db.collection('tournament_requests').add({
      'clubId': clubId,
      'tournamentId': tournamentId,
      'tournamentName': tournamentName,
      'fromUid': user.uid,
      'toUid': targetUid,
      'toUsername': targetUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> get incomingTournamentRequests {
    final uid = currentUser?.uid;
    if (uid == null) return const Stream.empty();
    return _db
        .collection('tournament_requests')
        .where('toUid', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  Future<void> acceptTournamentRequest(String requestId, String clubId, String tournamentId) async {
    final user = currentUser;
    if (user == null) return;

    final tournamentRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final tourDoc = await tournamentRef.get();
    if (!tourDoc.exists) throw 'Tournament no longer exists.';

    final tourData = tourDoc.data() as Map<String, dynamic>;
    final List participantUids = List.from(tourData['participantUids'] ?? []);

    if (!participantUids.contains(user.uid)) {
      final participantEntry = {
        'uid': user.uid,
        'username': user.displayName ?? 'Member',
        'joinedAt': DateTime.now().toIso8601String(),
      };

      await tournamentRef.update({
        'participants': FieldValue.arrayUnion([participantEntry]),
        'participantUids': FieldValue.arrayUnion([user.uid]),
      });
    }

    await _db.collection('tournament_requests').doc(requestId).update({
      'status': 'accepted',
    });
  }

  Future<void> declineTournamentRequest(String requestId) async {
    await _db.collection('tournament_requests').doc(requestId).update({
      'status': 'declined',
    });
  }

  Future<void> retractTournamentInvitation({
    required String tournamentId,
    required String targetUid,
  }) async {
    final reqs = await _db
        .collection('tournament_requests')
        .where('tournamentId', isEqualTo: tournamentId)
        .where('toUid', isEqualTo: targetUid)
        .where('status', isEqualTo: 'pending')
        .get();

    for (var doc in reqs.docs) {
      await doc.reference.delete();
    }
  }

  Future<void> deleteTournamentRequest(String requestId) async {
    await _db.collection('tournament_requests').doc(requestId).delete();
  }

  // --- Doubles Partner Request Logic ---

  Future<void> requestDoublesPartner({
    required String clubId,
    required String tournamentId,
    required String eventType, // 'mixed', 'mens_doubles', 'womens_doubles'
    required String partnerUid,
    required String partnerUsername,
  }) async {
    final user = currentUser;
    if (user == null) return;
    if (user.uid == partnerUid) throw 'You cannot partner with yourself.';

    // Fetch user and partner gender
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final partnerDoc = await _db.collection('users').doc(partnerUid).get();

    final userGender = userDoc.data()?['gender'] ?? 'Not set';
    final partnerGender = partnerDoc.data()?['gender'] ?? 'Not set';

    if (userGender == 'Not set' || partnerGender == 'Not set') {
      throw 'Both players must have their gender set in Settings before pairing in doubles.';
    }

    if (eventType == 'mixed') {
      if (userGender == partnerGender) {
        throw 'Mixed Doubles requires one Male and one Female partner.';
      }
    } else if (eventType == 'mens_doubles') {
      if (userGender != 'Male' || partnerGender != 'Male') {
        throw "Men's Doubles requires both partners to be Male.";
      }
    } else if (eventType == 'womens_doubles') {
      if (userGender != 'Female' || partnerGender != 'Female') {
        throw "Women's Doubles requires both partners to be Female.";
      }
    } else if (eventType == 'open_doubles') {
      // Gender does not matter for open doubles
    }

    final tourRef = _db.collection('clubs').doc(clubId).collection('tournaments').doc(tournamentId);

    final existing = await tourRef.collection('doubles_requests')
        .where('eventType', isEqualTo: eventType)
        .where('status', whereIn: ['pending', 'accepted'])
        .get();

    for (var doc in existing.docs) {
      final data = doc.data();
      if (data['fromUid'] == user.uid || data['toUid'] == user.uid ||
          data['fromUid'] == partnerUid || data['toUid'] == partnerUid) {
        throw 'You or your requested partner are already in a pair or have a pending request for this event.';
      }
    }

    await tourRef.collection('doubles_requests').add({
      'eventType': eventType,
      'fromUid': user.uid,
      'fromUsername': user.displayName ?? 'Player',
      'toUid': partnerUid,
      'toUsername': partnerUsername,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptDoublesPartner({
    required String clubId,
    required String tournamentId,
    required String requestId,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final tourRef = _db.collection('clubs').doc(clubId).collection('tournaments').doc(tournamentId);
    final reqRef = tourRef.collection('doubles_requests').doc(requestId);
    final reqDoc = await reqRef.get();
    if (!reqDoc.exists) throw 'Request not found.';

    final reqData = reqDoc.data() as Map<String, dynamic>;
    final eventType = reqData['eventType'] ?? 'doubles';
    final List teamRoster = List.from(reqData['teamRoster'] ?? []);

    if (teamRoster.isNotEmpty) {
      final List acceptedUids = List.from(reqData['acceptedUids'] ?? []);
      if (!acceptedUids.contains(user.uid)) {
        acceptedUids.add(user.uid);
      }

      bool isFullyAccepted = acceptedUids.length >= teamRoster.length;

      if (isFullyAccepted) {
        await reqRef.update({
          'status': 'accepted',
          'acceptedUids': acceptedUids,
        });
      } else {
        await reqRef.update({
          'acceptedUids': acceptedUids,
        });
      }
      return;
    }

    final fromUid = reqData['fromUid'];
    final toUid = reqData['toUid'];

    final accepted = await tourRef.collection('doubles_requests')
        .where('eventType', isEqualTo: eventType)
        .where('status', isEqualTo: 'accepted')
        .get();

    for (var doc in accepted.docs) {
      final data = doc.data();
      if (data['fromUid'] == fromUid || data['toUid'] == fromUid ||
          data['fromUid'] == toUid || data['toUid'] == toUid) {
        throw 'One of the participants is already in a confirmed doubles pair for this event.';
      }
    }

    await reqRef.update({'status': 'accepted'});
  }

  Future<void> createDirectDoublesPair({
    required String clubId,
    required String tournamentId,
    required String p1Uid,
    required String p1Username,
    required String p2Uid,
    required String p2Username,
    required String eventType,
  }) async {
    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('doubles_requests')
        .doc();

    final batch = _db.batch();

    batch.set(docRef, {
      'fromUid': p1Uid,
      'fromUsername': p1Username,
      'toUid': p2Uid,
      'toUsername': p2Username,
      'status': 'accepted',
      'eventType': eventType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final pairRef = _db.collection('doubles_pairs').doc(docRef.id);
    batch.set(pairRef, {
      'clubId': clubId,
      'tournamentId': tournamentId,
      'eventType': eventType,
      'p1Uid': p1Uid,
      'p1Name': p1Username,
      'p2Uid': p2Uid,
      'p2Name': p2Username,
      'points': 0,
      'elo': 800,
      'glicko': 800,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Future<void> createTeamRoster({
    required String clubId,
    required String tournamentId,
    required String eventType,
    required List<Map<String, String>> teamMembers,
  }) async {
    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('doubles_requests')
        .doc();

    final String teamName = teamMembers.map((m) => m['username']).join(' & ');

    await docRef.set({
      'fromUid': teamMembers.first['uid'],
      'fromUsername': teamMembers.first['username'],
      'toUid': teamMembers.last['uid'],
      'toUsername': teamName,
      'status': 'accepted',
      'eventType': eventType,
      'teamRoster': teamMembers,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> sendTeamRosterRequest({
    required String clubId,
    required String tournamentId,
    required String eventType,
    required List<Map<String, String>> teamMembers,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final docRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('doubles_requests')
        .doc();

    final String teamName = teamMembers.map((m) => m['username']).join(' & ');

    await docRef.set({
      'fromUid': user.uid,
      'fromUsername': user.displayName ?? 'Player',
      'toUid': teamMembers.last['uid'],
      'toUsername': teamName,
      'status': 'pending',
      'acceptedUids': [user.uid],
      'eventType': eventType,
      'teamRoster': teamMembers,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineDoublesPartner({
    required String clubId,
    required String tournamentId,
    required String requestId,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final tourRef = _db.collection('clubs').doc(clubId).collection('tournaments').doc(tournamentId);
    final reqRef = tourRef.collection('doubles_requests').doc(requestId);
    final reqDoc = await reqRef.get();

    if (reqDoc.exists) {
      final reqData = reqDoc.data() as Map<String, dynamic>;
      final List teamRoster = List.from(reqData['teamRoster'] ?? []);

      if (teamRoster.isNotEmpty) {
        final List declinedUids = List.from(reqData['declinedUids'] ?? []);
        if (!declinedUids.contains(user.uid)) {
          declinedUids.add(user.uid);
        }
        await reqRef.update({
          'declinedUids': declinedUids,
        });
        return;
      }
    }

    await reqRef.delete();
  }

  Future<void> deleteDoublesPartnerRequest({
    required String clubId,
    required String tournamentId,
    required String requestId,
  }) async {
    final tourRef = _db.collection('clubs').doc(clubId).collection('tournaments').doc(tournamentId);
    await tourRef.collection('doubles_requests').doc(requestId).delete();
  }

  Future<void> updateUserGender(String gender) async {
    final user = currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).update({
      'gender': gender,
    });
  }

  Future<void> updateUserPhotoUrl(String photoUrl) async {
    final user = currentUser;
    if (user == null) return;
    try {
      await user.updatePhotoURL(photoUrl);
    } catch (e) {
      debugPrint("Error updating auth photo URL: $e");
    }
    await _db.collection('users').doc(user.uid).set({
      'photoUrl': photoUrl,
    }, SetOptions(merge: true));
  }

  Future<void> setSamkitsGenderToMale() async {
    final query = await _db
        .collection('users')
        .where('username_search', isEqualTo: 'samkits')
        .get();
    for (var doc in query.docs) {
      await doc.reference.update({'gender': 'Male'});
    }
  }

  Future<void> updateMemberRole({
    required String clubId,
    required String memberUid,
    required String newRole,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final clubDoc = await _db.collection('clubs').doc(clubId).get();
    if (!clubDoc.exists || clubDoc.data()?['ownerUid'] != user.uid) {
      throw 'Only the club owner can update member roles.';
    }

    await _db
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(memberUid)
        .update({
      'role': newRole,
    });
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
    
    debugPrint("Search: Looking for user '$trimmed'...");

    // 1. Try case-insensitive searchable field
    var result = await _db
        .collection('users')
        .where('username_search', isEqualTo: trimmed.toLowerCase())
        .limit(1)
        .get();

    if (result.docs.isNotEmpty) {
      final data = result.docs.first.data();
      data['uid'] = result.docs.first.id; // Ensure UID is always present
      debugPrint("Search: Found by username_search: ${data['username']}");
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
      debugPrint("Search: Found by case-sensitive username: ${data['username']}");
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
        debugPrint("Search: Found by email: ${data['email']}");
        return data;
      }
    }

    debugPrint("Search: No user found matching '$trimmed'");
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
    debugPrint("Firestore: Match request sent to $targetUid (ID: ${docRef.id})");
    return docRef.id;
  }

  // Respond to a match request
  Future<void> respondToRequest(String requestId, String status) async {
    try {
      final docRef = _db.collection('match_requests').doc(requestId);
      final doc = await docRef.get();
      if (!doc.exists) {
        debugPrint("Firestore: Cannot respond to request $requestId, it no longer exists.");
        return;
      }
      await docRef.update({'status': status});
    } catch (e) {
      debugPrint("Firestore Error responding to request: $e");
    }
  }

  // Delete a match request
  Future<void> deleteMatchRequest(String requestId) async {
    try {
      await _db.collection('match_requests').doc(requestId).delete();
    } catch (e) {
      debugPrint("Firestore Error deleting request: $e");
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
        debugPrint("Firestore: Initializing real-time listener for user: ${user.uid}");
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
      debugPrint("Error deleting match: $e");
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

  // --- Tournament Match Result & Rating Adjustments ---

  Future<void> recordTournamentMatchResult({
    required String clubId,
    required String tournamentId,
    required String matchId,
    required String winnerUid,
    required String loserUid,
    required String scoreText,
    String rankingCategory = 'points_open_singles',
    int pointsAwarded = 100,
    List<Map<String, dynamic>>? logs,
    List<Map<String, dynamic>>? setSummaries,
  }) async {
    final matchRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId)
        .collection('matches')
        .doc(matchId);

    final winnerRef = _db.collection('users').doc(winnerUid);
    final loserRef = _db.collection('users').doc(loserUid);
    final tourRef = _db.collection('clubs').doc(clubId).collection('tournaments').doc(tournamentId);

    // 1. Parallelize ALL network reads simultaneously
    final results = await Future.wait([
      winnerRef.get(),
      loserRef.get(),
      tourRef.get(),
    ]);

    final DocumentSnapshot winnerDoc = results[0] as DocumentSnapshot;
    final DocumentSnapshot loserDoc = results[1] as DocumentSnapshot;
    final DocumentSnapshot tourDoc = results[2] as DocumentSnapshot;

    final winnerData = (winnerDoc.data() as Map<String, dynamic>?) ?? {};
    final loserData = (loserDoc.data() as Map<String, dynamic>?) ?? {};
    final tourData = (tourDoc.data() as Map<String, dynamic>?) ?? {};

    final bool isBye = winnerUid == 'BYE' || loserUid == 'BYE' || winnerUid.isEmpty || loserUid.isEmpty;

    final batch = _db.batch();

    // Batch set match completed
    batch.set(matchRef, {
      'winnerUid': winnerUid,
      'loserUid': loserUid,
      'scoreText': scoreText,
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'logs':? logs,
      'setSummaries':? setSummaries,
    }, SetOptions(merge: true));

    if (!isBye) {
      // Rating calculations
      final double wElo = ((winnerData['elo_open_singles'] ?? winnerData['eloRating'] ?? 1200) as num).toDouble();
      final double lElo = ((loserData['elo_open_singles'] ?? loserData['eloRating'] ?? 1200) as num).toDouble();

      final double expectedW = 1.0 / (1.0 + pow(10, (lElo - wElo) / 400.0));
      final double expectedL = 1.0 / (1.0 + pow(10, (wElo - lElo) / 400.0));

      final int newWElo = (wElo + 32 * (1.0 - expectedW)).round();
      final int newLElo = (lElo + 32 * (0.0 - expectedL)).round();

      // Glicko-2 Calculations
      final double wGlicko = ((winnerData['glicko_open_singles'] ?? winnerData['glickoRating'] ?? winnerData['glicko'] ?? 800) as num).toDouble();
      final double wRd = ((winnerData['glicko_rd'] ?? winnerData['glickoRd'] ?? 350) as num).toDouble();
      final double wVol = ((winnerData['glicko_vol'] ?? winnerData['glickoVol'] ?? 0.06) as num).toDouble();

      final double lGlicko = ((loserData['glicko_open_singles'] ?? loserData['glickoRating'] ?? loserData['glicko'] ?? 800) as num).toDouble();
      final double lRd = ((loserData['glicko_rd'] ?? loserData['glickoRd'] ?? 350) as num).toDouble();
      final double lVol = ((loserData['glicko_vol'] ?? loserData['glickoVol'] ?? 0.06) as num).toDouble();

      final Glicko2Result winnerGlickoRes = _calculateGlicko2(
        r: wGlicko,
        rd: wRd,
        vol: wVol,
        opponentR: lGlicko,
        opponentRd: lRd,
        outcome: 1.0,
      );

      final Glicko2Result loserGlickoRes = _calculateGlicko2(
        r: lGlicko,
        rd: lRd,
        vol: lVol,
        opponentR: wGlicko,
        opponentRd: wRd,
        outcome: 0.0,
      );

      final int newWGlicko = winnerGlickoRes.rating.round();
      final int newLGlicko = loserGlickoRes.rating.round();

      // Glicko-1 Calculations
      final double wGlicko1 = ((winnerData['glicko1_open_singles'] ?? winnerData['glicko1Rating'] ?? 800) as num).toDouble();
      final double wGlicko1Rd = ((winnerData['glicko1_rd'] ?? 350) as num).toDouble();

      final double lGlicko1 = ((loserData['glicko1_open_singles'] ?? loserData['glicko1Rating'] ?? 800) as num).toDouble();
      final double lGlicko1Rd = ((loserData['glicko1_rd'] ?? 350) as num).toDouble();

      final Glicko1Result winnerGlicko1Res = _calculateGlicko1(
        r: wGlicko1,
        rd: wGlicko1Rd,
        opponentR: lGlicko1,
        opponentRd: lGlicko1Rd,
        outcome: 1.0,
      );

      final Glicko1Result loserGlicko1Res = _calculateGlicko1(
        r: lGlicko1,
        rd: lGlicko1Rd,
        opponentR: wGlicko1,
        opponentRd: wGlicko1Rd,
        outcome: 0.0,
      );

      String category = rankingCategory;
      if (category.isEmpty || category.contains('teams')) {
        category = 'points_open_singles';
      }

      final String eloCategory = category.replaceAll('points_', 'elo_');
      final String glickoCategory = category.replaceAll('points_', 'glicko_');
      final String glicko1Category = category.replaceAll('points_', 'glicko1_');

      if (winnerDoc.exists) {
        batch.update(winnerRef, {
          'wins': FieldValue.increment(1),
          eloCategory: newWElo,
          'eloRating': newWElo,
          glickoCategory: newWGlicko,
          'glickoRating': newWGlicko,
          'glicko_rd': winnerGlickoRes.rd,
          'glicko_vol': winnerGlickoRes.volatility,
          glicko1Category: winnerGlicko1Res.rating.round(),
          'glicko1_rd': winnerGlicko1Res.rd,
        });
      }

      if (loserDoc.exists) {
        batch.update(loserRef, {
          'losses': FieldValue.increment(1),
          eloCategory: newLElo,
          'eloRating': newLElo,
          glickoCategory: newLGlicko,
          'glickoRating': newLGlicko,
          'glicko_rd': loserGlickoRes.rd,
          'glicko_vol': loserGlickoRes.volatility,
          glicko1Category: loserGlicko1Res.rating.round(),
          'glicko1_rd': loserGlicko1Res.rd,
        });
      }

      // Automatic Bracket Advancement
      if (matchId.startsWith('match_r')) {
        final parts = matchId.split('_');
        if (parts.length >= 3) {
          final int roundNum = int.tryParse(parts[1].replaceAll('r', '')) ?? 1;
          final int matchNum = int.tryParse(parts[2].replaceAll('m', '')) ?? 1;
          final int totalRounds = (tourData['totalRounds'] as num?)?.toInt() ?? 3;

          final String winnerName = winnerData['username'] ?? 'Winner';
          final String loserName = loserData['username'] ?? 'Loser';

          if (roundNum >= totalRounds) {
            batch.update(tourRef, {
              'isCompleted': true,
              'championUid': winnerUid,
              'championName': winnerName,
              'runnerUpUid': loserUid,
              'runnerUpName': loserName,
              'completedAt': FieldValue.serverTimestamp(),
            });
          } else {
            final int nextRound = roundNum + 1;
            final int nextMatch = (matchNum + 1) ~/ 2;
            final String nextMatchId = 'match_r${nextRound}_m$nextMatch';
            final bool isP1 = matchNum % 2 != 0;

            final nextRef = tourRef.collection('matches').doc(nextMatchId);

            if (isP1) {
              batch.set(nextRef, {
                'roundNum': nextRound,
                'matchNum': nextMatch,
                'p1Uid': winnerUid,
                'p1Name': winnerName,
                'status': 'scheduled',
              }, SetOptions(merge: true));
            } else {
              batch.set(nextRef, {
                'roundNum': nextRound,
                'matchNum': nextMatch,
                'p2Uid': winnerUid,
                'p2Name': winnerName,
                'status': 'scheduled',
              }, SetOptions(merge: true));
            }

            if (nextRound == totalRounds) {
              final String bronzeId = 'match_bronze';
              final bronzeRef = tourRef.collection('matches').doc(bronzeId);
              if (isP1) {
                batch.set(bronzeRef, {
                  'p1Uid': loserUid,
                  'p1Name': loserName,
                  'status': 'scheduled',
                }, SetOptions(merge: true));
              } else {
                batch.set(bronzeRef, {
                  'p2Uid': loserUid,
                  'p2Name': loserName,
                  'status': 'scheduled',
                }, SetOptions(merge: true));
              }
            }
          }
        }
      }

      if (matchId == 'match_bronze') {
        final String winnerName = winnerData['username'] ?? '3rd Place Winner';
        batch.update(tourRef, {
          'thirdPlaceUid': winnerUid,
          'thirdPlaceName': winnerName,
        });
      }
    }

    await batch.commit();

    // Check if tournament has ended and award final placement points
    if (!isBye && matchId.startsWith('match_r')) {
      final parts = matchId.split('_');
      if (parts.length >= 3) {
        final int roundNum = int.tryParse(parts[1].replaceAll('r', '')) ?? 1;
        final int totalRounds = (tourData['totalRounds'] as num?)?.toInt() ?? 3;
        if (roundNum >= totalRounds) {
          await finalizeTournamentAndAwardPoints(clubId: clubId, tournamentId: tournamentId);
        }
      }
    }
  }

  Future<void> finalizeTournamentAndAwardPoints({
    required String clubId,
    required String tournamentId,
  }) async {
    final tourRef = _db
        .collection('clubs')
        .doc(clubId)
        .collection('tournaments')
        .doc(tournamentId);

    final tourDoc = await tourRef.get();
    if (!tourDoc.exists) return;

    final tourData = tourDoc.data() as Map<String, dynamic>;
    if (tourData['pointsDistributed'] == true) return; // Prevent duplicate distribution

    final int rankingPoints = (tourData['rankingPoints'] as num?)?.toInt() ?? 1000;
    final Map<String, dynamic> breakdown = (tourData['pointsBreakdown'] as Map<String, dynamic>?) ?? {
      'winner': rankingPoints,
      'finalist': (rankingPoints * 0.7).round(),
      'semifinalist': (rankingPoints * 0.35).round(),
      'quarterfinalist': (rankingPoints * 0.175).round(),
      'roundOf16': (rankingPoints * 0.0875).round(),
      'roundOf32': (rankingPoints * 0.045).round(),
      'roundOf64': (rankingPoints * 0.015).round(),
    };

    String doublesType = tourData['doublesType'] ?? 'none';
    String category = 'points_open_singles';
    if (doublesType != 'none') {
      category = 'points_open_doubles_indiv';
    }

    final matchesSnap = await tourRef.collection('matches').get();
    final List<QueryDocumentSnapshot> matches = matchesSnap.docs;

    Map<String, int> userHighestRoundWon = {};
    Map<String, int> userHighestRoundPlayed = {};

    for (var mDoc in matches) {
      final mData = mDoc.data() as Map<String, dynamic>;
      final String winner = mData['winnerUid'] ?? '';
      final String loser = mData['loserUid'] ?? '';
      final String p1 = mData['p1Uid'] ?? '';
      final String p2 = mData['p2Uid'] ?? '';
      final int roundNum = (mData['roundNum'] as num?)?.toInt() ?? 1;

      if (winner.isNotEmpty && winner != 'BYE') {
        userHighestRoundWon[winner] = max(userHighestRoundWon[winner] ?? 0, roundNum);
      }
      if (p1.isNotEmpty && p1 != 'BYE') {
        userHighestRoundPlayed[p1] = max(userHighestRoundPlayed[p1] ?? 0, roundNum);
      }
      if (p2.isNotEmpty && p2 != 'BYE') {
        userHighestRoundPlayed[p2] = max(userHighestRoundPlayed[p2] ?? 0, roundNum);
      }
      if (loser.isNotEmpty && loser != 'BYE') {
        userHighestRoundPlayed[loser] = max(userHighestRoundPlayed[loser] ?? 0, roundNum);
      }
    }

    final bool hasThirdPlace = tourData['hasThirdPlacePlayoff'] ?? false;
    final String championUid = tourData['championUid'] ?? '';
    final String runnerUpUid = tourData['runnerUpUid'] ?? '';
    final String thirdPlaceUid = tourData['thirdPlaceUid'] ?? '';

    String bronzeLoserUid = '';
    for (var mDoc in matches) {
      if (mDoc.id == 'match_bronze') {
        final mData = mDoc.data() as Map<String, dynamic>;
        final String bWinner = mData['winnerUid'] ?? '';
        final String bP1 = mData['p1Uid'] ?? '';
        final String bP2 = mData['p2Uid'] ?? '';
        if (bWinner.isNotEmpty) {
          bronzeLoserUid = (bWinner == bP1) ? bP2 : bP1;
        }
      }
    }

    final int totalRounds = (tourData['totalRounds'] as num?)?.toInt() ?? 3;
    final List participantUids = List.from(tourData['participantUids'] ?? []);

    final batch = _db.batch();

    for (var uidObj in participantUids) {
      final String uid = uidObj.toString();
      if (uid.isEmpty || uid == 'BYE') continue;

      int maxRoundWon = userHighestRoundWon[uid] ?? 0;
      int maxRoundPlayed = userHighestRoundPlayed[uid] ?? 1;

      int pointsToAward = breakdown['roundOf64'] ?? (rankingPoints * 0.015).round();

      int winnerPts = (breakdown['winner'] as num?)?.toInt() ?? rankingPoints;
      int finalistPts = (breakdown['finalist'] as num?)?.toInt() ?? (rankingPoints * 0.7).round();
      int semiPts = (breakdown['semifinalist'] as num?)?.toInt() ?? (rankingPoints * 0.35).round();
      int qfPts = (breakdown['quarterfinalist'] as num?)?.toInt() ?? (rankingPoints * 0.175).round();
      int fourthPts = (breakdown['fourthPlace'] as num?)?.toInt() ?? ((semiPts + qfPts) ~/ 2);

      if (uid == championUid || maxRoundWon >= totalRounds) {
        // Champion / Winner
        pointsToAward = winnerPts;
      } else if (uid == runnerUpUid || maxRoundPlayed == totalRounds) {
        // Finalist / Runner-up
        pointsToAward = finalistPts;
      } else if (hasThirdPlace) {
        // If 3rd place match exists:
        if (uid == thirdPlaceUid) {
          // 3rd Place Bronze Winner
          pointsToAward = semiPts;
        } else if (uid == bronzeLoserUid) {
          // 4th Place Bronze Loser (More than QF, Less than Bronze Winner)
          pointsToAward = fourthPts;
        } else if (maxRoundPlayed == totalRounds - 1) {
          pointsToAward = semiPts;
        } else if (maxRoundPlayed == totalRounds - 2) {
          pointsToAward = qfPts;
        } else if (maxRoundPlayed == totalRounds - 3) {
          pointsToAward = (breakdown['roundOf16'] as num?)?.toInt() ?? (rankingPoints * 0.0875).round();
        } else if (maxRoundPlayed == totalRounds - 4) {
          pointsToAward = (breakdown['roundOf32'] as num?)?.toInt() ?? (rankingPoints * 0.045).round();
        }
      } else {
        // If NO 3rd place match exists (both Semifinal losers earn equal points):
        if (maxRoundPlayed == totalRounds - 1) {
          pointsToAward = semiPts;
        } else if (maxRoundPlayed == totalRounds - 2) {
          pointsToAward = qfPts;
        } else if (maxRoundPlayed == totalRounds - 3) {
          pointsToAward = (breakdown['roundOf16'] as num?)?.toInt() ?? (rankingPoints * 0.0875).round();
        } else if (maxRoundPlayed == totalRounds - 4) {
          pointsToAward = (breakdown['roundOf32'] as num?)?.toInt() ?? (rankingPoints * 0.045).round();
        }
      }

      final userRef = _db.collection('users').doc(uid);
      batch.set(userRef, {
        category: FieldValue.increment(pointsToAward),
      }, SetOptions(merge: true));
    }

    batch.update(tourRef, {
      'isCompleted': true,
      'pointsDistributed': true,
      'completedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}

class Glicko1Result {
  final double rating;
  final double rd;

  Glicko1Result({required this.rating, required this.rd});
}

Glicko1Result _calculateGlicko1({
  required double r,
  required double rd,
  required double opponentR,
  required double opponentRd,
  required double outcome,
}) {
  const double q = 0.00575646273; // ln(10)/400
  double g(double rdVal) => 1.0 / sqrt(1.0 + (3.0 * q * q * rdVal * rdVal) / (pi * pi));

  final double gOpp = g(opponentRd);
  final double expected = 1.0 / (1.0 + pow(10, -gOpp * (r - opponentR) / 400.0));

  final double dSq = 1.0 / (q * q * gOpp * gOpp * expected * (1.0 - expected));
  final double newRd = sqrt(1.0 / ((1.0 / (rd * rd)) + (1.0 / dSq)));
  final double newR = r + (q / ((1.0 / (rd * rd)) + (1.0 / dSq))) * gOpp * (outcome - expected);

  return Glicko1Result(rating: newR, rd: newRd);
}

class Glicko2Result {
  final double rating;
  final double rd;
  final double volatility;

  Glicko2Result({
    required this.rating,
    required this.rd,
    required this.volatility,
  });
}

Glicko2Result _calculateGlicko2({
  required double r,
  required double rd,
  required double vol,
  required double opponentR,
  required double opponentRd,
  required double outcome,
}) {
  const double scale = 173.7178;
  const double tau = 0.5;
  const double defaultRating = 800.0;
  const double epsilon = 0.000001;

  double g(double phi) => 1.0 / sqrt(1.0 + (3.0 * phi * phi) / (pi * pi));
  double e(double mu, double muJ, double phiJ) => 1.0 / (1.0 + exp(-g(phiJ) * (mu - muJ)));

  final double mu = (r - defaultRating) / scale;
  final double phi = rd / scale;
  final double muJ = (opponentR - defaultRating) / scale;
  final double phiJ = opponentRd / scale;

  final double gPhiJ = g(phiJ);
  final double eVal = e(mu, muJ, phiJ);

  final double v = 1.0 / (gPhiJ * gPhiJ * eVal * (1.0 - eVal));
  final double delta = v * gPhiJ * (outcome - eVal);

  final double a = log(vol * vol);

  double f(double x) {
    final double ex = exp(x);
    final double num1 = ex * (delta * delta - phi * phi - v - ex);
    final double den1 = 2.0 * pow(phi * phi + v + ex, 2);
    return (num1 / den1) - ((x - a) / (tau * tau));
  }

  double A = a;
  double B;

  if (delta * delta > phi * phi + v) {
    B = log(delta * delta - phi * phi - v);
  } else {
    int k = 1;
    while (f(a - k * tau) < 0) {
      k++;
    }
    B = a - k * tau;
  }

  double fA = f(A);
  double fB = f(B);

  while ((B - A).abs() > epsilon) {
    final double C = A + (A - B) * fA / (fB - fA);
    final double fC = f(C);

    if (fC * fB < 0) {
      A = B;
      fA = fB;
    } else {
      fA = fA / 2.0;
    }

    B = C;
    fB = fC;
  }

  final double newVol = exp(A / 2.0);
  final double phiStar = sqrt(phi * phi + newVol * newVol);
  final double newPhi = 1.0 / sqrt((1.0 / (phiStar * phiStar)) + (1.0 / v));
  final double newMu = mu + newPhi * newPhi * gPhiJ * (outcome - eVal);

  final double newR = scale * newMu + defaultRating;
  final double newRd = scale * newPhi;

  return Glicko2Result(
    rating: newR,
    rd: newRd,
    volatility: newVol,
  );
}
