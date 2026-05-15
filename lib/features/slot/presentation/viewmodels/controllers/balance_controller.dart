import 'package:flutter/foundation.dart';

import '../../../domain/engine/slot_engine.dart';

class BalanceController extends ChangeNotifier {
  static const List<double> _betTiers = [
    10,
    20,
    30,
    40,
    50,
    75,
    100,
    200,
    500,
    750,
    1000,
    1500,
    2000,
    2500,
    3000,
    3500,
    4000,
    4500,
    5000,
  ];
  static const double _defaultBalance = 10000.0;

  double _balance = _defaultBalance;
  double _userBalance = _defaultBalance;
  double _betAmount = 100.0;
  double _lastWin = 0.0;
  bool _anteBetActive = false;

  double get balance => _balance;

  double get userBalance => _userBalance;

  double get betAmount => _betAmount;
  double get lastWin => _lastWin;

  bool get canDecreaseBet => _betAmount > _betTiers.first;
  bool get canIncreaseBet => _betAmount < _betTiers.last;

  double get effectiveBetCost =>
      _anteBetActive ? _betAmount * 1.25 : _betAmount;

  double get anteCost => _betAmount * 1.25;

  double get buyFeaturePrice =>
      _betAmount * SlotEngine.buyFeaturePriceMultiplier;

  // ignore: avoid_setters_without_getters
  set anteActiveShadow(bool value) {
    if (_anteBetActive == value) return;
    _anteBetActive = value;
    notifyListeners();
  }

  void hydrate(Map<String, dynamic> userData) {
    final seed = (userData['userBalance'] ?? _defaultBalance).toDouble();
    _balance = seed;
    _userBalance = seed;
    notifyListeners();
  }

  void applyRemoteUserBalance(double remoteValue) {
    if (_userBalance == remoteValue) return;
    _userBalance = remoteValue;
    _balance = remoteValue;
    notifyListeners();
  }

  void resetLastWin() {
    if (_lastWin == 0.0) return;
    _lastWin = 0.0;
    notifyListeners();
  }

  bool canAfford(double cost) => _userBalance >= cost;

  bool canAffordDisplayed(double cost) => _balance >= cost;

  void charge(double amount) {
    _balance = (_balance - amount).clamp(0.0, double.infinity);
    _userBalance = (_userBalance - amount).clamp(0.0, double.infinity);
    notifyListeners();
  }

  void awardWin(double amount) {
    _lastWin = amount;
    _balance += amount;
    _userBalance += amount;
    notifyListeners();
  }

  void depositGameMoney(double amount) {
    if (amount <= 0) return;
    _balance += amount;
    _userBalance += amount;
    notifyListeners();
  }

  bool increaseBet() {
    final idx = _currentTierIndex();
    if (idx >= _betTiers.length - 1) return false;
    _betAmount = _betTiers[idx + 1];
    notifyListeners();
    return true;
  }

  bool decreaseBet() {
    final idx = _currentTierIndex();
    if (idx <= 0) return false;
    _betAmount = _betTiers[idx - 1];
    notifyListeners();
    return true;
  }

  int _currentTierIndex() {
    for (var i = 0; i < _betTiers.length; i++) {
      if (_betTiers[i] >= _betAmount) return i;
    }
    return _betTiers.length - 1;
  }
}
