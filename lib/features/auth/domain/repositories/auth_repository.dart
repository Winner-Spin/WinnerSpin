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

  Future<void> deleteAccount();

  Future<void> reloadCurrentUser();

  Future<void> sendEmailVerificationLink();

  Future<Map<String, dynamic>?> getUserData(String uid);

  Stream<Map<String, dynamic>?> watchUserData(String uid);

  Future<void> updateProfileAvatar(String uid, String avatarId);

  Future<void> sendPasswordResetEmail(String uid, String email);

  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  });
}
