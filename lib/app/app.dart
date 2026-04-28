import 'package:flutter/material.dart';

import '../features/auth/data/repositories/firebase_auth_repository.dart';
import '../features/auth/presentation/views/login_screen.dart';
import '../features/slot/presentation/views/game_screen.dart';

/// Root application widget. Picks the start screen based on the current
/// auth session — game screen if signed in, login otherwise.
class WinnerSpinApp extends StatelessWidget {
  const WinnerSpinApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isSignedIn = FirebaseAuthRepository().currentUserId != null;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Winner Spin',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: isSignedIn ? const GameScreen() : const LoginScreen(),
    );
  }
}
