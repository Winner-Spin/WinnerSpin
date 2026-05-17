import 'package:flutter/services.dart';

import '../../../domain/engine/spin_task.dart';
import 'balance_controller.dart';
import 'grid_controller.dart';
import 'slot_pool_controller.dart';
import 'spin_round_controller.dart';
import 'tumble_sequence_controller.dart';

class SpinLifecycleController {
  void prepareSpinStart({
    required BalanceController balanceController,
    required TumbleSequenceController tumbleController,
    required GridController gridController,
    required bool vibrationEnabled,
    required void Function() notifyListeners,
  }) {
    balanceController.resetLastWin();
    tumbleController.resetForNewSpin();
    gridController.capturePreviousGrid();
    gridController.resetForNewSpin();
    if (vibrationEnabled) HapticFeedback.lightImpact();
    notifyListeners();
  }

  void applySpinTaskOutput({
    required SpinTaskOutput taskOutput,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
  }) {
    poolController.applySpinPool(taskOutput.pool);
    roundController.applyPendingResult(taskOutput.result);
  }

  void showPendingInitialGrid({
    required SpinRoundController roundController,
    required GridController gridController,
  }) {
    final pendingResult = roundController.pendingResult;
    if (pendingResult == null) return;
    gridController.setGrid(pendingResult.initialGrid);
  }

  void clearMultiplierResidues({required GridController gridController}) {
    gridController.clearMultiplierResidues();
  }
}
