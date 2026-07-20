import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/models/email_verification_failure.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/email_verification_viewmodel.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EmailVerificationViewModel', () {
    test('sends a verification link and starts the resend cooldown', () async {
      final repository = FakeAuthRepository();
      final viewModel = EmailVerificationViewModel(
        email: 'player@example.com',
        authRepository: repository,
      );

      await viewModel.sendVerificationLink();

      expect(repository.sendVerificationLinkCalls, 1);
      expect(viewModel.resendSecondsRemaining, 60);
      expect(viewModel.canResend, isFalse);
      expect(viewModel.message, contains('player@example.com'));
      viewModel.dispose();
    });

    test('continues after Firebase reports a verified email', () async {
      final repository = FakeAuthRepository();
      repository.onReloadCurrentUser = () async {
        repository.currentUserEmailVerified = true;
      };
      final viewModel = EmailVerificationViewModel(
        email: 'player@example.com',
        authRepository: repository,
      );

      await viewModel.checkVerificationStatus();

      expect(repository.reloadCurrentUserCalls, 1);
      expect(viewModel.verificationSuccess, isTrue);
      expect(viewModel.messageIsError, isFalse);
      viewModel.dispose();
    });

    test('keeps the user on the screen while email is unverified', () async {
      final repository = FakeAuthRepository();
      final viewModel = EmailVerificationViewModel(
        email: 'player@example.com',
        authRepository: repository,
      );

      await viewModel.checkVerificationStatus();

      expect(viewModel.verificationSuccess, isFalse);
      expect(viewModel.message, contains('not verified yet'));
      expect(viewModel.messageIsError, isTrue);
      viewModel.dispose();
    });

    test('handles Firebase email throttling', () async {
      final repository = FakeAuthRepository()
        ..onSendVerificationLink = () => Future<void>.error(
          const EmailVerificationException(
            EmailVerificationFailureCode.tooManyRequests,
          ),
        );
      final viewModel = EmailVerificationViewModel(
        email: 'player@example.com',
        authRepository: repository,
      );
      await viewModel.sendVerificationLink();

      expect(viewModel.canResend, isFalse);
      expect(viewModel.message, contains('Too many verification emails'));
      viewModel.dispose();
    });
  });
}
