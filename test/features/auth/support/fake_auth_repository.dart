import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  Future<String?> Function(String email, String password)? onSignIn;
  Future<String?> Function(String email, String password, String username)?
  onSignUp;
  Future<void> Function()? onSendVerificationLink;
  Future<void> Function()? onReloadCurrentUser;
  Future<void> Function(String password)? onDeleteAccount;
  Future<UserProfileExistence> Function(String uid)? onGetUserProfileExistence;

  int signOutCalls = 0;
  int deleteAccountCalls = 0;
  int sendVerificationLinkCalls = 0;
  int reloadCurrentUserCalls = 0;
  int getUserProfileExistenceCalls = 0;
  String? deleteAccountPassword;
  bool authDeletionCompleted = false;

  @override
  String? currentUserId = 'user-1';

  @override
  String? currentUserEmail = 'player@example.com';

  @override
  bool currentUserEmailVerified = false;

  @override
  Future<String?> signIn({required String email, required String password}) {
    return onSignIn?.call(email, password) ?? Future.value(currentUserId);
  }

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) {
    currentUserEmail = email;
    return onSignUp?.call(email, password, username) ??
        Future.value(currentUserId);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }

  @override
  Future<void> deleteAccount(
    String password, {
    BeforeAuthDeletion? beforeAuthDeletion,
  }) async {
    deleteAccountCalls++;
    deleteAccountPassword = password;
    await onDeleteAccount?.call(password);
    final userId = currentUserId;
    if (userId != null) await beforeAuthDeletion?.call(userId);
    authDeletionCompleted = true;
  }

  @override
  Future<void> reloadCurrentUser() async {
    reloadCurrentUserCalls++;
    await onReloadCurrentUser?.call();
  }

  @override
  Future<void> sendEmailVerificationLink() async {
    sendVerificationLinkCalls++;
    await onSendVerificationLink?.call();
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async => null;

  @override
  Future<UserProfileExistence> getUserProfileExistence(String uid) async {
    getUserProfileExistenceCalls++;
    return onGetUserProfileExistence?.call(uid) ?? UserProfileExistence.missing;
  }

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      const Stream.empty();

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) async {}

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {}

  @override
  Future<void> sendPasswordResetEmailForAddress(String email) async {}

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) async {}
}
