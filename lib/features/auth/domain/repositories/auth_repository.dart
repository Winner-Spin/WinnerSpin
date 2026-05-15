enum AuthErrorCode {
  userNotFound,
  wrongPassword,
  invalidEmail,
  userDisabled,
  invalidCredential,
  emailAlreadyInUse,
  weakPassword,
  unknown,
}

class AuthException implements Exception {
  final AuthErrorCode code;
  final String? rawMessage;
  const AuthException(this.code, [this.rawMessage]);

  @override
  String toString() => 'AuthException($code, $rawMessage)';
}

abstract class AuthRepository {
  String? get currentUserId;

  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  });

  Future<String?> signIn({required String email, required String password});

  Future<void> signOut();

  Future<Map<String, dynamic>?> getUserData(String uid);

  Stream<Map<String, dynamic>?> watchUserData(String uid);

  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    int? freeSpinsRemaining,
  });
}
