import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Returns the currently signed-in user, or null.
  User? get currentUser => _auth.currentUser;

  // ─── SIGN UP ───────────────────────────────────────────────

  /// Creates a new user with [email] and [password], sets the
  /// display name to [username], and writes the user profile
  /// document to Firestore at `users/{uid}`.
  Future<User?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    // 1. Create the Firebase Auth account
    final UserCredential credential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final User? user = credential.user;
    if (user == null) return null;

    // 2. Set display name on the Auth profile
    await user.updateDisplayName(username.trim());

    // 3. Store extended profile in Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'username': username.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return user;
  }

  // ─── SIGN IN ───────────────────────────────────────────────

  /// Signs in an existing user with [email] and [password].
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential credential =
        await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    return credential.user;
  }

  // ─── SIGN OUT ──────────────────────────────────────────────

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── USER DATA ─────────────────────────────────────────────

  /// Fetches user profile data from Firestore.
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      // Return null on failure to prevent app crashes and data leaks.
      return null;
    }
  }
}
