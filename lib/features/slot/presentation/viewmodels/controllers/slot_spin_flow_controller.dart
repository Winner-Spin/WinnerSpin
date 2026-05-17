import '../../../domain/engine/spin_task.dart';
import 'ante_controller.dart';
import 'auto_spin_controller.dart';
import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'grid_controller.dart';
import 'insufficient_funds_hint_controller.dart';
import 'slot_pool_controller.dart';
import 'slot_spin_start_controller.dart';
import 'spin_execution_controller.dart';
import 'spin_lifecycle_controller.dart';
import 'spin_round_controller.dart';
import 'tumble_sequence_controller.dart';

class SlotSpinFlowController {
  Future<void> spin({
    required SlotSpinStartController startController,
    required SpinLifecycleController lifecycleController,
    required SpinExecutionController executionController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    required AutoSpinController autoSpinController,
    required InsufficientFundsHintController insufficientHintController,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
    required AnteController anteController,
    required TumbleSequenceController tumbleController,
    required GridController gridController,
    required bool isBusy,
    required bool isInFreeSpins,
    required double betAmount,
    required bool vibrationEnabled,
    required void Function() commitPendingFreeSpinConsume,
    required void Function() notifyListeners,
  }) async {
    final start = startController.beginSpin(
      isBusy: isBusy,
      isInFreeSpins: isInFreeSpins,
      balanceController: balanceController,
      freeSpinsController: freeSpinsController,
      autoSpinController: autoSpinController,
      insufficientHintController: insufficientHintController,
      poolController: poolController,
      roundController: roundController,
      notifyListeners: notifyListeners,
    );
    if (!start.started) return;

    autoSpinController.consumeAtSpinStart();
    lifecycleController.prepareSpinStart(
      balanceController: balanceController,
      tumbleController: tumbleController,
      gridController: gridController,
      vibrationEnabled: vibrationEnabled,
      notifyListeners: notifyListeners,
    );

    final bool anteFlag = start.isFreeSpin
        ? anteController.currentRoundFromAnte
        : anteController.active;
    final bool buyFlag =
        start.isFreeSpin && freeSpinsController.currentRoundFromBuy;

    final taskOutput = await executionController.run(
      pool: poolController.pool,
      betAmount: betAmount,
      isFreeSpins: start.isFreeSpin,
      anteBet: anteFlag,
      buyFs: buyFlag,
    );

    _applySpinTaskOutput(
      taskOutput: taskOutput,
      lifecycleController: lifecycleController,
      poolController: poolController,
      roundController: roundController,
      gridController: gridController,
    );

    if (start.isFreeSpin) {
      commitPendingFreeSpinConsume();
    }
  }

  Future<void> buyFreeSpins({
    required SlotSpinStartController startController,
    required SpinLifecycleController lifecycleController,
    required SpinExecutionController executionController,
    required BalanceController balanceController,
    required AutoSpinController autoSpinController,
    required InsufficientFundsHintController insufficientHintController,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
    required AnteController anteController,
    required TumbleSequenceController tumbleController,
    required GridController gridController,
    required bool isBusy,
    required bool isInFreeSpins,
    required double betAmount,
    required double buyFeaturePrice,
    required bool vibrationEnabled,
    required void Function() notifyListeners,
  }) async {
    final started = startController.beginBoughtFreeSpinTrigger(
      isBusy: isBusy,
      isInFreeSpins: isInFreeSpins,
      balanceController: balanceController,
      anteController: anteController,
      autoSpinController: autoSpinController,
      insufficientHintController: insufficientHintController,
      poolController: poolController,
      roundController: roundController,
      buyFeaturePrice: buyFeaturePrice,
      notifyListeners: notifyListeners,
    );
    if (!started) return;

    lifecycleController.prepareSpinStart(
      balanceController: balanceController,
      tumbleController: tumbleController,
      gridController: gridController,
      vibrationEnabled: vibrationEnabled,
      notifyListeners: notifyListeners,
    );

    final taskOutput = await executionController.run(
      pool: poolController.pool,
      betAmount: betAmount,
      isFreeSpins: false,
      anteBet: false,
      buyFs: false,
      forceFsTrigger: true,
    );

    _applySpinTaskOutput(
      taskOutput: taskOutput,
      lifecycleController: lifecycleController,
      poolController: poolController,
      roundController: roundController,
      gridController: gridController,
    );
  }

  void _applySpinTaskOutput({
    required SpinTaskOutput taskOutput,
    required SpinLifecycleController lifecycleController,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
    required GridController gridController,
  }) {
    lifecycleController.applySpinTaskOutput(
      taskOutput: taskOutput,
      poolController: poolController,
      roundController: roundController,
    );
    lifecycleController.showPendingInitialGrid(
      roundController: roundController,
      gridController: gridController,
    );
  }
}
