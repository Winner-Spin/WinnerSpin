import 'package:flutter/material.dart';
<<<<<<< Updated upstream
import 'package:google_fonts/google_fonts.dart';
import 'viewmodels/login_viewmodel.dart'; // Import the ViewModel
=======
import 'viewmodels/login_viewmodel.dart';
>>>>>>> Stashed changes

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Instantiate the ViewModel
  final LoginViewModel _viewModel = LoginViewModel();

  @override
  void dispose() {
    // Dispose the ViewModel to free resources
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
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

              // Action Button: Music (Placed at the home icon's position - rightmost)
              Positioned(
                top: screenH * 0.125, // Height just above the logo in the reference
                right: screenW * 0.07, // Position of the rightmost Home icon in the 3-button group
                child: AnimatedImageButton(
                  imagePath: 'lib/images/login_screen/music_button.png',
                  width: 46,
                  onTap: () {
                    _viewModel.toggleMusic();
                  },
                ),
              ),

              // Email Input Field
              Positioned(
                top: screenH * 0.48, // approximate position of email field
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
                top: screenH * 0.58, // lower position for password field
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

              // Login Button
              Positioned(
                top: screenH * 0.70,
                left: screenW * 0.25,
                right: screenW * 0.25,
                child: Center(
                  child: AnimatedImageButton(
                    imagePath: 'lib/images/login_screen/login_button_final.png',
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
                    imagePath: 'lib/images/login_screen/signup_button_final.png',
                    width: 250,
                    onTap: () {
<<<<<<< Updated upstream
                      _viewModel.navigateToSignUp();
=======
                      _viewModel.navigateToSignUp(context);
>>>>>>> Stashed changes
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

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
              style: GoogleFonts.baloo2(
                textStyle: const TextStyle(
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
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.baloo2(
                  textStyle: const TextStyle(
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



} // End of _LoginScreenState

/// Custom Image Button with Scale Animation
class AnimatedImageButton extends StatefulWidget {
  final VoidCallback onTap;
  final String imagePath;
  final double width;

  const AnimatedImageButton({
    super.key,
    required this.onTap,
    required this.imagePath,
    required this.width,
  });

  @override
  State<AnimatedImageButton> createState() => _AnimatedImageButtonState();
}

class _AnimatedImageButtonState extends State<AnimatedImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100), // Press speed
      reverseDuration: const Duration(milliseconds: 100), // Release speed
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Image.asset(
          widget.imagePath,
          width: widget.width, // Set scale width via parameter
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
