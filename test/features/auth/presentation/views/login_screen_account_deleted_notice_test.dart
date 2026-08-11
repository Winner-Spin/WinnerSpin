import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/login_viewmodel.dart';
import 'package:winner_spin/features/auth/presentation/views/login_screen.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('does not show the account deleted notice by default', (
    tester,
  ) async {
    final viewModel = LoginViewModel.withRepository(FakeAuthRepository());

    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(viewModel: viewModel)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-deleted-dialog')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });

  testWidgets('shows the notice once and the close button keeps login open', (
    tester,
  ) async {
    final viewModel = LoginViewModel.withRepository(FakeAuthRepository());
    final rebuild = ValueNotifier<int>(0);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: rebuild,
          builder: (_, _, _) =>
              LoginScreen(viewModel: viewModel, showAccountDeletedNotice: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsOneWidget,
    );
    expect(find.text('ACCOUNT DELETED'), findsOneWidget);
    expect(
      find.text('Your account and associated data have been deleted.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('account-deleted-close-button')),
          )
          .tooltip,
      'Close',
    );

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsOneWidget,
      reason: 'the modal barrier must not dismiss the success notice',
    );

    rebuild.value++;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsOneWidget,
      reason: 'a parent rebuild must not schedule another notice',
    );

    await tester.tap(
      find.byKey(const ValueKey('account-deleted-close-button')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-deleted-dialog')), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    rebuild.value++;
    await tester.pump();
    expect(
      find.byKey(const ValueKey('account-deleted-dialog')),
      findsNothing,
      reason: 'the handled notice must stay closed after a rebuild',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    rebuild.dispose();
    viewModel.dispose();
  });

  testWidgets('OK closes only the notice and keeps login open', (tester) async {
    final viewModel = LoginViewModel.withRepository(FakeAuthRepository());

    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(viewModel: viewModel, showAccountDeletedNotice: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('account-deleted-ok-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-deleted-dialog')), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    viewModel.dispose();
  });
}
