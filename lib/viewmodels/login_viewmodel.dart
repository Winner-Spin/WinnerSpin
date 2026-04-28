import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../repositories/auth_repository.dart';
import '../repositories/firebase_auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  // Singleton pattern — production-only single instance.
  static final LoginViewModel _instance = LoginViewModel._internal();
  factory LoginViewModel() => _instance;
  LoginViewModel._internal() : _authRepository = FirebaseAuthRepository();

  /// Test-only constructor — lets tests inject a mock repository.
  @visibleForTesting
  LoginViewModel.withRepository(this._authRepository);

  final AuthRepository _authRepository;

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _loginSuccess = false;
  bool get loginSuccess => _loginSuccess;

  bool _isMusicMuted = false;
  bool get isMusicMuted => _isMusicMuted;

  bool _isMusicInitialized = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  void initMusic() async {
    if (_isMusicInitialized) return;
    _isMusicInitialized = true;
    
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/bg_music.mp3'));
    _isMusicMuted = false;
    notifyListeners();
  }

  // ─── LOGIN ─────────────────────────────────────────────────

  Future<void> login() async {
    // Clear previous state
    _errorMessage = null;
    _loginSuccess = false;

    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _errorMessage = 'Please enter email and password.';
      notifyListeners();
      return;
    }

    _setLoading(true);

    try {
      await _authRepository.signIn(
        email: emailController.text,
        password: passwordController.text,
      );

      // Login successful
      _errorMessage = null;
      emailController.clear();
      passwordController.clear();
      _loginSuccess = true;
    } on AuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  /// Resets the loginSuccess flag after navigation is handled.
  void resetLoginSuccess() {
    _loginSuccess = false;
  }

  // ─── MUSIC ─────────────────────────────────────────────────

  void toggleMusic() {
    _isMusicMuted = !_isMusicMuted;
    if (_isMusicMuted) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
    notifyListeners();
  }

  /// Pauses music when navigating away from the login screen.
  Future<void> onNavigatingAway() async {
    if (!_isMusicMuted) {
      await _audioPlayer.pause();
    }
  }

  /// Resumes music when returning to the login screen.
  Future<void> onReturned() async {
    if (!_isMusicMuted) {
      await _audioPlayer.resume();
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Maps domain-level auth error codes to user-facing messages.
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
    }
  }
}
