import 'package:flutter/material.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  RegisterViewModel({AuthRepository? authRepository})
      : _authRepository = authRepository ?? FirebaseAuthRepository();

  final AuthRepository _authRepository;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _registrationSuccess = false;
  bool get registrationSuccess => _registrationSuccess;

  /// Validates inputs and calls the repository's signUp.
  /// On success the user is signed back out so they must log in manually;
  /// the View handles navigation off [registrationSuccess].
  Future<void> register() async {
    _errorMessage = null;
    _registrationSuccess = false;

    final username = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = passwordConfirmController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _errorMessage = 'Please fill in all fields.';
      notifyListeners();
      return;
    }

    if (password != confirmPassword) {
      _errorMessage = 'Passwords do not match.';
      notifyListeners();
      return;
    }

    if (password.length < 6) {
      _errorMessage = 'Password must be at least 6 characters.';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await _authRepository.signUp(
        email: email,
        password: password,
        username: username,
      );
      // Sign back out so the user must log in manually.
      await _authRepository.signOut();
      _registrationSuccess = true;
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.code} - ${e.rawMessage}');
      _errorMessage = _friendlyError(e.code);
    } catch (e) {
      debugPrint('Unexpected register error: $e');
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _setLoading(false);
    }
  }

  /// Resets the registrationSuccess flag after navigation is handled.
  void resetRegistrationSuccess() {
    _registrationSuccess = false;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Maps domain-level auth error codes to user-facing messages.
  String _friendlyError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.emailAlreadyInUse:
        return 'This email is already registered.';
      case AuthErrorCode.invalidEmail:
        return 'Invalid email address.';
      case AuthErrorCode.weakPassword:
        return 'Password is too weak.';
      case AuthErrorCode.userNotFound:
      case AuthErrorCode.wrongPassword:
      case AuthErrorCode.userDisabled:
      case AuthErrorCode.invalidCredential:
      case AuthErrorCode.unknown:
        return 'Registration failed. Please try again.';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }
}
