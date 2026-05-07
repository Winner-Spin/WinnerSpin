import 'dart:async';

import 'package:flutter/foundation.dart';

/// Phases the win-presentation goes through after a winning spin
/// produced both cluster wins and at least one multiplier symbol.
enum WinPresentationPhase {
  idle,
  baseCounting,
  multiplierCollecting,
  finalCounting,
  done,
}

/// Drives the staged "base → multipliers → final" win reveal. Caller
/// invokes [start] once the cascade animations have settled and the
/// final result is known. The controller emits state changes via
/// [ChangeNotifier] so the view can rebuild as each phase progresses.
///
/// Multipliers are summed (not multiplied) — matching the engine's
/// `totalWin = base * sum(multipliers) + scatter` math.
class WinPresentationController extends ChangeNotifier {
  WinPresentationPhase _phase = WinPresentationPhase.idle;
  WinPresentationPhase get phase => _phase;

  double _baseWin = 0;
  double get baseWin => _baseWin;

  double _totalWin = 0;
  double get totalWin => _totalWin;

  List<int> _multipliers = const [];
  List<int> get multipliers => _multipliers;

  /// Index of the multiplier currently in flight (or just landed).
  /// `-1` while no flight is in progress.
  int _activeIndex = -1;
  int get activeIndex => _activeIndex;

  /// Sum of multiplier values that have already landed in the bar.
  int _runningSum = 0;
  int get runningSum => _runningSum;

  /// True from the moment the FIRST multiplier starts its flight until
  /// the formula collapses for the final reveal. Lets the view paint
  /// the "×" placeholder in the bar before the value lands.
  bool _multiplierFlightStarted = false;
  bool get multiplierFlightStarted => _multiplierFlightStarted;

  Timer? _phaseTimer;

  // Tunable timings. Adjust here to retime the whole presentation.
  static const Duration baseCountUpDuration = Duration(milliseconds: 700);

  /// Brief hold after the base count-up completes — gives the player
  /// a beat to read the cluster total before the cell bursts start
  /// firing.
  static const Duration holdAfterBaseCountUp = Duration(milliseconds: 450);

  static const Duration multiplierSettleDuration = Duration(milliseconds: 250);
  static const Duration multiplierFlightDuration = Duration(milliseconds: 700);
  static const Duration postLandPulse = Duration(milliseconds: 220);
  static const Duration interMultiplierGap = Duration(milliseconds: 220);
  static const Duration formulaToFinalGap = Duration(milliseconds: 350);
  static const Duration finalCountUpDuration = Duration(milliseconds: 800);

  /// Total time the floating text spends in the air before landing.
  static Duration get totalFlightWindow =>
      multiplierSettleDuration + multiplierFlightDuration;

  /// Begins the presentation. [multiplierValues] is the ordered list of
  /// face values that will fly into the bar one by one.
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

    // baseCounting is now a "hold" phase — the bar already counted up
    // live during the cascade, so this phase just keeps the base value
    // on screen for [holdAfterBaseCountUp] before the first multiplier
    // fuse fires. No fresh count-up from zero.
    _phase = WinPresentationPhase.baseCounting;
    notifyListeners();

    _phaseTimer = Timer(holdAfterBaseCountUp, _startNextMultiplier);
  }

  /// Resets back to idle — call when a new spin starts so the previous
  /// presentation doesn't keep emitting changes.
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

  /// Called by the view when the current multiplier's flight reaches
  /// the bar. Updates [runningSum], schedules the next multiplier or
  /// advances to the final phase.
  void onMultiplierLanded() {
    if (_phase != WinPresentationPhase.multiplierCollecting) return;
    if (_activeIndex < 0 || _activeIndex >= _multipliers.length) return;

    _runningSum += _multipliers[_activeIndex];
    notifyListeners();

    final hasMore = _activeIndex < _multipliers.length - 1;
    final delay = hasMore
        ? (postLandPulse + interMultiplierGap)
        : (postLandPulse + formulaToFinalGap);

    _phaseTimer?.cancel();
    _phaseTimer = Timer(delay, () {
      if (hasMore) {
        _startNextMultiplier();
      } else {
        _enterFinalPhase();
      }
    });
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
