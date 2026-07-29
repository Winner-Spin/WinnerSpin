import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/network/internet_connection_probe.dart';
import '../../domain/models/email_verification_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/password_reset_rate_limiter.dart';

typedef InternetConnectionCheck = Future<bool> Function();

/// Firebase implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    InternetConnectionCheck? internetConnectionCheck,
    DateTime Function()? now,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1'),
       _internetConnectionCheck =
           internetConnectionCheck ?? hasInternetConnection,
       _now = now ?? DateTime.now;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final InternetConnectionCheck _internetConnectionCheck;
  final DateTime Function() _now;

  static const String _usersCollection = 'users';
  static const String _passwordResetRequestedAtField =
      'passwordResetRequestedAt';
  static const String _passwordResetRequestIdField = 'passwordResetRequestId';

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentUserEmail => _auth.currentUser?.email;

  @override
  bool get currentUserEmailVerified => _auth.currentUser?.emailVerified == true;

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
        'emailVerified': false,
        'profileAvatarId': 'pink_bear',
        'createdAt': FieldValue.serverTimestamp(),
        'balance': 10000.0,
        'userBalance': 10000.0,
        'lastWin': 0.0,
        'freeSpinsRemaining': 0,
        'freeSpinAccumulatedWin': 0.0,
        'freeSpinsAwardedThisRound': 0,
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
      if (!await _internetConnectionCheck()) {
        throw const AuthException(AuthErrorCode.networkRequestFailed);
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.reload();
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        throw AuthException(
          AuthErrorCode.emailVerificationRequired,
          user.email,
        );
      }
      return user?.uid;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code), e.message);
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException(AuthErrorCode.userNotFound);
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: email, password: password),
      );
      await user.getIdToken(true);

      await _functions.httpsCallable('deleteAccount').call<void>();
      try {
        await _auth.signOut();
      } catch (_) {
        // Server deletion already succeeded; device cleanup must still run.
      }
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseCode(error.code), error.message);
    } on FirebaseFunctionsException catch (error) {
      throw AuthException(AuthErrorCode.unknown, error.message);
    }
  }

  @override
  Future<void> reloadCurrentUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // Password resets revoke the previous refresh token. Forcing a token
      // refresh makes the client observe that revocation immediately instead
      // of continuing with an ID token that may remain cached for up to an hour.
      await currentUser.getIdToken(true);
      await currentUser.reload();
    } on FirebaseAuthException catch (error) {
      if (_isInvalidSessionError(error.code)) {
        await _auth.signOut();
        return;
      }
      rethrow;
    }

    final user = _auth.currentUser;
    if (user == null || !user.emailVerified) return;

    // Firebase Authentication owns the verification state. Keep the public
    // profile document in sync without making sign-in depend on this write.
    try {
      await _firestore.collection(_usersCollection).doc(user.uid).set({
        'emailVerified': true,
      }, SetOptions(merge: true));
    } catch (_) {
      // A later app start or profile refresh will retry this best-effort sync.
    }
  }

  @override
  Future<void> sendEmailVerificationLink() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailVerificationException(
        EmailVerificationFailureCode.unavailable,
        rawMessage: 'There is no authenticated user.',
      );
    }
    if (user.emailVerified) return;

    try {
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _mapVerificationError(error);
    }
  }

  EmailVerificationException _mapVerificationError(
    FirebaseAuthException error,
  ) {
    return EmailVerificationException(switch (error.code) {
      'too-many-requests' => EmailVerificationFailureCode.tooManyRequests,
      'network-request-failed' => EmailVerificationFailureCode.unavailable,
      _ => EmailVerificationFailureCode.unknown,
    }, rawMessage: error.message);
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection(_usersCollection).doc(uid).get();
      if (doc.exists) return doc.data();
      return null;
    } catch (_) {
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
  Future<void> updateProfileAvatar(String uid, String avatarId) {
    return _firestore.collection(_usersCollection).doc(uid).set({
      'profileAvatarId': avatarId,
    }, SetOptions(merge: true));
  }

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {
    final requestedAt = _now().toUtc();
    final requestId = '$uid-${requestedAt.microsecondsSinceEpoch}';
    final userRef = _firestore.collection(_usersCollection).doc(uid);
    DateTime? previousRequestAt;

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        previousRequestAt = _readFirestoreDate(
          data?[_passwordResetRequestedAtField],
        );
        // Checked here only to produce a friendly message with a retry time.
        // The rule that actually holds is in firestore.rules, evaluated
        // against the server clock — this one runs on a clock the player can
        // set to whatever they like.
        PasswordResetRateLimiter.ensureAllowed(
          lastRequestAt: previousRequestAt,
          now: requestedAt,
        );
        transaction.set(userRef, {
          // Server time, not the device's. The rules require exactly this, so
          // a shifted clock cannot backdate the record and unlock an early
          // retry.
          _passwordResetRequestedAtField: FieldValue.serverTimestamp(),
          _passwordResetRequestIdField: requestId,
        }, SetOptions(merge: true));
      });

      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseCode(e.code), e.message);
    } on PasswordResetLimitException {
      rethrow;
    } on FirebaseException catch (error) {
      // The write is refused when the server says the day is not up, which is
      // the case a tampered clock walks into.
      if (error.code == 'permission-denied' && previousRequestAt != null) {
        throw PasswordResetLimitException(
          previousRequestAt!.add(PasswordResetRateLimiter.cooldown).toLocal(),
        );
      }
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmailForAddress(String email) async {
    // No Firestore reservation here, unlike the in-app flow. The caller is not
    // signed in, so it knows no uid and the rules keep it away from
    // `users/{uid}` — the 24-hour record simply cannot be written or read from
    // this side. Enforcing it would need a server, so what is left is
    // Firebase's own abuse protection on the endpoint.
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_mapFirebaseCode(error.code), error.message);
    }
  }

  DateTime? _readFirestoreDate(Object? value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) async {
    final patch = <String, dynamic>{};
    if (userBalance != null) {
      patch['userBalance'] = (userBalance * 100).round() / 100;
    }
    if (lastWin != null) {
      patch['lastWin'] = (lastWin * 100).round() / 100;
    }
    if (freeSpinsRemaining != null) {
      patch['freeSpinsRemaining'] = freeSpinsRemaining;
    }
    if (freeSpinAccumulatedWin != null) {
      patch['freeSpinAccumulatedWin'] =
          (freeSpinAccumulatedWin * 100).round() / 100;
    }
    if (freeSpinsAwardedThisRound != null) {
      patch['freeSpinsAwardedThisRound'] = freeSpinsAwardedThisRound;
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
      case 'network-request-failed':
        return AuthErrorCode.networkRequestFailed;
      default:
        return AuthErrorCode.unknown;
    }
  }

  static bool _isInvalidSessionError(String code) {
    return switch (code) {
      'invalid-user-token' ||
      'user-token-expired' ||
      'user-disabled' ||
      'user-not-found' => true,
      _ => false,
    };
  }
}
