import 'package:flutter/foundation.dart';

/// Tracks Free Spins state — the spin counter, the buy-bonus round flag,
/// and the convenience predicate the UI relies on.
class FreeSpinsController extends ChangeNotifier {
  static const int _initialAward = 10;
  static const int _retriggerAward = 5;

  int _remaining = 0;
  bool _currentRoundFromBuy = false;

  /// Number of free spins still owed to the player.
  int get remaining => _remaining;

  /// True while the player is inside an active FS round.
  bool get isActive => _remaining > 0;

  /// True while the in-progress FS round was bought via the Buy FS feature.
  /// The engine reads this to apply the buy multiplier boost across the
  /// entire round, including retriggers.
  bool get currentRoundFromBuy => _currentRoundFromBuy;

  /// Hydrates the counter from a Firestore user document.
  void hydrate(Map<String, dynamic> userData) {
    _remaining = userData['freeSpinsRemaining'] ?? 0;
    notifyListeners();
  }

  /// Consumes one free spin (called when an FS spin starts).
  void consumeOne() {
    _remaining--;
    notifyListeners();
  }

  /// Awards spins for an initial trigger (10).
  void awardInitial() {
    _remaining += _initialAward;
    notifyListeners();
  }

  /// Awards spins for a retrigger (5).
  void awardRetrigger() {
    _remaining += _retriggerAward;
    notifyListeners();
  }

  /// Awards a bought round (10) and flags the round as buy-triggered.
  void awardBoughtRound() {
    _remaining += _initialAward;
    _currentRoundFromBuy = true;
    notifyListeners();
  }

  /// Clears the buy flag. Called when the FS round ends.
  void clearRoundFlag() {
    if (!_currentRoundFromBuy) return;
    _currentRoundFromBuy = false;
    notifyListeners();
  }
}
