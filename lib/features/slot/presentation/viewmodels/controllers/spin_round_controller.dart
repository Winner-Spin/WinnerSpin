import 'dart:async';

import '../../../domain/models/spin_result.dart';

class SpinRoundController {
  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  bool _lastSpinWasFreeSpin = false;
  bool get lastSpinWasFreeSpin => _lastSpinWasFreeSpin;

  bool _currentSpinFromBuy = false;
  bool get currentSpinFromBuy => _currentSpinFromBuy;

  SpinResult? _pendingResult;
  SpinResult? get pendingResult => _pendingResult;

  String? _pendingRecoveryId;
  String? get pendingRecoveryId => _pendingRecoveryId;

  Completer<void>? _spinResultReady;

  double _pendingHistoryBet = 0;
  double get pendingHistoryBet => _pendingHistoryBet;

  SpinResult? _lastSpinResult;
  SpinResult? get lastSpinResult => _lastSpinResult;

  void markSpinMode(bool isFreeSpin) {
    _lastSpinWasFreeSpin = isFreeSpin;
  }

  void beginNormalSpin(double historyBet) {
    _prepareForSpinResult();
    _isSpinning = true;
    _lastSpinWasFreeSpin = false;
    _currentSpinFromBuy = false;
    _pendingHistoryBet = historyBet;
  }

  void beginFreeSpin() {
    _prepareForSpinResult();
    _isSpinning = true;
    _lastSpinWasFreeSpin = true;
    _currentSpinFromBuy = false;
    _pendingHistoryBet = 0;
  }

  void beginBoughtFreeSpinTrigger() {
    _prepareForSpinResult();
    _isSpinning = true;
    _lastSpinWasFreeSpin = false;
    _currentSpinFromBuy = true;
    _pendingHistoryBet = 0;
  }

  void finishSpinning() {
    _isSpinning = false;
  }

  void applyPendingResult(SpinResult result) {
    _pendingResult = result;
  }

  void attachRecovery(String spinId) {
    _pendingRecoveryId = spinId;
  }

  Future<void> waitForSpinResult() {
    return _spinResultReady?.future ?? Future<void>.value();
  }

  void markSpinResultReady() {
    final completer = _spinResultReady;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void markResultSettled(SpinResult result) {
    _lastSpinResult = result;
  }

  void clearPendingResult() {
    _pendingResult = null;
    _pendingRecoveryId = null;
    _spinResultReady = null;
    _pendingHistoryBet = 0;
  }

  void _prepareForSpinResult() {
    markSpinResultReady();
    _pendingResult = null;
    _pendingRecoveryId = null;
    _spinResultReady = Completer<void>();
  }
}
