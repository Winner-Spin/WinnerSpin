import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';

/// FirebaseAuth + Firestore implementation of [AuthRepository].
/// Translates [FirebaseAuthException] into the domain-level [AuthException]
/// so the presentation layer never imports Firebase types.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static const String _usersCollection = 'users';

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return null;

      await user.updateDisplayName(username.trim());

      await _firestore.collection(_usersCollection).doc(user.uid).set({
        'uid': user.uid,
        'username': username.trim(),
        'email': email.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 10000.0,
        'userBalance': 10000.0,
        'freeSpinsRemaining': 0,
      });

      return user.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code), e.message);
    }
  }

  @override
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user?.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code), e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (_) {
      // Silently swallow — caller falls back to defaults.
      return null;
    }
  }

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) {
    return _firestore
        .collection(_usersCollection)
        .doc(uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    int? freeSpinsRemaining,
  }) async {
    final patch = <String, dynamic>{};
    if (userBalance != null) {
      // Round to 2 decimal places (cents) so accumulated float-precision
      // drift from engine math doesn't leak into the persisted balance.
      patch['userBalance'] = (userBalance * 100).round() / 100;
    }
    if (freeSpinsRemaining != null) {
      patch['freeSpinsRemaining'] = freeSpinsRemaining;
    }
    if (patch.isEmpty) return;

    await _firestore
        .collection(_usersCollection)
        .doc(uid)
        .set(patch, SetOptions(merge: true));
  }

  static AuthErrorCode _mapFirebaseCode(String code) {
    switch (code) {
      case 'user-not-found':
        return AuthErrorCode.userNotFound;
      case 'wrong-password':
        return AuthErrorCode.wrongPassword;
      case 'invalid-email':
        return AuthErrorCode.invalidEmail;
      case 'user-disabled':
        return AuthErrorCode.userDisabled;
      case 'invalid-credential':
        return AuthErrorCode.invalidCredential;
      case 'email-already-in-use':
        return AuthErrorCode.emailAlreadyInUse;
      case 'weak-password':
        return AuthErrorCode.weakPassword;
      default:
        return AuthErrorCode.unknown;
    }
  }
}
