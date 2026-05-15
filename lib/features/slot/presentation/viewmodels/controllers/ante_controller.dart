import 'package:flutter/foundation.dart';

class AnteController extends ChangeNotifier {
  bool _active = false;
  bool _currentRoundFromAnte = false;

  bool get active => _active;

  /// True if the current FS round was triggered by an ante base spin.
  bool get currentRoundFromAnte => _currentRoundFromAnte;

  void toggle() {
    _active = !_active;
    notifyListeners();
  }

  /// Locks the ante flag at FS trigger time.
  void captureForNewRound() {
    if (_currentRoundFromAnte == _active) return;
    _currentRoundFromAnte = _active;
    notifyListeners();
  }

  void clearRoundFlag() {
    if (!_currentRoundFromAnte) return;
    _currentRoundFromAnte = false;
    notifyListeners();
  }
}
