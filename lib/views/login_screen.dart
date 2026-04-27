import 'package:flutter/material.dart';
import '../viewmodels/login_viewmodel.dart';
import '../widgets/animated_image_button.dart';
import 'register_screen.dart';
import 'game_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LoginViewModel _viewModel = LoginViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.initMusic();
  }

  void _onViewModelChange() {
    _showErrorIfNeeded(context);
    _handleLoginSuccess(context);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    // We no longer dispose the view model because it is a singleton
    // and audio needs to be kept alive.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final double screenH = constraints.maxHeight;
              final double screenW = constraints.maxWidth;

          return Stack(
            children: [
              // Background
              Positioned.fill(
                child: Image.asset(
                  'lib/images/login_screen/background_1.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // Music Button
              Positioned(
                top: screenH * 0.125,
                right: screenW * 0.07,
                child: AnimatedImageButton(
                  imagePath: 'lib/images/login_screen/music_button.png',
                  width: 46,
                  isStrikeThrough: _viewModel.isMusicMuted,
                  onTap: () {
                    _viewModel.toggleMusic();
                  },
                ),
              ),

              // Email Input Field
              Positioned(
                top: screenH * 0.48,
                left: screenW * 0.15,
                right: screenW * 0.15,
                child: _buildCustomTextField(
                  context: context,
                  controller: _viewModel.emailController,
                  icon: Icons.email,
                  hint: 'Email',
                  backgroundImage:
                      'lib/images/login_screen/email_button1_cropped.png',
                ),
              ),

              // Password Input Field
              Positioned(
                top: screenH * 0.58,
                left: screenW * 0.15,
                right: screenW * 0.15,
                child: _buildCustomTextField(
                  context: context,
                  controller: _viewModel.passwordController,
                  icon: Icons.lock,
                  hint: 'Password',
                  obscureText: true,
                  backgroundImage:
                      'lib/images/login_screen/password_button_cropped.png',
                ),
              ),

              // Login Button (or loading spinner)
              Positioned(
                top: screenH * 0.70,
                left: screenW * 0.25,
                right: screenW * 0.25,
                child: Center(
                  child: _viewModel.isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                        )
                      : AnimatedImageButton(
                          imagePath:
                              'lib/images/login_screen/login_button_final.png',
                          width: 180,
                          onTap: () {
                            _viewModel.login();
                          },
                        ),
                ),
              ),

              // Sign Up Button
              Positioned(
                bottom: screenH * 0.165,
                left: screenW * 0.10,
                right: screenW * 0.10,
                child: Center(
                  child: AnimatedImageButton(
                    imagePath:
                        'lib/images/login_screen/signup_button_final.png',
                    width: 250,
                    onTap: () => _navigateToSignUp(context),
                  ),
                ),
              ),
            ],
          );
        },
      ); // LayoutBuilder
     },
    ), // AnimatedBuilder
   ); // Scaffold
  }

  // ─── NAVIGATION (View responsibility) ───────────────────────

  void _handleLoginSuccess(BuildContext context) {
    if (!mounted) return;
    if (_viewModel.loginSuccess) {
      _viewModel.resetLoginSuccess();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GameScreen()),
      );
    }
  }

  Future<void> _navigateToSignUp(BuildContext context) async {
    final navigator = Navigator.of(context);

    // Pause music before navigating
    await _viewModel.onNavigatingAway();

    await navigator.push(
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );

    // Resume music when returning
    await _viewModel.onReturned();
  }

  // ─── ERROR HANDLING ──────────────────────────────────────────

  String? _lastShownError;

  void _showErrorIfNeeded(BuildContext context) {
    if (!mounted) return;
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─── HELPERS ─────────────────────────────────────────────────

  Widget _buildCustomTextField({
    required BuildContext context,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    required String backgroundImage,
    bool obscureText = false,
  }) {
    return Container(
      height: 60,
      padding: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage(backgroundImage),
          fit: BoxFit.fill,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 64),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscureText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  color: Colors.white70,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black45,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}
