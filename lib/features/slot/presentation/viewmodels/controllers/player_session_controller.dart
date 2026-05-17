import 'dart:async';

import 'package:flutter/foundation.dart';

class PlayerSessionController extends ChangeNotifier {
  String _username = 'Loading...';
  String get username => _username;

  String _email = 'Loading...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  void applyUserData(Map<String, dynamic>? userData) {
    if (userData == null) {
      _username = 'Unknown';
      _email = 'Unknown';
      return;
    }

    _username = userData['username'] ?? 'Player';
    _email = userData['email'] ?? 'No Email';
  }

  void markError() {
    _username = 'Error';
    _email = 'Error';
  }

  void finishLoading() {
    _isLoading = false;
  }

  void listenToUserBalance({
    required Stream<Map<String, dynamic>?> stream,
    required ValueChanged<double> onBalanceChanged,
  }) {
    _userSubscription?.cancel();
    _userSubscription = stream.listen((data) {
      if (data == null || !data.containsKey('userBalance')) return;
      final value = data['userBalance'];
      onBalanceChanged(value is num ? value.toDouble() : 10000.0);
    });
  }

  Future<void> signOut({
    required Future<void> Function() forceSave,
    required Future<void> Function() signOut,
  }) async {
    await forceSave();
    await _userSubscription?.cancel();
    _userSubscription = null;
    await signOut();
    _loggedOut = true;
  }

  void resetLoggedOut() {
    _loggedOut = false;
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
