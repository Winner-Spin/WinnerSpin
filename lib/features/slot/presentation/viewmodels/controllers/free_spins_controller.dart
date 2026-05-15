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
    _remaining = userData['freeSpinsRemaining'] ?? 0;
    notifyListeners();
  }

  void consumeOne() {
    _remaining--;
    notifyListeners();
  }

  void awardInitial() {
    _remaining += _initialAward;
    notifyListeners();
  }

  void awardRetrigger() {
    _remaining += _retriggerAward;
    notifyListeners();
  }

  void awardBoughtRound() {
    _remaining += _initialAward;
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
