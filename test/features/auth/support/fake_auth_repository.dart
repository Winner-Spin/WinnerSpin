import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';

class FakeAuthRepository implements AuthRepository {
  Future<String?> Function(String email, String password)? onSignIn;
  Future<String?> Function(String email, String password, String username)?
  onSignUp;
  Future<void> Function()? onSendVerificationLink;
  Future<void> Function()? onReloadCurrentUser;

  int signOutCalls = 0;
  int deleteAccountCalls = 0;
  int sendVerificationLinkCalls = 0;
  int reloadCurrentUserCalls = 0;

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
  Future<void> deleteAccount() async {
    deleteAccountCalls++;
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
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      const Stream.empty();

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) async {}

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {}

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
