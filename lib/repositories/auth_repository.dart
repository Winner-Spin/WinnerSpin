/// Domain-level error codes — provider-agnostic. Concrete repositories
/// translate Firebase / network errors into these.
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

/// Thrown by [AuthRepository] implementations on auth failures.
/// ViewModels catch this and map [code] to a user-facing message.
class AuthException implements Exception {
  final AuthErrorCode code;
  final String? rawMessage;
  const AuthException(this.code, [this.rawMessage]);

  @override
  String toString() => 'AuthException($code, $rawMessage)';
}

/// Abstract auth contract. Hides FirebaseAuth and Firestore types from the
/// presentation layer. ViewModels depend on this; concrete impls (Firebase,
/// future mocks for tests) implement it.
abstract class AuthRepository {
  /// UID of the currently signed-in user, or null when signed out.
  String? get currentUserId;

  /// Creates a new account, sets the display name, and writes the initial
  /// user document. Returns the new UID, or null if creation failed silently.
  /// Throws [AuthException] on auth-layer errors.
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  });

  /// Signs in an existing user. Returns the UID on success.
  /// Throws [AuthException] on auth-layer errors.
  Future<String?> signIn({
    required String email,
    required String password,
  });

  /// Signs out the current user.
  Future<void> signOut();

  /// One-shot fetch of the user document.
  Future<Map<String, dynamic>?> getUserData(String uid);

  /// Live stream of user document changes — emits whenever the doc updates.
  Stream<Map<String, dynamic>?> watchUserData(String uid);

  /// Patches the user document with player-level state (balance, FS counter).
  /// Either field may be omitted to leave it untouched.
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    int? freeSpinsRemaining,
  });
}
