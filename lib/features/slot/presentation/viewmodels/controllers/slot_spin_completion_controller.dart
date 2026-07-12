import 'ante_controller.dart';
import 'auto_spin_controller.dart';
import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'game_history_controller.dart';
import 'grid_controller.dart';
import 'slot_pool_controller.dart';
import 'spin_lifecycle_controller.dart';
import 'spin_result_settlement_controller.dart';
import 'spin_round_controller.dart';
import 'tumble_sequence_controller.dart';

class SlotSpinCompletionController {
  Future<void> complete({
    required SpinLifecycleController lifecycleController,
    required SpinRoundController roundController,
    required TumbleSequenceController tumbleController,
    required SpinResultSettlementController settlementController,
    required BalanceController balanceController,
    required GameHistoryController historyController,
    required GridController gridController,
    required FreeSpinsController freeSpinsController,
    required AnteController anteController,
    required SlotPoolController poolController,
    required AutoSpinController autoSpinController,
    required String? userId,
    required bool vibrationEnabled,
    required bool Function() isInFreeSpins,
    required void Function() savePlayerState,
    required void Function() savePoolIfNeeded,
    required void Function() notifyListeners,
  }) async {
    await roundController.waitForSpinResult();
    final result = roundController.pendingResult;
    lifecycleController.clearMultiplierResidues(gridController: gridController);

    if (result == null) {
      roundController.finishSpinning();
      roundController.clearPendingResult();
      notifyListeners();
      return;
    }

    roundController.finishSpinning();

    await tumbleController.play(
      result: result,
      gridController: gridController,
      vibrationEnabled: vibrationEnabled,
      notifyListeners: notifyListeners,
    );

    settlementController.awardWinAndRecordHistory(
      result: result,
      balanceController: balanceController,
      historyController: historyController,
      userId: userId,
      pendingHistoryBet: roundController.pendingHistoryBet,
      vibrationEnabled: vibrationEnabled,
    );
    settlementController.showWinningPositions(
      result: result,
      gridController: gridController,
    );
    roundController.markResultSettled(result);

    final freeSpinAwarded = settlementController.applyFreeSpinAward(
      result: result,
      freeSpinsController: freeSpinsController,
      anteController: anteController,
      currentSpinFromBuy: roundController.currentSpinFromBuy,
    );
    if (freeSpinAwarded) {
      savePlayerState();
    }

    settlementController.clearRoundFlagsIfNeeded(
      isInFreeSpins: isInFreeSpins(),
      anteController: anteController,
      freeSpinsController: freeSpinsController,
    );

    poolController.recordPayout(result.totalWin);
    savePoolIfNeeded();

    roundController.clearPendingResult();

    if (autoSpinController.active) {
      autoSpinController.stopIfCompleted();
      notifyListeners();
    }
  }
}
