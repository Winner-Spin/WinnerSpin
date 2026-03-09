import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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

              // Top Right Action Buttons (Music & Settings)
              Positioned(
                top: screenH * 0.05,
                right: screenW * 0.05,
                child: Row(
                  children: [
                    _buildActionButton(Icons.music_note_rounded, () {
                      // TODO: Toggle music
                    }),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.settings_rounded, () {
                      // TODO: Open settings
                    }),
                  ],
                ),
              ),

              // Email Input Field
              Positioned(
                top: screenH * 0.48, // approximate position of email field
                left: screenW * 0.15,
                right: screenW * 0.15,
                child: _buildCustomTextField(
                  context: context,
                  controller: _emailController,
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
                  controller: _passwordController,
                  icon: Icons.lock,
                  hint: 'Password',
                  obscureText: true,
                  backgroundImage:
                      'lib/images/login_screen/password_button_cropped.png',
                ),
              ),

              // Login Button
              Positioned(
                top: screenH * 0.70, // lower position
                left: screenW * 0.25,
                right: screenW * 0.25,
                child: Center(child: _buildLoginButton()),
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

  /// Candy-style LOGIN button — matches the dark green ribbon reference image.
  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: () {
        // TODO: Handle login
      },
      child: Container(
        width: 180,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          // Outer glow border
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF1E8A0E,
              ).withValues(alpha: 0.6), // dark green shadow
              blurRadius: 18,
              spreadRadius: 2,
            ),
            BoxShadow(
              color: const Color(
                0xFF65D212,
              ).withValues(alpha: 0.3), // light green glow
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
          // Dark to light green gradient matching the ribbon
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF6AE115), // bright slightly yellowish green (top center)
              Color(0xFF33A90A), // mid green
              Color(0xFF167204), // dark rich green (bottom)
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          border: Border.all(
            color: const Color(
              0xFF8CF628,
            ), // bright yellow-green highlight edge
            width: 2.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.hardEdge, // ensure stars don't bleed out
          children: [
            // --- Starry Background Effect ---
            // Randomly distributed small glowing dots to simulate stars matching the ribbon
            // Some sizes increased for more prominent visual impact
            Positioned(
              top: 8,
              left: 20,
              child: _buildStar(6, Colors.white.withValues(alpha: 0.9)),
            ), // Big star
            Positioned(
              top: 25,
              left: 45,
              child: _buildStar(2, Colors.white.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 15,
              left: 90,
              child: _buildStar(5, Colors.yellowAccent.withValues(alpha: 0.8)),
            ), // Big star
            Positioned(
              top: 40,
              left: 30,
              child: _buildStar(3, Colors.white.withValues(alpha: 0.6)),
            ),
            Positioned(
              top: 5,
              right: 35,
              child: _buildStar(4, Colors.white.withValues(alpha: 0.9)),
            ),
            Positioned(
              top: 35,
              right: 18,
              child: _buildStar(
                6.5,
                Colors.yellowAccent.withValues(alpha: 0.9),
              ),
            ), // Big star
            Positioned(
              top: 20,
              right: 70,
              child: _buildStar(2, Colors.white.withValues(alpha: 0.5)),
            ),
            Positioned(
              top: 45,
              right: 55,
              child: _buildStar(4.5, Colors.white.withValues(alpha: 0.8)),
            ), // Med-big
            Positioned(
              top: 30,
              left: 130,
              child: _buildStar(2.5, Colors.white.withValues(alpha: 0.6)),
            ),

            // Glossy highlight on top half
            Positioned(
              top: 2,
              left: 10,
              right: 10,
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withValues(alpha: 0.45),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // LOGIN text with shadow / stroke effect
            Text(
              'LOGIN',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 3
                  ..color = const Color(0xFF0F4D02), // very dark green outline
              ),
            ),
            const Text(
              'LOGIN',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: Color(0xFFFFFF44), // yellow text
                shadows: [
                  Shadow(
                    color: Colors.black45,
                    offset: Offset(0, 2),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper widget to draw a tiny glowing star dot
  Widget _buildStar(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 2.0,
            spreadRadius: size * 0.5,
          ),
        ],
      ),
    );
  }

  /// Candy-style Action Button (for Music and Settings)
  Widget _buildActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFC7106D), // Outer darker pink edge
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 5,
              offset: const Offset(0, 3), // Bottom shadow
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(2.5), // Outer border width
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFFFD54F), // Yellow/amber inner rim
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5), // Yellow rim width
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFF72C0), // Bright pink top
                  Color(0xFFE81389), // Deep pink bottom
                ],
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 26,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(
                    alpha: 0.5,
                  ), // Gölge belirginleştirildi
                  offset: const Offset(0, 2), // Gölge konumu değiştirildi
                  blurRadius: 4, // Bulanıklık artırıldı
                ),
                Shadow(
                  color: Colors.black.withValues(
                    alpha: 0.3,
                  ), // Ek aydınlık için ikinci gölge
                  offset: const Offset(0, -1),
                  blurRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // End of _LoginScreenState
