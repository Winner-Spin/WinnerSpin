import 'package:flutter/services.dart';

import '../../../domain/models/spin_result.dart';
import 'grid_controller.dart';

class TumbleSequenceController {
  static const Duration fadeDuration = Duration(milliseconds: 1750);
  static const Duration settleDuration = Duration(milliseconds: 450);

  bool _isTumbling = false;
  double _liveWin = 0;

  bool get isTumbling => _isTumbling;
  double get liveWin => _liveWin;

  void resetForNewSpin() {
    _liveWin = 0;
  }

  Future<void> play({
    required SpinResult result,
    required GridController gridController,
    required bool vibrationEnabled,
    required void Function() notifyListeners,
  }) async {
    if (result.tumbles.isEmpty) return;

    _isTumbling = true;
    notifyListeners();

    for (final tumble in result.tumbles) {
      _liveWin += tumble.winAmount;
      gridController.startTumble(
        fadingPaths: tumble.winningPaths,
        activeExplosions: tumble.clusterWins,
      );
      notifyListeners();
      if (vibrationEnabled) HapticFeedback.mediumImpact();

      await Future.delayed(fadeDuration);
      gridController.endTumble(newGrid: tumble.gridAfter);
      await Future.delayed(settleDuration);
    }

    _isTumbling = false;
    notifyListeners();
  }
}
