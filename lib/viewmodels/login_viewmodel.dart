import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../register_screen.dart';
import '../services/auth_service.dart';
import '../game_screen.dart';

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

  bool _isMusicMuted = false;
  bool get isMusicMuted => _isMusicMuted;

  bool _isMusicInitialized = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  void initMusic() async {
    if (_isMusicInitialized) return;
    _isMusicInitialized = true;
    
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Use AssetSource for local assets from the `assets` folder
    await _audioPlayer.play(AssetSource('audio/bg_music.mp3'));
    _isMusicMuted = false;
    notifyListeners();
  }

  // ─── LOGIN ─────────────────────────────────────────────────

  Future<void> login(BuildContext context) async {
    // Clear previous error
    _errorMessage = null;

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

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const GameScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _friendlyError(e.code);
    } catch (e) {
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      _setLoading(false);
    }
  }

  // ─── NAVIGATION ────────────────────────────────────────────

  void navigateToSignUp(BuildContext context) async {
    // Pause music before navigating
    if (!_isMusicMuted) {
      await _audioPlayer.pause();
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );

    // Resume music when returning (if it wasn't muted)
    if (!_isMusicMuted) {
      await _audioPlayer.resume();
    }
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

  // We no longer dispose the audio player since it's a singleton
  // and needs to survive across screen re-visits.
}
