import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/presentation/viewmodels/register_viewmodel.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('keeps the new user signed in and opens verification next', () async {
    final repository = FakeAuthRepository();
    final viewModel = RegisterViewModel(authRepository: repository);
    viewModel.nameController.text = 'Player One';
    viewModel.emailController.text = 'player@example.com';
    viewModel.passwordController.text = 'password';
    viewModel.passwordConfirmController.text = 'password';

    await viewModel.register();

    expect(viewModel.registrationSuccess, isTrue);
    expect(viewModel.verificationEmail, 'player@example.com');
    expect(repository.signOutCalls, 0);
    viewModel.dispose();
  });
}
