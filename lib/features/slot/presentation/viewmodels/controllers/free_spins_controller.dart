import 'package:flutter/foundation.dart';

class FreeSpinsController extends ChangeNotifier {
  static const int _initialAward = 10;
  static const int _retriggerAward = 5;

  int _remaining = 0;
  double _accumulatedWin = 0;
  int _awardedThisRound = 0;
  bool _currentRoundFromBuy = false;
  bool _roundHoldActive = false;
  bool _pendingConsume = false;

  int get remaining => _remaining;

  double get accumulatedWin => _accumulatedWin;

  int get awardedThisRound => _awardedThisRound;

  bool get isActive => _remaining > 0;

  bool get isInRound => isActive || _roundHoldActive;

  bool get currentRoundFromBuy => _currentRoundFromBuy;

  void hydrate(Map<String, dynamic> userData) {
    final storedRemaining = userData['freeSpinsRemaining'];
    final remaining = storedRemaining is num ? storedRemaining.toInt() : 0;
    _remaining = remaining < 0 ? 0 : remaining;
    if (_remaining > 0) {
      final storedWin = userData['freeSpinAccumulatedWin'];
      final accumulatedWin = storedWin is num ? storedWin.toDouble() : 0.0;
      _accumulatedWin = accumulatedWin < 0 ? 0 : accumulatedWin;

      final storedAwarded = userData['freeSpinsAwardedThisRound'];
      final awarded = storedAwarded is num
          ? storedAwarded.toInt()
          : _initialAward;
      _awardedThisRound = awarded < 0 ? 0 : awarded;
    } else {
      _accumulatedWin = 0;
      _awardedThisRound = 0;
    }
    notifyListeners();
  }

  void consumeOne() {
    if (_remaining <= 0) return;
    _remaining--;
    notifyListeners();
  }

  void beginSpinRound() {
    _pendingConsume = true;
    _roundHoldActive = true;
  }

  bool commitPendingConsume() {
    if (!_pendingConsume) return false;
    _pendingConsume = false;
    consumeOne();
    return true;
  }

  bool releaseRoundHold() {
    if (!_roundHoldActive) return false;
    _roundHoldActive = false;
    return true;
  }

  void awardInitial({double initialWin = 0}) {
    _remaining = _remaining <= 0 ? _initialAward : _remaining + _initialAward;
    _accumulatedWin = initialWin < 0 ? 0 : initialWin;
    _awardedThisRound = _initialAward;
    notifyListeners();
  }

  void awardRetrigger() {
    _remaining += _retriggerAward;
    _awardedThisRound += _retriggerAward;
    notifyListeners();
  }

  void awardBoughtRound({double initialWin = 0}) {
    _remaining = _remaining <= 0 ? _initialAward : _remaining + _initialAward;
    _accumulatedWin = initialWin < 0 ? 0 : initialWin;
    _awardedThisRound = _initialAward;
    _currentRoundFromBuy = true;
    notifyListeners();
  }

  void recordRoundWin(double amount) {
    if (amount <= 0) return;
    _accumulatedWin += amount;
    notifyListeners();
  }

  void finishRound() {
    if (_remaining > 0) return;
    final changed =
        _accumulatedWin != 0 || _awardedThisRound != 0 || _currentRoundFromBuy;
    _accumulatedWin = 0;
    _awardedThisRound = 0;
    _currentRoundFromBuy = false;
    if (changed) notifyListeners();
  }

  void markCurrentRoundFromBuy() {
    if (_currentRoundFromBuy) return;
    _currentRoundFromBuy = true;
    notifyListeners();
  }

  void clearRoundFlag() {
    if (!_currentRoundFromBuy) return;
    _currentRoundFromBuy = false;
    notifyListeners();
  }
}
