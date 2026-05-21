import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/audio/ambient_music_preference.dart';
import '../../../../core/audio/app_audio_context.dart';
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

  bool _isMusicMuted = !AmbientMusicPreference.enabled;
  bool get isMusicMuted => _isMusicMuted;

  bool _isMusicInitialized = false;
  bool _hasStartedMusic = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> initMusic() async {
    if (_isMusicInitialized) {
      _isMusicMuted = !AmbientMusicPreference.enabled;
      if (_isMusicMuted) {
        await _audioPlayer.pause();
      } else {
        await _playOrResumeMusic();
      }
      notifyListeners();
      return;
    }

    _isMusicInitialized = true;
    await _audioPlayer.setAudioContext(AppAudioContext.game);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);

    if (AmbientMusicPreference.enabled) {
      await _playOrResumeMusic();
    }

    _isMusicMuted = !AmbientMusicPreference.enabled;
    notifyListeners();
  }

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
    AmbientMusicPreference.enabled = !_isMusicMuted;
    if (_isMusicMuted) {
      _audioPlayer.pause();
    } else {
      _playOrResumeMusic();
    }
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
    }
  }

  Future<void> _playOrResumeMusic() async {
    if (_hasStartedMusic) {
      await _audioPlayer.resume();
      return;
    }
    _hasStartedMusic = true;
    await _audioPlayer.play(AssetSource('audio/Items/Basin_of_Light.mp3'));
  }

  @override
  void dispose() {
    unawaited(_audioPlayer.dispose());
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }
}
