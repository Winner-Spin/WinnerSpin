import 'package:flutter/services.dart';

import '../../../domain/models/pending_spin_recovery.dart';
import '../../../domain/models/pool_state.dart';
import '../../../domain/models/spin_result.dart';
import 'ante_controller.dart';
import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'game_history_controller.dart';
import 'grid_controller.dart';
import 'slot_pool_controller.dart';
import 'spin_round_controller.dart';

class SpinResultSettlementController {
  void provideWinFeedback({
    required double winAmount,
    required bool vibrationEnabled,
  }) {
    if (vibrationEnabled && winAmount > 0) {
      HapticFeedback.heavyImpact();
    }
  }

  void awardWinAndRecordHistory({
    required SpinResult result,
    required BalanceController balanceController,
    required GameHistoryController historyController,
    required String? userId,
    required double pendingHistoryBet,
    required bool vibrationEnabled,
    String? historyId,
  }) {
    awardWin(
      result: result,
      balanceController: balanceController,
      vibrationEnabled: vibrationEnabled,
    );
    historyController.record(
      userId: userId,
      newBalance: balanceController.userBalance,
      bet: pendingHistoryBet,
      winAmount: result.totalWin,
      id: historyId,
    );
  }

  void awardWin({
    required SpinResult result,
    required BalanceController balanceController,
    required bool vibrationEnabled,
  }) {
    balanceController.awardWin(result.totalWin);
    provideWinFeedback(
      winAmount: result.totalWin,
      vibrationEnabled: vibrationEnabled,
    );
  }

  PendingSpinRecovery createRecovery({
    required String spinId,
    required DateTime playedAt,
    required SpinResult result,
    required SpinRoundController roundController,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    required AnteController anteController,
    required SlotPoolController poolController,
  }) {
    final isFreeSpin = roundController.lastSpinWasFreeSpin;
    var remaining = freeSpinsController.remaining;
    var accumulatedWin = freeSpinsController.accumulatedWin;
    var awardedThisRound = freeSpinsController.awardedThisRound;
    var roundFromAnte = isFreeSpin
        ? anteController.currentRoundFromAnte
        : false;
    var roundFromBuy = isFreeSpin
        ? freeSpinsController.currentRoundFromBuy
        : false;

    if (isFreeSpin) {
      remaining = (remaining - 1).clamp(0, 1 << 31).toInt();
      if (result.totalWin > 0) accumulatedWin += result.totalWin;
      if (result.freeSpinsTriggered) {
        remaining += FreeSpinsController.retriggerAwardCount;
        awardedThisRound += FreeSpinsController.retriggerAwardCount;
      }
    } else if (result.freeSpinsTriggered) {
      remaining = remaining <= 0
          ? FreeSpinsController.initialAwardCount
          : remaining + FreeSpinsController.initialAwardCount;
      accumulatedWin = result.totalWin.clamp(0, double.infinity).toDouble();
      awardedThisRound = FreeSpinsController.initialAwardCount;
      roundFromAnte = anteController.active;
    }

    if (remaining <= 0) {
      accumulatedWin = 0;
      awardedThisRound = 0;
      roundFromAnte = false;
      roundFromBuy = false;
    }

    final pool = poolController.pool;
    return PendingSpinRecovery(
      spinId: spinId,
      playedAt: playedAt,
      isFreeSpin: isFreeSpin,
      historyBet: roundController.pendingHistoryBet,
      winAmount: result.totalWin,
      userBalance: balanceController.userBalance + result.totalWin,
      freeSpinsRemaining: remaining,
      freeSpinAccumulatedWin: accumulatedWin,
      freeSpinsAwardedThisRound: awardedThisRound,
      pendingFreeSpinAward: result.freeSpinsTriggered
          ? (result.isRetrigger ? 5 : 10)
          : 0,
      roundFromAnte: roundFromAnte,
      roundFromBuy: roundFromBuy,
      poolTotalBetsPlaced: pool.totalBetsPlaced,
      poolTotalPaidOut: pool.totalPaidOut + result.totalWin,
      poolTotalSpins: pool.totalSpins,
    );
  }

  void restoreRecovery({
    required PendingSpinRecovery recovery,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    required AnteController anteController,
    required SlotPoolController poolController,
  }) {
    balanceController.hydrate({
      'userBalance': recovery.userBalance,
      'lastWin': recovery.winAmount,
    });
    freeSpinsController.hydrate({
      'freeSpinsRemaining': recovery.freeSpinsRemaining,
      'freeSpinAccumulatedWin': recovery.freeSpinAccumulatedWin,
      'freeSpinsAwardedThisRound': recovery.freeSpinsAwardedThisRound,
    });
    anteController.restoreRoundFlag(recovery.roundFromAnte);
    freeSpinsController.restoreRoundFlag(recovery.roundFromBuy);
    poolController.hydrate(
      PoolState(
        totalBetsPlaced: recovery.poolTotalBetsPlaced,
        totalPaidOut: recovery.poolTotalPaidOut,
        totalSpins: recovery.poolTotalSpins,
      ),
    );
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
      freeSpinsController.awardInitial(initialWin: result.totalWin);
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

  void showWinningPositions({
    required SpinResult result,
    required GridController gridController,
  }) {
    gridController.setWinningPositions(result.winningPositions);
  }
}
