import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'viewmodels/register_viewmodel.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final RegisterViewModel _viewModel = RegisterViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          // Show error snackbar when errorMessage changes
          _showErrorIfNeeded(context);

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
                      imagePath:
                          'lib/images/register_screen/music_button.png',
                      width: 46,
                      onTap: () {
                        // TODO: Toggle music
                      },
                    ),
                  ),

                  Positioned(
                    top: screenH * 0.34,
                    left: screenW * 0.14,
                    right: screenW * 0.14,
                    child: _buildCustomTextField(
                      context: context,
                      controller: _viewModel.nameController,
                      icon: Icons.star,
                      hint: 'Username',
                      backgroundImage:
                          'lib/images/register_screen/ad_soyad_button_dark.png',
                      leadingSpace: 60,
                      contentPadding: const EdgeInsets.only(top: 4),
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

                  Positioned(
                    top: screenH * 0.71,
                    left: screenW * 0.21,
                    right: screenW * 0.21,
                    child: Center(
                      child: _viewModel.isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white,
                            )
                          : _buildKayitButton(
                              onTap: () {
                                _viewModel.register(context);
                              },
                            ),
                    ),
                  ),

                  Positioned(
                    bottom: screenH * 0.12,
                    left: screenW * 0.15,
                    right: screenW * 0.15,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(),
                          ),
                        );
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.pinkAccent, width: 2),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Already have an account? ',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Login!',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
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

  // ─── ERROR HANDLING ──────────────────────────────────────────

  String? _lastShownError;

  void _showErrorIfNeeded(BuildContext context) {
    final error = _viewModel.errorMessage;
    if (error != null && error != _lastShownError) {
      _lastShownError = error;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
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
  }

  Widget _buildKayitButton({required VoidCallback onTap}) {
    return AnimatedImageButton(
      imagePath: 'lib/images/register_screen/register_button_clean.png',
      width: 235,
      onTap: onTap,
    );
  }
}
