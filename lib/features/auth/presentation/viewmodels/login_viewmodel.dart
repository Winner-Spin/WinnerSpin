import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/audio/ambient_music_service.dart';
import '../../../../core/audio/ambient_music_preference.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

enum LoginErrorPresentation { image, snackBar }

class LoginViewModel extends ChangeNotifier {
  static const Duration defaultRequestTimeout = Duration(seconds: 15);

  static final LoginViewModel _instance = LoginViewModel._internal();
  factory LoginViewModel() => _instance;
  LoginViewModel._internal()
    : _authRepository = FirebaseAuthRepository(),
      _requestTimeout = defaultRequestTimeout;

  @visibleForTesting
  LoginViewModel.withRepository(
    this._authRepository, {
    Duration requestTimeout = defaultRequestTimeout,
  }) : _requestTimeout = requestTimeout;

  final AuthRepository _authRepository;
  final Duration _requestTimeout;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  LoginErrorPresentation _errorPresentation = LoginErrorPresentation.image;
  LoginErrorPresentation get errorPresentation => _errorPresentation;

  bool _loginSuccess = false;
  bool get loginSuccess => _loginSuccess;

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

  Future<void> login() async {
    if (_isLoading) return;

    _errorMessage = null;
    _errorPresentation = LoginErrorPresentation.image;
    _loginSuccess = false;

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _errorMessage = 'Please enter email and password.';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await _authRepository
          .signIn(
            email: emailController.text,
            password: passwordController.text,
          )
          .timeout(_requestTimeout);

      _errorMessage = null;
      emailController.clear();
      passwordController.clear();
      _loginSuccess = true;
    } on AuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
      _errorPresentation = e.code == AuthErrorCode.networkRequestFailed
          ? LoginErrorPresentation.snackBar
          : LoginErrorPresentation.image;
    } on TimeoutException {
      _errorMessage =
          'Connection timed out. Please check your internet connection.';
      _errorPresentation = LoginErrorPresentation.snackBar;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
      _errorPresentation = LoginErrorPresentation.snackBar;
    } finally {
      _setLoading(false);
    }
  }

  void resetLoginSuccess() {
    _loginSuccess = false;
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    _errorPresentation = LoginErrorPresentation.image;
    notifyListeners();
  }

  void toggleMusic() {
    _isMusicMuted = !_isMusicMuted;
    unawaited(_musicService.setEnabled(!_isMusicMuted));
    notifyListeners();
  }

  Future<void> onReturned() async {
    _isMusicMuted = !AmbientMusicPreference.enabled;
    if (!_isMusicMuted) {
      await _musicService.ensurePlaying();
    }
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _friendlyError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.userNotFound:
        return 'No account found with this email.';
      case AuthErrorCode.wrongPassword:
        return 'Incorrect password.';
      case AuthErrorCode.invalidEmail:
        return 'Invalid email address.';
      case AuthErrorCode.userDisabled:
        return 'This account has been disabled.';
      case AuthErrorCode.invalidCredential:
        return 'Invalid email or password.';
      case AuthErrorCode.emailAlreadyInUse:
      case AuthErrorCode.weakPassword:
      case AuthErrorCode.unknown:
        return 'Login failed. Please try again.';
      case AuthErrorCode.networkRequestFailed:
        return 'No internet connection. Please check your connection.';
    }
  }
}
