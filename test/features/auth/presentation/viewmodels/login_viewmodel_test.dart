import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/login_viewmodel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LoginViewModel', () {
    test('stops loading and reports a connection timeout', () async {
      final repository = _FakeAuthRepository(
        signInResult: Completer<String?>().future,
      );
      final viewModel = LoginViewModel.withRepository(
        repository,
        requestTimeout: const Duration(milliseconds: 10),
      );
      viewModel.emailController.text = 'player@example.com';
      viewModel.passwordController.text = 'password';

      await viewModel.login();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loginSuccess, isFalse);
      expect(
        viewModel.errorMessage,
        'Connection timed out. Please check your internet connection.',
      );
      expect(viewModel.errorPresentation, LoginErrorPresentation.snackBar);
    });

    test('stops loading and reports Firebase network errors', () async {
      final repository = _FakeAuthRepository(
        signInResult: Future<String?>.error(
          const AuthException(AuthErrorCode.networkRequestFailed),
        ),
      );
      final viewModel = LoginViewModel.withRepository(repository);
      viewModel.emailController.text = 'player@example.com';
      viewModel.passwordController.text = 'password';

      await viewModel.login();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loginSuccess, isFalse);
      expect(
        viewModel.errorMessage,
        'No internet connection. Please check your connection.',
      );
      expect(viewModel.errorPresentation, LoginErrorPresentation.snackBar);
    });

    test(
      'keeps the invalid credential message for real credential errors',
      () async {
        final repository = _FakeAuthRepository(
          signInResult: Future<String?>.error(
            const AuthException(AuthErrorCode.invalidCredential),
          ),
        );
        final viewModel = LoginViewModel.withRepository(repository);
        viewModel.emailController.text = 'player@example.com';
        viewModel.passwordController.text = 'wrong-password';

        await viewModel.login();

        expect(viewModel.isLoading, isFalse);
        expect(viewModel.loginSuccess, isFalse);
        expect(viewModel.errorMessage, 'Invalid email or password.');
        expect(viewModel.errorPresentation, LoginErrorPresentation.image);
      },
    );

    test('routes an unverified account to email verification', () async {
      final repository = _FakeAuthRepository(
        signInResult: Future<String?>.error(
          const AuthException(
            AuthErrorCode.emailVerificationRequired,
            'player@example.com',
          ),
        ),
      );
      final viewModel = LoginViewModel.withRepository(repository);
      viewModel.emailController.text = 'player@example.com';
      viewModel.passwordController.text = 'password';

      await viewModel.login();

      expect(viewModel.loginSuccess, isFalse);
      expect(viewModel.verificationRequired, isTrue);
      expect(viewModel.verificationEmail, 'player@example.com');
      expect(viewModel.errorMessage, isNull);
    });
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({required this.signInResult});

  final Future<String?> signInResult;

  @override
  String? get currentUserId => null;

  @override
  String? get currentUserEmail => null;

  @override
  bool get currentUserEmailVerified => false;

  @override
  Future<String?> signIn({required String email, required String password}) =>
      signInResult;

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) => throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<void> deleteAccount() => throw UnimplementedError();

  @override
  Future<void> reloadCurrentUser() => throw UnimplementedError();

  @override
  Future<void> sendEmailVerificationLink() => throw UnimplementedError();

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) =>
      throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      throw UnimplementedError();

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) =>
      throw UnimplementedError();

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) =>
      throw UnimplementedError();

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) => throw UnimplementedError();
}
