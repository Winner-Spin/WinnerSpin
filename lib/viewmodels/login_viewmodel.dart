import 'package:flutter/material.dart';

class LoginViewModel extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      return;
    }

    _setLoading(true);

    await Future.delayed(const Duration(seconds: 2));

    // TODO: Implement actual authentication logic
    print("Login with Email: ${emailController.text}, Password: ${passwordController.text}");

    _setLoading(false);
  }

  void navigateToSignUp() {
    // TODO: Implement navigation logic
    print("Navigating to Sign Up Screen");
  }

  void toggleMusic() {
    // TODO: Implement music toggle logic
    print("Toggling Music");
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
