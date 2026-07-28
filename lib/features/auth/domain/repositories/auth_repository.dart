enum AuthErrorCode {
  userNotFound,
  wrongPassword,
  invalidEmail,
  userDisabled,
  invalidCredential,
  emailAlreadyInUse,
  weakPassword,
  networkRequestFailed,
  emailVerificationRequired,
  unknown,
}

class AuthException implements Exception {
  final AuthErrorCode code;
  final String? rawMessage;
  const AuthException(this.code, [this.rawMessage]);

  @override
  String toString() => 'AuthException($code, $rawMessage)';
}

class PasswordResetLimitException implements Exception {
  const PasswordResetLimitException(this.nextAllowedAt);

  final DateTime nextAllowedAt;

  @override
  String toString() =>
      'PasswordResetLimitException(nextAllowedAt: $nextAllowedAt)';
}

abstract class AuthRepository {
  String? get currentUserId;

  String? get currentUserEmail;

  bool get currentUserEmailVerified;

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  });

  Future<String?> signIn({required String email, required String password});

  Future<void> signOut();

  /// Deletes the signed-in account and its stored data.
  ///
  /// [password] re-proves who is asking. Firebase refuses to delete an account
  /// on a stale sign-in, and for something irreversible it is worth asking
  /// anyway — a borrowed unlocked phone should not be able to wipe an account.
  ///
  /// Throws [AuthException] with [AuthErrorCode.wrongPassword] when the
  /// password does not match.
  ///
  /// [onReauthenticated] runs once the password is proven and before anything
  /// is removed. Used to preserve records that the deletion would otherwise
  /// take with it; the auth layer does not need to know what those are.
  Future<void> deleteAccount(
    String password, {
    Future<void> Function()? onReauthenticated,
  });

  Future<void> reloadCurrentUser();

  Future<void> sendEmailVerificationLink();

  Future<Map<String, dynamic>?> getUserData(String uid);

  Stream<Map<String, dynamic>?> watchUserData(String uid);

  Future<void> updateProfileAvatar(String uid, String avatarId);

  Future<void> sendPasswordResetEmail(String uid, String email);

  /// Password reset for someone who cannot sign in.
  ///
  /// Unlike [sendPasswordResetEmail] there is no uid and therefore no 24-hour
  /// record: a signed-out caller cannot reach its own user document. Only
  /// Firebase's own protection applies.
  ///
  /// Whether an unknown address reports [AuthErrorCode.userNotFound] depends on
  /// the project's email enumeration protection; with it on, Firebase reports
  /// success either way.
  Future<void> sendPasswordResetEmailForAddress(String email);

  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  });
}
