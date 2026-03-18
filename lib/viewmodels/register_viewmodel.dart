import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── REGISTER ──────────────────────────────────────────────

  /// Validates inputs, calls AuthService.signUp, and navigates
  /// back to the login screen on success.
  Future<void> register(BuildContext context) async {
    // Clear any previous error
    _errorMessage = null;

    // ── Validation ──
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

    // ── Firebase sign-up ──
    _setLoading(true);

    try {
      await _authService.signUp(
        email: email,
        password: password,
        username: username,
      );

      // Sign out so user must log in manually
      await _authService.signOut();

      // Success — go to login screen
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔥 FirebaseAuthException: ${e.code} - ${e.message}');
      _errorMessage = _friendlyError(e.code);
    } on FirebaseException catch (e) {
      debugPrint('🔥 FirebaseException: ${e.code} - ${e.message}');
      _errorMessage = _friendlyFirestoreError(e.code);
    } catch (e) {
      debugPrint('🔥 Unexpected error: $e');
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _setLoading(false);
    }
  }

  // ─── HELPERS ───────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Converts Firebase Auth error codes to user-friendly messages.
  String _friendlyError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      default:
        return 'Registration failed ($code). Please try again.';
    }
  }

  /// Converts Firestore error codes to user-friendly messages.
  String _friendlyFirestoreError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Database permission denied. Please contact support.';
      case 'unavailable':
        return 'Service is temporarily unavailable. Try again later.';
      default:
        return 'Database error ($code). Please try again.';
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    passwordConfirmController.dispose();
    super.dispose();
  }
}
