import 'dart:async';

import 'package:flutter/foundation.dart';

enum WinPresentationPhase {
  idle,
  baseCounting,
  multiplierCollecting,
  finalCounting,
  done,
}

class WinPresentationController extends ChangeNotifier {
  WinPresentationPhase _phase = WinPresentationPhase.idle;
  WinPresentationPhase get phase => _phase;

  double _baseWin = 0;
  double get baseWin => _baseWin;

  double _totalWin = 0;
  double get totalWin => _totalWin;

  List<int> _multipliers = const [];
  List<int> get multipliers => _multipliers;

  int _activeIndex = -1;
  int get activeIndex => _activeIndex;

  int _runningSum = 0;
  int get runningSum => _runningSum;

  bool _multiplierFlightStarted = false;
  bool get multiplierFlightStarted => _multiplierFlightStarted;

  Timer? _phaseTimer;

  static const Duration baseCountUpDuration = Duration(milliseconds: 700);

  static const Duration holdAfterBaseCountUp = Duration(milliseconds: 450);

  static const Duration multiplierSettleDuration = Duration(milliseconds: 250);
  static const Duration multiplierFlightDuration = Duration(milliseconds: 700);
  static const Duration postLandPulse = Duration(milliseconds: 220);
  static const Duration interMultiplierGap = Duration(milliseconds: 220);
  static const Duration formulaToFinalGap = Duration(milliseconds: 350);
  static const Duration finalCountUpDuration = Duration(milliseconds: 800);

  static Duration get totalFlightWindow =>
      multiplierSettleDuration + multiplierFlightDuration;

  void start({
    required double baseWin,
    required List<int> multiplierValues,
    required double totalWin,
  }) {
    _phaseTimer?.cancel();
    _baseWin = baseWin;
    _totalWin = totalWin;
    _multipliers = List.unmodifiable(multiplierValues);
    _activeIndex = -1;
    _runningSum = 0;
    _multiplierFlightStarted = false;

    _phase = WinPresentationPhase.baseCounting;
    notifyListeners();

    _phaseTimer = Timer(holdAfterBaseCountUp, _startNextMultiplier);
  }

  void reset() {
    _phaseTimer?.cancel();
    _phase = WinPresentationPhase.idle;
    _activeIndex = -1;
    _runningSum = 0;
    _multiplierFlightStarted = false;
    notifyListeners();
  }

  void _startNextMultiplier() {
    if (_multipliers.isEmpty) {
      _enterFinalPhase();
      return;
    }
    _phase = WinPresentationPhase.multiplierCollecting;
    _activeIndex = (_activeIndex < 0) ? 0 : _activeIndex + 1;
    _multiplierFlightStarted = true;
    notifyListeners();
  }

  void onBombBlastComplete() {
    if (_phase != WinPresentationPhase.multiplierCollecting) return;
    if (_activeIndex < 0) return;
    final hasMore = _activeIndex < _multipliers.length - 1;
    if (!hasMore) return;
    _activeIndex++;
    _phaseTimer?.cancel();
    notifyListeners();
  }

  void onMultiplierLanded(int landedIndex) {
    if (_phase != WinPresentationPhase.multiplierCollecting) return;
    if (landedIndex < 0 || landedIndex >= _multipliers.length) return;

    _runningSum += _multipliers[landedIndex];
    notifyListeners();

    final isLast = landedIndex == _multipliers.length - 1;
    if (isLast) {
      _phaseTimer?.cancel();
      _phaseTimer = Timer(postLandPulse + formulaToFinalGap, _enterFinalPhase);
    }
  }

  void _enterFinalPhase() {
    _phase = WinPresentationPhase.finalCounting;
    _multiplierFlightStarted = false;
    notifyListeners();

    _phaseTimer?.cancel();
    _phaseTimer = Timer(finalCountUpDuration, () {
      _phase = WinPresentationPhase.done;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }
}
