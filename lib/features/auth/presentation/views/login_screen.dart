import 'dart:async';

import 'package:flutter/material.dart';
import '../viewmodels/login_viewmodel.dart';
import '../../../../core/widgets/animated_image_button.dart';
import 'register_screen.dart';
import '../../../slot/presentation/views/game_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final LoginViewModel _viewModel = LoginViewModel();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.initMusic();
    _errorPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _errorPulseScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _errorPulseCtrl, curve: Curves.easeOutBack),
    );
  }

  void _onViewModelChange() {
    _showErrorIfNeeded(context);
    _handleLoginSuccess(context);
    // One-shot grow on appearance: the image scales up from a small
    // start to its full size and stays there. The controller's value
    // resets to 0 when the message clears so the next error re-plays
    // the grow from scratch.
    final hasError = _viewModel.errorMessage != null;
    if (hasError && _errorPulseCtrl.value == 0) {
      _errorPulseCtrl.forward(from: 0);
    } else if (!hasError && _errorPulseCtrl.value != 0) {
      _errorPulseCtrl.value = 0;
    }
  }

  @override
  void dispose() {
    _errorClearTimer?.cancel();
    _errorPulseCtrl.dispose();
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

              // Login Button — stays mounted while the auth request
              // is in flight so the layout doesn't reflow under the
              // player. Taps are swallowed by the disabled-state
              // wrapper while loading, and a small spinner overlays
              // the button to signal the request is still running.
              Positioned(
                top: screenH * 0.70,
                left: screenW * 0.25,
                right: screenW * 0.25,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: _viewModel.isLoading ? 0.7 : 1.0,
                        child: AbsorbPointer(
                          absorbing: _viewModel.isLoading,
                          child: AnimatedImageButton(
                            imagePath:
                                'lib/images/login_screen/login_button_final.png',
                            width: 180,
                            onTap: () {
                              _viewModel.login();
                            },
                          ),
                        ),
                      ),
                      if (_viewModel.isLoading)
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                    ],
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

              // Inline error indicator sitting in the gap between
              // the password field and the login button — replaces
              // the old SnackBar with the campaign-art badge and
              // plays a one-shot grow on appearance to draw the
              // player's eye.
              if (_viewModel.errorMessage != null)
                Positioned(
                  top: screenH * 0.62,
                  left: screenW * 0.18,
                  right: screenW * 0.18,
                  child: IgnorePointer(
                    child: Center(
                      child: ScaleTransition(
                        scale: _errorPulseScale,
                        child: Image.asset(
                          'lib/images/login_screen/invalid_error.png',
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                      ),
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
  Timer? _errorClearTimer;

  void _showErrorIfNeeded(BuildContext context) {
    if (!mounted) return;
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      _errorClearTimer?.cancel();
      _errorClearTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _viewModel.clearError();
        _lastShownError = null;
      });
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
