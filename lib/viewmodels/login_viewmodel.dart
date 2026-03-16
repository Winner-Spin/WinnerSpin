import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../register_screen.dart';

class LoginViewModel extends ChangeNotifier {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isMusicMuted = false;
  bool get isMusicMuted => _isMusicMuted;

  final AudioPlayer _audioPlayer = AudioPlayer();

  void initMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Use AssetSource for local assets from the `assets` folder
    await _audioPlayer.play(AssetSource('audio/bg_music.mp3'));
    _isMusicMuted = false;
    notifyListeners();
  }

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

  void navigateToSignUp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void toggleMusic() {
    _isMusicMuted = !_isMusicMuted;
    if (_isMusicMuted) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.resume();
    }
    print("Toggling Music. Muted: $_isMusicMuted");
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
