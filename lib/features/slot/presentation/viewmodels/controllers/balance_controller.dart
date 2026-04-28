import '../../../domain/engine/slot_engine.dart';

/// Holds balance + bet state. Plain mutable holder — the owning
/// ViewModel calls `notifyListeners()` after mutating it.
class BalanceController {
  static const double _minBet = 10.0;
  static const double _maxBet = 5000.0;
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

  /// Per-base-spin cost: 1.25× when ante is active, 1.0× otherwise.
  double get effectiveBetCost =>
      _anteBetActive ? _betAmount * 1.25 : _betAmount;

  /// Buy Free Spins price in TL at the current bet level.
  double get buyFeaturePrice =>
      _betAmount * SlotEngine.buyFeaturePriceMultiplier;

  /// Mirrors the ante toggle so `effectiveBetCost` reflects the current state.
  /// The ante toggle itself lives on [AnteController]; this is a read-only
  /// shadow updated by the owning ViewModel.
  // ignore: avoid_setters_without_getters
  set anteActiveShadow(bool value) {
    _anteBetActive = value;
  }

  /// Hydrates from a Firestore user document, falling back to defaults.
  void hydrate(Map<String, dynamic> userData) {
    _balance = (userData['balance'] ?? _defaultBalance).toDouble();
    _userBalance = (userData['userBalance'] ?? _defaultBalance).toDouble();
  }

  /// Updates [userBalance] from a remote stream snapshot.
  void applyRemoteUserBalance(double remoteValue) {
    _userBalance = remoteValue;
  }

  /// Resets the displayed last-win to zero (call at the start of every spin).
  void resetLastWin() {
    _lastWin = 0.0;
  }

  /// True when the player has enough credit to pay [cost].
  bool canAfford(double cost) => _userBalance >= cost;

  /// Charges [amount] to both local and canonical balances.
  void charge(double amount) {
    _balance -= amount;
    _userBalance -= amount;
  }

  /// Awards [amount] to both local and canonical balances and stores it as
  /// the most recent win so the UI can display it.
  void awardWin(double amount) {
    _lastWin = amount;
    _balance += amount;
    _userBalance += amount;
  }

  bool increaseBet() {
    if (_betAmount >= _maxBet) return false;
    _betAmount = (_betAmount * 2).clamp(_minBet, _maxBet);
    return true;
  }

  bool decreaseBet() {
    if (_betAmount <= _minBet) return false;
    _betAmount = (_betAmount / 2).clamp(_minBet, _maxBet);
    return true;
  }
}
