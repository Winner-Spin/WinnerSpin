import 'package:flutter/foundation.dart';

class FreeSpinsController extends ChangeNotifier {
  static const int _initialAward = 10;
  static const int _retriggerAward = 5;

  int _remaining = 0;
  bool _currentRoundFromBuy = false;

  int get remaining => _remaining;

  bool get isActive => _remaining > 0;

  bool get currentRoundFromBuy => _currentRoundFromBuy;

  void hydrate(Map<String, dynamic> userData) {
    final storedRemaining = userData['freeSpinsRemaining'];
    final remaining = storedRemaining is num ? storedRemaining.toInt() : 0;
    _remaining = remaining < 0 ? 0 : remaining;
    notifyListeners();
  }

  void consumeOne() {
    if (_remaining <= 0) return;
    _remaining--;
    notifyListeners();
  }

  void awardInitial() {
    _remaining = _remaining <= 0 ? _initialAward : _remaining + _initialAward;
    notifyListeners();
  }

  void awardRetrigger() {
    _remaining += _retriggerAward;
    notifyListeners();
  }

  void awardBoughtRound() {
    _remaining = _remaining <= 0 ? _initialAward : _remaining + _initialAward;
    _currentRoundFromBuy = true;
    notifyListeners();
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
