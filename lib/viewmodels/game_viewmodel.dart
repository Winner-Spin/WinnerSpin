import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GameViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  String _username = 'Yükleniyor...';
  String get username => _username;

  String _email = 'Yükleniyor...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ─── FETCH USER DATA ────────────────────────────────────────

  Future<void> fetchUserData() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;
          _username = data['username'] ?? 'Kullanıcı';
          _email = data['email'] ?? 'Email Yok';
        } else {
          _username = 'Bilinmiyor';
          _email = 'Bilinmiyor';
        }
      }
    } catch (e) {
      debugPrint('Firestore fetch error: $e');
      _username = 'Hata oluştu';
      _email = 'Hata oluştu';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── SIGN OUT ───────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    _loggedOut = true;
    notifyListeners();
  }

  /// Resets the loggedOut flag after navigation is handled.
  void resetLoggedOut() {
    _loggedOut = false;
  }
}
