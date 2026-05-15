import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/audio/ambient_music_preference.dart';
import '../../../../core/audio/app_audio_context.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/firebase_auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  static final LoginViewModel _instance = LoginViewModel._internal();
  factory LoginViewModel() => _instance;
  LoginViewModel._internal() : _authRepository = FirebaseAuthRepository();

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

  bool _isMusicMuted = !AmbientMusicPreference.enabled;
  bool get isMusicMuted => _isMusicMuted;

  bool _isMusicInitialized = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  void initMusic() async {
    if (_isMusicInitialized) {
      _isMusicMuted = !AmbientMusicPreference.enabled;
      if (_isMusicMuted) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.resume();
      }
      notifyListeners();
      return;
    }
    _isMusicInitialized = true;

    await _audioPlayer.setAudioContext(AppAudioContext.game);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    if (AmbientMusicPreference.enabled) {
      await _audioPlayer.play(AssetSource('audio/Items/Basin_of_Light.mp3'));
    }
    _isMusicMuted = !AmbientMusicPreference.enabled;
    notifyListeners();
  }

  Future<void> login() async {
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

  void resetLoginSuccess() {
    _loginSuccess = false;
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  void toggleMusic() {
    _isMusicMuted = !_isMusicMuted;
    AmbientMusicPreference.enabled = !_isMusicMuted;
    if (_isMusicMuted) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
    notifyListeners();
  }

  Future<void> onNavigatingAway() async {
    if (!_isMusicMuted) {
      await _audioPlayer.pause();
    }
  }

  Future<void> onReturned() async {
    if (!_isMusicMuted) {
      await _audioPlayer.resume();
    }
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
    }
  }
}
