import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/audio/ambient_music_service.dart';
import '../../../../core/audio/ambient_music_preference.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

class RegisterViewModel extends ChangeNotifier {
  static const Duration defaultRequestTimeout = Duration(seconds: 15);

  RegisterViewModel({
    AuthRepository? authRepository,
    Duration requestTimeout = defaultRequestTimeout,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _requestTimeout = requestTimeout;

  final AuthRepository _authRepository;
  final Duration _requestTimeout;

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

  bool _isMusicMuted = !AmbientMusicPreference.enabled;
  bool get isMusicMuted => _isMusicMuted;

  final AmbientMusicService _musicService = AmbientMusicService.instance;

  Future<void> initMusic() async {
    _isMusicMuted = !AmbientMusicPreference.enabled;
    if (!_isMusicMuted) {
      await _musicService.ensurePlaying();
    }
    notifyListeners();
  }

  Future<void> register() async {
    if (_isLoading) return;

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
      await _authRepository
          .signUp(email: email, password: password, username: username)
          .timeout(_requestTimeout);
      await _authRepository.signOut().timeout(_requestTimeout);
      _registrationSuccess = true;
    } on AuthException catch (e) {
      debugPrint('Auth error: ${e.code} - ${e.rawMessage}');
      _errorMessage = _friendlyError(e.code);
    } on TimeoutException {
      _errorMessage =
          'Connection timed out. Please check your internet connection.';
    } catch (e) {
      debugPrint('Unexpected register error: $e');
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void resetRegistrationSuccess() {
    _registrationSuccess = false;
  }

  void toggleMusic() {
    _isMusicMuted = !_isMusicMuted;
    unawaited(_musicService.setEnabled(!_isMusicMuted));
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

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
      case AuthErrorCode.networkRequestFailed:
        return 'No internet connection. Please check your connection.';
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
