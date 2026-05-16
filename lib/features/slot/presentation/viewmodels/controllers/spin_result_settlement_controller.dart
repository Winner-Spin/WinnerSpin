import 'package:flutter/services.dart';

import '../../../domain/models/pool_state.dart';
import '../../../domain/models/spin_result.dart';
import 'ante_controller.dart';
import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'game_history_controller.dart';
import 'grid_controller.dart';

class SpinResultSettlementController {
  void awardWinAndRecordHistory({
    required SpinResult result,
    required BalanceController balanceController,
    required GameHistoryController historyController,
    required String? userId,
    required double pendingHistoryBet,
    required bool vibrationEnabled,
  }) {
    balanceController.awardWin(result.totalWin);
    historyController.record(
      userId: userId,
      newBalance: balanceController.userBalance,
      bet: pendingHistoryBet,
      winAmount: result.totalWin,
    );
    if (vibrationEnabled && result.totalWin > 0) {
      HapticFeedback.heavyImpact();
    }
  }

  bool applyFreeSpinAward({
    required SpinResult result,
    required FreeSpinsController freeSpinsController,
    required AnteController anteController,
    required bool currentSpinFromBuy,
  }) {
    if (!result.freeSpinsTriggered) return false;

    if (result.isRetrigger) {
      freeSpinsController.awardRetrigger();
    } else {
      freeSpinsController.awardInitial();
      anteController.captureForNewRound();
      if (currentSpinFromBuy) {
        freeSpinsController.markCurrentRoundFromBuy();
      }
    }

    return true;
  }

  void clearRoundFlagsIfNeeded({
    required bool isInFreeSpins,
    required AnteController anteController,
    required FreeSpinsController freeSpinsController,
  }) {
    if (isInFreeSpins) return;
    anteController.clearRoundFlag();
    freeSpinsController.clearRoundFlag();
  }

  void recordPayout({required PoolState pool, required double amount}) {
    pool.recordPayout(amount);
  }

  void showWinningPositions({
    required SpinResult result,
    required GridController gridController,
  }) {
    gridController.setWinningPositions(result.winningPositions);
  }
}
