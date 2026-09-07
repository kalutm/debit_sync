import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/constants/firestore_paths.dart';
import '../models/app_user.dart';

/// Repository wrapping Firebase Auth and Firestore user document management.
///
/// Responsibilities:
/// - Authenticates users via Email/Password and Google Sign-In.
/// - Maintains the `/users/{uid}` Firestore document (create on first login,
///   merge on subsequent logins to preserve FCM tokens).
/// - Provides a real-time auth state stream for the router redirect guard.
final class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  // ── Auth State ─────────────────────────────────────────────────────────────

  /// Emits the current [User] whenever auth state changes (sign-in/out).
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the currently signed-in Firebase [User], or null if unauthenticated.
  User? get currentUser => _auth.currentUser;

  // ── Email / Password ───────────────────────────────────────────────────────

  /// Signs in an existing user with [email] and [password].
  ///
  /// Throws [FirebaseAuthException] on invalid credentials.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Creates a new account with [email] and [password], then upserts the
  /// `/users/{uid}` document with the provided [displayName].
  ///
  /// Throws [FirebaseAuthException] on duplicate email or weak password.
  Future<UserCredential> createAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update the Firebase Auth profile display name.
    await credential.user?.updateDisplayName(displayName);

    // Create the Firestore user document immediately after registration.
    final user = credential.user!;
    final appUser = AppUser(
      uid: user.uid,
      name: displayName,
      email: email,
      tokens: const [],
      createdAt: DateTime.now(),
    );
    await upsertUserDocument(appUser);

    return credential;
  }

  // ── Google Sign-In ─────────────────────────────────────────────────────────

  /// Initiates the Google Sign-In OAuth flow, then authenticates with Firebase.
  ///
  /// On first login: creates the `/users/{uid}` document populated with the
  /// user's Google profile (display name, email).
  ///
  /// On subsequent logins: merges the document to preserve FCM tokens and
  /// avoid overwriting existing data.
  ///
  /// Returns null if the user cancels the Google Sign-In picker without
  /// completing the flow.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // User dismissed the Google Sign-In dialog.
      return null;
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user!;

    // Upsert the Firestore document. SetOptions.mergeFields ensures we only
    // write name/email on first login and leave tokens untouched on re-login.
    final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

    final appUser = AppUser(
      uid: user.uid,
      name: user.displayName ?? googleUser.displayName ?? 'Unknown',
      email: user.email ?? googleUser.email,
      tokens: const [],
      createdAt: DateTime.now(),
    );

    await upsertUserDocument(appUser, isNewUser: isNewUser);

    return userCredential;
  }

  // ── Firestore User Document ────────────────────────────────────────────────

  /// Writes or merges the user's document in `/users/{uid}`.
  ///
  /// [isNewUser] — when true, sets the full document (first login).
  ///               when false, only merges [name] and [email] fields to
  ///               preserve existing [tokens] and [createdAt].
  Future<void> upsertUserDocument(AppUser user, {bool isNewUser = true}) async {
    final ref = _firestore.doc(FirestorePaths.user(user.uid));

    if (isNewUser) {
      await ref.set(user.toMap());
    } else {
      // Merge only profile fields; do not clobber tokens or createdAt.
      await ref.set({
        'name': user.name,
        'email': user.email,
      }, SetOptions(merge: true));
    }
  }

  /// Returns a real-time stream of the [AppUser] document for [uid].
  ///
  /// Emits null if the document does not yet exist.
  Stream<AppUser?> watchUserDocument(String uid) {
    return _firestore
        .doc(FirestorePaths.user(uid))
        .snapshots()
        .map(
          (snap) => snap.exists && snap.data() != null
              ? AppUser.fromJson(snap.data()!)
              : null,
        );
  }

  /// Looks up a user's UID by their email address.
  ///
  /// Returns null if no user is found with that email.
  Future<String?> findUidByEmail(String email) async {
    final snapshot = await _firestore
        .collection(FirestorePaths.usersCollection)
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// Adds [token] to the user's FCM token list if not already present.
  ///
  /// Uses Firestore [FieldValue.arrayUnion] to prevent duplicates atomically.
  Future<void> registerFcmToken({
    required String uid,
    required String token,
  }) async {
    await _firestore.doc(FirestorePaths.user(uid)).update({
      'tokens': FieldValue.arrayUnion([token]),
    });
  }

  /// Removes [token] from the user's FCM token list on sign-out.
  ///
  /// Uses Firestore [FieldValue.arrayRemove] for atomic removal.
  Future<void> unregisterFcmToken({
    required String uid,
    required String token,
  }) async {
    await _firestore.doc(FirestorePaths.user(uid)).update({
      'tokens': FieldValue.arrayRemove([token]),
    });
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────

  /// Signs the current user out of both Firebase and Google Sign-In.
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }
}
