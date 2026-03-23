import 'package:flutter/material.dart';
import '../viewmodels/game_viewmodel.dart';
import 'login_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameViewModel _viewModel = GameViewModel();

  @override
  void initState() {
    super.initState();
    _viewModel.fetchUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: AnimatedBuilder(
        animation: _viewModel,
        builder: (context, child) {
          // Handle logout navigation
          _handleLogout(context);

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🎰 Winner Spin 🎰',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Display User Info from Firestore
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _viewModel.isLoading
                      ? const CircularProgressIndicator(
                          color: Colors.amberAccent)
                      : Column(
                          children: [
                            Text(
                              'Hoş geldin, ${_viewModel.username}!',
                              style: const TextStyle(
                                color: Colors.amberAccent,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _viewModel.email,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                ),

                const SizedBox(height: 40),
                ElevatedButton.icon(
                  onPressed: () {
                    _viewModel.signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'Çıkış Yap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── NAVIGATION (View responsibility) ───────────────────────

  void _handleLogout(BuildContext context) {
    if (_viewModel.loggedOut) {
      _viewModel.resetLoggedOut();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const LoginScreen(),
            ),
          );
        }
      });
    }
  }
}
