import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/email_verification_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/views/email_verification_screen.dart';
import 'package:winner_spin/features/auth/presentation/views/login_screen.dart';

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

  testWidgets('requires a password and allows deletion to be cancelled', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          sendLinkOnOpen: false,
        ),
      ),
    );
    final deleteButton = find.byKey(
      const ValueKey('delete-unverified-account-button'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('player@example.com and all associated account data'),
      findsOneWidget,
    );
    final confirmButton = find.byKey(
      const ValueKey('confirm-delete-account-button'),
    );
    expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(repository.deleteAccountCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('locks screen actions while deletion is pending and calls back', (
    tester,
  ) async {
    final deletion = Completer<void>();
    final repository = FakeAuthRepository()
      ..onDeleteAccount = (_) => deletion.future;
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );
    var accountDeleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          sendLinkOnOpen: false,
          onAccountDeleted: () => accountDeleted = true,
        ),
      ),
    );
    await _openDeletionDialog(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.reloadCurrentUserCalls, 0);
    await _confirmDeletion(tester, 'hunter2');

    expect(find.text('DELETING...'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('verify-email-button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'USE A DIFFERENT ACCOUNT'),
          )
          .onPressed,
      isNull,
    );
    expect(accountDeleted, isFalse);

    deletion.complete();
    await tester.pump();
    await tester.pump();

    expect(repository.deleteAccountPassword, 'hunter2');
    expect(accountDeleted, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('shows an error after an incorrect deletion password', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..onDeleteAccount = (_) =>
          Future<void>.error(const AuthException(AuthErrorCode.wrongPassword));
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          sendLinkOnOpen: false,
        ),
      ),
    );
    await _submitDeletion(tester, 'wrong-password');
    await tester.pumpAndSettle();

    expect(find.textContaining('Incorrect password'), findsOneWidget);
    expect(find.text('DELETE THIS ACCOUNT'), findsOneWidget);
    expect(find.byKey(const ValueKey('account-deleted-dialog')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('clears the route stack after deletion without a callback', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final repository = FakeAuthRepository();
    final viewModel = EmailVerificationViewModel(
      email: 'player@example.com',
      authRepository: repository,
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: EmailVerificationScreen(
          email: 'player@example.com',
          viewModel: viewModel,
          authRepository: repository,
          sendLinkOnOpen: false,
        ),
      ),
    );
    await _submitDeletion(tester, 'hunter2');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('account-deleted-ok-button')));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('account-deleted-dialog')), findsNothing);
    expect(navigatorKey.currentState!.canPop(), isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });
}

Future<void> _submitDeletion(WidgetTester tester, String password) async {
  await _openDeletionDialog(tester);
  await _confirmDeletion(tester, password);
}

Future<void> _openDeletionDialog(WidgetTester tester) async {
  final deleteButton = find.byKey(
    const ValueKey('delete-unverified-account-button'),
  );
  await tester.ensureVisible(deleteButton);
  await tester.tap(deleteButton);
  await tester.pumpAndSettle();
}

Future<void> _confirmDeletion(WidgetTester tester, String password) async {
  await tester.enterText(
    find.byKey(const ValueKey('delete-account-password')),
    password,
  );
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('confirm-delete-account-button')));
  await tester.pump();
}
