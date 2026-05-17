import 'ante_controller.dart';
import 'auto_spin_controller.dart';
import 'balance_controller.dart';
import 'free_spins_controller.dart';
import 'insufficient_funds_hint_controller.dart';
import 'slot_pool_controller.dart';
import 'spin_round_controller.dart';

class SlotSpinStartController {
  ({bool started, bool isFreeSpin}) beginSpin({
    required bool isBusy,
    required bool isInFreeSpins,
    required BalanceController balanceController,
    required FreeSpinsController freeSpinsController,
    required AutoSpinController autoSpinController,
    required InsufficientFundsHintController insufficientHintController,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
    required void Function() notifyListeners,
  }) {
    if (isBusy) return (started: false, isFreeSpin: false);

    final isFreeSpin = isInFreeSpins;
    roundController.markSpinMode(isFreeSpin);

    if (isFreeSpin) {
      roundController.beginFreeSpin();
      freeSpinsController.beginSpinRound();
      return (started: true, isFreeSpin: true);
    }

    final cost = balanceController.effectiveBetCost;
    if (!balanceController.canAfford(cost)) {
      if (autoSpinController.active) {
        autoSpinController.stopSilently();
      }
      insufficientHintController.flash(notifyListeners);
      return (started: false, isFreeSpin: false);
    }

    roundController.beginNormalSpin(cost);
    balanceController.charge(cost);
    poolController.recordBet(cost);
    return (started: true, isFreeSpin: false);
  }

  bool beginBoughtFreeSpinTrigger({
    required bool isBusy,
    required bool isInFreeSpins,
    required BalanceController balanceController,
    required AnteController anteController,
    required AutoSpinController autoSpinController,
    required InsufficientFundsHintController insufficientHintController,
    required SlotPoolController poolController,
    required SpinRoundController roundController,
    required double buyFeaturePrice,
    required void Function() notifyListeners,
  }) {
    if (autoSpinController.active) {
      autoSpinController.stopSilently();
    }
    if (anteController.active) return false;
    if (isBusy || isInFreeSpins) return false;
    if (!balanceController.canAffordDisplayed(buyFeaturePrice)) {
      insufficientHintController.flash(notifyListeners);
      return false;
    }

    balanceController.charge(buyFeaturePrice);
    poolController.recordBet(buyFeaturePrice);
    roundController.beginBoughtFreeSpinTrigger();
    return true;
  }
}
