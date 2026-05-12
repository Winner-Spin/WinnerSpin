import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/widgets/animated_image_button.dart';
import '../viewmodels/register_viewmodel.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final RegisterViewModel _viewModel = RegisterViewModel();

  late final AnimationController _errorPulseCtrl;
  late final Animation<double> _errorPulseScale;
  Timer? _errorClearTimer;
  String? _lastShownError;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
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
    _handleRegistrationSuccess(context);
    // One-shot grow on appearance — mirrors the login screen.
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
    _viewModel.dispose();
    super.dispose();
  }

  /// Maps a viewmodel error message to its corresponding badge
  /// image. Returns null for errors that don't have a dedicated
  /// image — those stay silent on the new flow (the SnackBar that
  /// used to surface them is gone).
  String? _errorImageFor(String error) {
    if (error.contains('fill in all fields')) {
      return 'lib/images/register_screen/empty_fields.png';
    }
    if (error.contains('do not match')) {
      return 'lib/images/register_screen/password_dont_match.png';
    }
    if (error.contains('at least 6 characters') ||
        error.contains('too weak')) {
      return 'lib/images/register_screen/min_6_characters.png';
    }
    if (error.contains('Invalid email')) {
      return 'lib/images/register_screen/invalid_email_adress.png';
    }
    return null;
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
                  Positioned.fill(
                    child: Image.asset(
                      'lib/images/register_screen/register.png',
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.07,
                    right: screenW * 0.07,
                    child: AnimatedImageButton(
                      imagePath: 'lib/images/register_screen/music_button.png',
                      width: 46,
                      onTap: () {
                        // TODO: Toggle music
                      },
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.34,
                    left: screenW * 0.13,
                    right: screenW * 0.13,
                    child: _buildCustomTextField(
                      context: context,
                      controller: _viewModel.nameController,
                      icon: Icons.star,
                      hint: 'Username',
                      backgroundImage:
                          'lib/images/register_screen/Ad_Soyad_button.png',
                      leadingSpace: 64,
                      contentPadding: const EdgeInsets.only(top: 4),
                      backgroundScaleY: 1.58,
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.43,
                    left: screenW * 0.13,
                    right: screenW * 0.13,
                    child: _buildCustomTextField(
                      context: context,
                      controller: _viewModel.emailController,
                      icon: Icons.email,
                      hint: 'Email',
                      backgroundImage:
                          'lib/images/register_screen/email_button1_cropped.png',
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.52,
                    left: screenW * 0.13,
                    right: screenW * 0.13,
                    child: _buildCustomTextField(
                      context: context,
                      controller: _viewModel.passwordController,
                      icon: Icons.lock,
                      hint: 'Password',
                      obscureText: true,
                      backgroundImage:
                          'lib/images/register_screen/password_button_cropped.png',
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.61,
                    left: screenW * 0.13,
                    right: screenW * 0.13,
                    child: _buildCustomTextField(
                      context: context,
                      controller: _viewModel.passwordConfirmController,
                      icon: Icons.lock_outline,
                      hint: 'Confirm Password',
                      obscureText: true,
                      backgroundImage:
                          'lib/images/register_screen/password_button_cropped.png',
                    ),
                  ),

                  // Register button stays mounted while the auth
                  // request is in flight so the layout doesn't reflow
                  // under the player. Taps are swallowed by the
                  // disabled wrapper while loading and a small
                  // spinner overlays the button.
                  Positioned(
                    top: screenH * 0.71,
                    left: screenW * 0.21,
                    right: screenW * 0.21,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Opacity(
                            opacity: _viewModel.isLoading ? 0.7 : 1.0,
                            child: AbsorbPointer(
                              absorbing: _viewModel.isLoading,
                              child: _buildKayitButton(
                                onTap: () {
                                  _viewModel.register();
                                },
                              ),
                            ),
                          ),
                          if (_viewModel.isLoading)
                            const SizedBox(
                              width: 28,
                              height: 27,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    bottom: screenH * 0.12,
                    left: screenW * 0.15,
                    right: screenW * 0.15,
                    child: Center(
                      child: AnimatedImageButton(
                        imagePath: 'lib/images/register_screen/image.png',
                        width: 250,
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Inline error indicator sitting just below the
                  // confirm password field, with enough headroom
                  // above the register button so the badge never
                  // sits on top of it. Replaces the old SnackBar
                  // with one of four campaign-art badges depending
                  // on which validation failed.
                  if (_viewModel.errorMessage != null &&
                      _errorImageFor(_viewModel.errorMessage!) != null)
                    Positioned(
                      bottom: screenH * 0.27,
                      left: screenW * 0.18,
                      right: screenW * 0.18,
                      child: IgnorePointer(
                        child: Center(
                          child: ScaleTransition(
                            scale: _errorPulseScale,
                            child: Image.asset(
                              _errorImageFor(_viewModel.errorMessage!)!,
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
          );
        },
      ),
    );
  }

  // ─── NAVIGATION (View responsibility) ───────────────────────

  void _handleRegistrationSuccess(BuildContext context) {
    if (!mounted) return;
    if (_viewModel.registrationSuccess) {
      _viewModel.resetRegistrationSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration successful! Please log in.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  // ─── ERROR HANDLING ──────────────────────────────────────────

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
    double leadingSpace = 64,
    EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
    double backgroundScaleY = 1,
  }) {
    final fieldContent = Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(width: leadingSpace),
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
                contentPadding: contentPadding,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );

    if (backgroundScaleY == 1) {
      return Container(
        height: 60,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(backgroundImage),
            fit: BoxFit.fill,
          ),
        ),
        child: fieldContent,
      );
    }

    return SizedBox(
      height: 60,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: Transform.scale(
                scaleY: backgroundScaleY,
                child: Image.asset(
                  backgroundImage,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
            Positioned.fill(child: fieldContent),
          ],
        ),
      ),
    );
  }

  Widget _buildKayitButton({required VoidCallback onTap}) {
    return AnimatedImageButton(
      imagePath: 'lib/images/register_screen/register_button_clean.png',
      width: 235,
      onTap: onTap,
    );
  }
}
