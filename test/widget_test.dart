import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/app/app.dart';
import 'package:winner_spin/features/auth/presentation/views/login_screen.dart';
import 'package:winner_spin/features/auth/presentation/views/email_verification_screen.dart';
import 'package:winner_spin/features/slot/presentation/views/game/game_screen.dart';

import 'features/auth/support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows login when there is no authenticated user', (
    tester,
  ) async {
    final repository = FakeAuthRepository()..currentUserId = null;

    await tester.pumpWidget(WinnerSpinApp(authRepository: repository));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('keeps an unverified authenticated user out of the game', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..currentUserId = 'user-1'
      ..currentUserEmail = 'player@example.com'
      ..currentUserEmailVerified = false;

    await tester.pumpWidget(WinnerSpinApp(authRepository: repository));
    await tester.pump();
    await tester.pump();

    expect(find.byType(EmailVerificationScreen), findsOneWidget);
    expect(find.byType(GameScreen), findsNothing);
    expect(repository.sendVerificationLinkCalls, 1);
  });
}
