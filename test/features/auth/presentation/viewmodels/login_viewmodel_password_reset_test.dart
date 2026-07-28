import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/login_viewmodel.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  test('sends the link and reports where to look next', () async {
    final repository = _ResetRepository();
    final viewModel = LoginViewModel.withRepository(repository);

    final sent = await viewModel.sendPasswordReset(' player@example.com ');

    expect(sent, isTrue);
    // Trimmed: a stray space from autofill must not turn into "not registered".
    expect(repository.requestedFor, 'player@example.com');
    expect(viewModel.passwordResetFailed, isFalse);
    expect(
      viewModel.passwordResetMessage,
      contains('reset link is on its way'),
    );
    // Reset mail lands in spam often enough that not saying so reads as a
    // failure to the player.
    expect(viewModel.passwordResetMessage, contains('spam folder'));
  });

  test('rejects an address that cannot be one', () async {
    final repository = _ResetRepository();
    final viewModel = LoginViewModel.withRepository(repository);

    final sent = await viewModel.sendPasswordReset('  ');

    expect(sent, isFalse);
    expect(
      repository.requestedFor,
      isNull,
      reason: 'no point spending a call on an empty field',
    );
    expect(viewModel.passwordResetFailed, isTrue);
  });

  test('does not claim an email was sent', () async {
    final viewModel = LoginViewModel.withRepository(_ResetRepository());

    await viewModel.sendPasswordReset('player@example.com');

    // With email enumeration protection on, Firebase reports success for an
    // unknown address too. Promising delivery would be wrong half the time.
    expect(viewModel.passwordResetMessage, startsWith('If an account'));
  });

  test('says so when Firebase does report an unknown address', () async {
    // Only reachable with email enumeration protection turned off.
    final repository = _ResetRepository(
      failure: const AuthException(AuthErrorCode.userNotFound),
    );
    final viewModel = LoginViewModel.withRepository(repository);

    final sent = await viewModel.sendPasswordReset('nobody@example.com');

    expect(sent, isFalse);
    expect(
      viewModel.passwordResetMessage,
      'This email address is not registered.',
    );
  });

  test('never borrows the sign-in wording', () async {
    // An undeployed callable arrives here as `unknown`. Reusing the login
    // messages put "Login failed" in a dialog about resetting a password.
    final repository = _ResetRepository(
      failure: const AuthException(AuthErrorCode.unknown),
    );
    final viewModel = LoginViewModel.withRepository(repository);

    await viewModel.sendPasswordReset('player@example.com');

    expect(viewModel.passwordResetMessage, isNot(contains('Login')));
    expect(viewModel.passwordResetMessage, contains('Reset email'));
  });

  test('reports a generic failure without leaking the cause', () async {
    final repository = _ResetRepository(failure: Exception('boom'));
    final viewModel = LoginViewModel.withRepository(repository);

    final sent = await viewModel.sendPasswordReset('player@example.com');

    expect(sent, isFalse);
    expect(viewModel.passwordResetMessage, contains('could not be sent'));
  });

  test('clears the message once the field is edited', () async {
    final viewModel = LoginViewModel.withRepository(_ResetRepository());
    await viewModel.sendPasswordReset('player@example.com');
    expect(viewModel.passwordResetMessage, isNotNull);

    viewModel.clearPasswordResetMessage();

    expect(viewModel.passwordResetMessage, isNull);
    expect(viewModel.passwordResetFailed, isFalse);
  });
}

class _ResetRepository extends FakeAuthRepository {
  _ResetRepository({this.failure});

  final Object? failure;
  String? requestedFor;

  @override
  Future<void> sendPasswordResetEmailForAddress(String email) async {
    if (failure != null) throw failure!;
    requestedFor = email;
  }
}
