import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/audio/ambient_music_preference.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/login_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/views/login_screen.dart';
import 'package:winner_spin/features/auth/presentation/views/post_login_gate.dart';
import 'package:winner_spin/features/slot/data/repositories/local_user_data_eraser.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AmbientMusicPreference.resetForTesting();
    await AmbientMusicPreference.setEnabled(false);
  });

  tearDown(AmbientMusicPreference.resetForTesting);

  testWidgets('missing profile stays locked behind account recovery', (
    tester,
  ) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(home: PostLoginGate(authRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MissingProfileRecoveryScreen), findsOneWidget);
    expect(find.text('DELETE THIS ACCOUNT'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('profile-recovery-delete-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('lookup failure offers retry and safe sign out', (tester) async {
    final repository = FakeAuthRepository()
      ..onGetUserProfileExistence = (_) => Future.error(Exception('offline'));

    await tester.pumpWidget(
      MaterialApp(home: PostLoginGate(authRepository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROFILE CHECK FAILED'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('profile-gate-retry-button')));
    await tester.pumpAndSettle();
    expect(repository.getUserProfileExistenceCalls, 2);

    await tester.tap(
      find.byKey(const ValueKey('profile-gate-sign-out-button')),
    );
    await tester.pumpAndSettle();
    expect(repository.signOutCalls, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('recovery deletion erases local data and shows success notice', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final eraser = _RecordingLocalUserDataEraser();

    await tester.pumpWidget(
      MaterialApp(
        home: PostLoginGate(
          authRepository: repository,
          localUserDataEraser: eraser,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-recovery-password')),
      'hunter2',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('profile-recovery-delete-button')),
    );
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(repository.deleteAccountPassword, 'hunter2');
    expect(repository.authDeletionCompleted, isTrue);
    expect(eraser.erasedUserIds, ['user-1']);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('wrong password keeps recovery locked and preserves local data', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..onDeleteAccount = (_) =>
          Future<void>.error(const AuthException(AuthErrorCode.wrongPassword));
    final eraser = _RecordingLocalUserDataEraser();

    await tester.pumpWidget(
      MaterialApp(
        home: PostLoginGate(
          authRepository: repository,
          localUserDataEraser: eraser,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-recovery-password')),
      'wrong-password',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('profile-recovery-delete-button')),
    );
    // The focused password field keeps scheduling cursor frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MissingProfileRecoveryScreen), findsOneWidget);
    expect(
      find.text('Incorrect password. The account was not deleted.'),
      findsOneWidget,
    );
    expect(eraser.erasedUserIds, isEmpty);
    expect(repository.authDeletionCompleted, isFalse);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('local cleanup failure prevents Auth deletion finalization', (
    tester,
  ) async {
    final repository = FakeAuthRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: PostLoginGate(
          authRepository: repository,
          localUserDataEraser: _FailingLocalUserDataEraser(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('profile-recovery-password')),
      'hunter2',
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('profile-recovery-delete-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MissingProfileRecoveryScreen), findsOneWidget);
    expect(
      find.text('Account could not be deleted. Please try again.'),
      findsOneWidget,
    );
    expect(repository.authDeletionCompleted, isFalse);
    expect(find.byType(LoginScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('present profile proceeds to the injected destination', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..onGetUserProfileExistence = (_) async => UserProfileExistence.present;

    await tester.pumpWidget(
      MaterialApp(
        home: PostLoginGate(
          authRepository: repository,
          presentDestinationBuilder: (_) =>
              const SizedBox(key: ValueKey('post-login-destination')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('post-login-destination')),
      findsOneWidget,
    );
    expect(find.byType(MissingProfileRecoveryScreen), findsNothing);
  });

  testWidgets('successful login still checks profile existence', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final viewModel = LoginViewModel.withRepository(repository);
    viewModel.emailController.text = 'player@example.com';
    viewModel.passwordController.text = 'hunter2';

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(authRepository: repository, viewModel: viewModel),
      ),
    );
    await viewModel.login();
    await tester.pumpAndSettle();

    expect(repository.getUserProfileExistenceCalls, 1);
    expect(find.byType(MissingProfileRecoveryScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });
}

class _RecordingLocalUserDataEraser extends LocalUserDataEraser {
  final List<String> erasedUserIds = [];

  @override
  Future<void> eraseFor(String userId) async {
    erasedUserIds.add(userId);
  }
}

class _FailingLocalUserDataEraser extends LocalUserDataEraser {
  @override
  Future<void> eraseFor(String userId) async {
    throw StateError('local cleanup failed');
  }
}
