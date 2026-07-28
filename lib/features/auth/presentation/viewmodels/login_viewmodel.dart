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

  bool _verificationRequired = false;
  bool get verificationRequired => _verificationRequired;

  String? _verificationEmail;
  String? get verificationEmail => _verificationEmail;

  bool _isMusicMuted = !AmbientMusicPreference.enabled;
  bool get isMusicMuted => _isMusicMuted;

  bool _isSendingPasswordReset = false;
  bool get isSendingPasswordReset => _isSendingPasswordReset;

  String? _passwordResetMessage;
  String? get passwordResetMessage => _passwordResetMessage;

  bool _passwordResetFailed = false;
  bool get passwordResetFailed => _passwordResetFailed;

  /// Sends a reset link to [email] for someone who cannot sign in.
  ///
  /// Returns true when the request went through. The in-app flow's 24-hour
  /// limit does not apply here: it is recorded on the user's own document,
  /// which a signed-out caller can neither read nor write.
  Future<bool> sendPasswordReset(String email) async {
    if (_isSendingPasswordReset) return false;

    final address = email.trim();
    if (address.isEmpty || !address.contains('@')) {
      _passwordResetFailed = true;
      _passwordResetMessage = 'Enter the email address of your account.';
      notifyListeners();
      return false;
    }

    _isSendingPasswordReset = true;
    _passwordResetFailed = false;
    _passwordResetMessage = null;
    notifyListeners();

    try {
      await _authRepository
          .sendPasswordResetEmailForAddress(address)
          .timeout(_requestTimeout);
      _passwordResetFailed = false;
      // Deliberately conditional. With email enumeration protection on — the
      // Firebase default — an unknown address also reports success, so
      // promising that an email was sent would be a lie half the time.
      _passwordResetMessage =
          'If an account uses this address, a reset link is on its way. '
          'Check your spam folder if you do not see it. After changing your '
          'password, return to the app and sign in with the new one.';
      return true;
    } on AuthException catch (error) {
      _passwordResetFailed = true;
      _passwordResetMessage = _passwordResetError(error.code);
      return false;
    } catch (_) {
      _passwordResetFailed = true;
      _passwordResetMessage =
          'Reset email could not be sent. Please try again.';
      return false;
    } finally {
      _isSendingPasswordReset = false;
      notifyListeners();
    }
  }

  /// Reset-specific wording. Reusing the sign-in messages here put "Login
  /// failed" in a dialog that has nothing to do with signing in.
  String _passwordResetError(AuthErrorCode code) {
    switch (code) {
      case AuthErrorCode.userNotFound:
        return 'This email address is not registered.';
      case AuthErrorCode.invalidEmail:
        return 'Invalid email address.';
      case AuthErrorCode.userDisabled:
        return 'This account has been disabled.';
      case AuthErrorCode.networkRequestFailed:
        return 'No internet connection. Please check your connection.';
      case AuthErrorCode.wrongPassword:
      case AuthErrorCode.invalidCredential:
      case AuthErrorCode.emailAlreadyInUse:
      case AuthErrorCode.weakPassword:
      case AuthErrorCode.emailVerificationRequired:
      case AuthErrorCode.unknown:
        return 'Reset email could not be sent. Please try again.';
    }
  }

  void clearPasswordResetMessage() {
    if (_passwordResetMessage == null) return;
    _passwordResetMessage = null;
    _passwordResetFailed = false;
    notifyListeners();
  }

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
    _verificationRequired = false;
    _verificationEmail = null;

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
      if (e.code == AuthErrorCode.emailVerificationRequired) {
        _verificationEmail = e.rawMessage ?? emailController.text.trim();
        _verificationRequired = true;
        _errorMessage = null;
        _errorPresentation = LoginErrorPresentation.snackBar;
        return;
      }
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

  void resetVerificationRequired() {
    _verificationRequired = false;
    _verificationEmail = null;
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
      case AuthErrorCode.emailVerificationRequired:
        return 'Please verify your email to continue.';
    }
  }
}
