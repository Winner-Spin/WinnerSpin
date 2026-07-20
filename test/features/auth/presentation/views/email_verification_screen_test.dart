import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/email_verification_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/views/email_verification_screen.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows English copy and checks the Firebase verification state', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    repository.onReloadCurrentUser = () async {
      repository.currentUserEmailVerified = true;
    };
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );
    var verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          sendLinkOnOpen: false,
          onVerified: () => verified = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('VERIFY EMAIL'), findsOneWidget);
    expect(find.text('CHECK YOUR EMAIL'), findsOneWidget);
    expect(find.text("I'VE VERIFIED MY EMAIL"), findsOneWidget);
    expect(find.text('USE A DIFFERENT ACCOUNT'), findsOneWidget);
    expect(find.textContaining('tap VERIFY EMAIL'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('verify-email-button')));
    await tester.pump();
    await tester.pump();

    expect(repository.reloadCurrentUserCalls, 1);
    expect(verified, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('checks verification automatically when the app resumes', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    repository.onReloadCurrentUser = () async {
      repository.currentUserEmailVerified = true;
    };
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );
    var verified = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          sendLinkOnOpen: false,
          onVerified: () => verified = true,
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(repository.reloadCurrentUserCalls, 1);
    expect(verified, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });
}
