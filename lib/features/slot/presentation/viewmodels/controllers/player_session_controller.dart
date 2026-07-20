import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/models/symbol_registry.dart';

class PlayerSessionController extends ChangeNotifier {
  String _username = 'Loading...';
  String get username => _username;

  String _email = 'Loading...';
  String get email => _email;

  String _profileAvatarId = SymbolRegistry.defaultProfileAvatarId;
  String get profileAvatarId => _profileAvatarId;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  void applyUserData(Map<String, dynamic>? userData) {
    if (userData == null) {
      _username = 'Unknown';
      _email = 'Unknown';
      _profileAvatarId = SymbolRegistry.defaultProfileAvatarId;
      return;
    }

    _username = userData['username'] ?? 'Player';
    _email = userData['email'] ?? 'No Email';
    final storedAvatarId = userData['profileAvatarId'];
    _profileAvatarId =
        storedAvatarId is String &&
            SymbolRegistry.isProfileAvatar(storedAvatarId)
        ? storedAvatarId
        : SymbolRegistry.defaultProfileAvatarId;
  }

  void setProfileAvatarId(String avatarId) {
    if (_profileAvatarId == avatarId) return;
    _profileAvatarId = avatarId;
    notifyListeners();
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

  Future<void> deleteAccount({
    required Future<void> Function() deleteAccount,
  }) async {
    await _userSubscription?.cancel();
    _userSubscription = null;
    await deleteAccount();
    _loggedOut = true;
  }

  Future<void> markSessionExpired() async {
    await _userSubscription?.cancel();
    _userSubscription = null;
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
