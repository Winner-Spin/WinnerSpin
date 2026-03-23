import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/auth_service.dart';

class LoginViewModel extends ChangeNotifier {
  // Singleton pattern
  static final LoginViewModel _instance = LoginViewModel._internal();
  factory LoginViewModel() => _instance;
  LoginViewModel._internal();

  final AuthService _authService = AuthService();

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
      await _authService.signIn(
        email: emailController.text,
        password: passwordController.text,
      );

      // Login successful
      _errorMessage = null;
      emailController.clear();
      passwordController.clear();
      _loginSuccess = true;
    } on FirebaseAuthException catch (e) {
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

  /// Converts Firebase error codes to user-friendly messages.
  String _friendlyError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Login failed. Please try again.';
    }
  }
}
