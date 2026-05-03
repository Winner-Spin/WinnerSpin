import 'package:flutter/foundation.dart';

import '../../../domain/engine/slot_engine.dart';

/// Holds balance + bet state. Each mutator notifies listeners after the
/// write; setters short-circuit when the value is unchanged.
class BalanceController extends ChangeNotifier {
  static const List<double> _betTiers = [
    10, 20, 30, 40, 50, 75, 100, 200, 500, 750,
    1000, 1500, 2000, 2500, 3000, 3500, 4000, 4500, 5000,
  ];
  static const double _defaultBalance = 10000.0;

  double _balance = _defaultBalance;
  double _userBalance = _defaultBalance;
  double _betAmount = 100.0;
  double _lastWin = 0.0;
  bool _anteBetActive = false;

  /// Local working balance (mirrors `_userBalance` during gameplay).
  double get balance => _balance;

  /// Firestore-canonical balance — source of truth for affordability checks.
  double get userBalance => _userBalance;

  double get betAmount => _betAmount;
  double get lastWin => _lastWin;

  bool get canDecreaseBet => _betAmount > _betTiers.first;
  bool get canIncreaseBet => _betAmount < _betTiers.last;

  /// Per-base-spin cost: 1.25× when ante is active, 1.0× otherwise.
  double get effectiveBetCost =>
      _anteBetActive ? _betAmount * 1.25 : _betAmount;

  /// What the per-spin cost would be with ante enabled — used by the
  /// AnteToggle to preview the cost regardless of the current toggle state.
  double get anteCost => _betAmount * 1.25;

  /// Buy Free Spins price in TL at the current bet level.
  double get buyFeaturePrice =>
      _betAmount * SlotEngine.buyFeaturePriceMultiplier;

  /// Mirrors the ante toggle so `effectiveBetCost` reflects the current state.
  /// The ante toggle itself lives on [AnteController]; this is a read-only
  /// shadow updated by the owning ViewModel.
  // ignore: avoid_setters_without_getters
  set anteActiveShadow(bool value) {
    if (_anteBetActive == value) return;
    _anteBetActive = value;
    notifyListeners();
  }

  /// Hydrates from a Firestore user document, falling back to defaults.
  /// Both balances seed from `userBalance` — the legacy `balance` field is
  /// frozen at signup and would otherwise leave the displayed credit
  /// stale on app restart.
  void hydrate(Map<String, dynamic> userData) {
    final seed = (userData['userBalance'] ?? _defaultBalance).toDouble();
    _balance = seed;
    _userBalance = seed;
    notifyListeners();
  }

  /// Updates [userBalance] from a remote stream snapshot. Mirrors the
  /// remote value into the displayed balance too so they don't diverge
  /// after an out-of-band server-side adjustment.
  void applyRemoteUserBalance(double remoteValue) {
    if (_userBalance == remoteValue) return;
    _userBalance = remoteValue;
    _balance = remoteValue;
    notifyListeners();
  }

  /// Resets the displayed last-win to zero (call at the start of every spin).
  void resetLastWin() {
    if (_lastWin == 0.0) return;
    _lastWin = 0.0;
    notifyListeners();
  }

  /// True when the player has enough canonical credit to pay [cost].
  /// Used by transaction-time guards (e.g. spin/buy) so a stale local
  /// state can't outspend the source-of-truth Firestore balance.
  bool canAfford(double cost) => _userBalance >= cost;

  /// True when the displayed balance covers [cost]. Used by UI
  /// disabled-state checks so the button mirrors what the player sees
  /// in the credit readout, rather than the canonical balance which
  /// may briefly lag during Firestore sync.
  bool canAffordDisplayed(double cost) => _balance >= cost;

  /// Charges [amount] to both local and canonical balances. Clamped to a
  /// non-negative floor so the displayed credit never dips below zero
  /// even if a stale check slips through.
  void charge(double amount) {
    _balance = (_balance - amount).clamp(0.0, double.infinity);
    _userBalance = (_userBalance - amount).clamp(0.0, double.infinity);
    notifyListeners();
  }

  /// Awards [amount] to both local and canonical balances and stores it as
  /// the most recent win so the UI can display it.
  void awardWin(double amount) {
    _lastWin = amount;
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

  /// Snaps current bet to its tier index. If the bet sits between two
  /// tiers (e.g. legacy persisted value), returns the index of the
  /// nearest tier at or above current.
  int _currentTierIndex() {
    for (var i = 0; i < _betTiers.length; i++) {
      if (_betTiers[i] >= _betAmount) return i;
    }
    return _betTiers.length - 1;
  }
}
