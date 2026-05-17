import 'auto_spin_controller.dart';
import 'balance_controller.dart';
import 'insufficient_funds_hint_controller.dart';

class SlotAutoSpinFlowController {
  bool start({
    required AutoSpinController autoSpinController,
    required BalanceController balanceController,
    required InsufficientFundsHintController insufficientHintController,
    required bool isBusy,
    required bool isInFreeSpins,
    required double effectiveBetCost,
    required int spinCount,
    required int speedMultiplier,
    required void Function() spin,
    required void Function() notifyListeners,
  }) {
    if (isBusy || spinCount <= 0) return false;
    if (!isInFreeSpins && !balanceController.canAfford(effectiveBetCost)) {
      insufficientHintController.flash(notifyListeners);
      return false;
    }

    if (!autoSpinController.start(
      spinCount,
      speedMultiplier: speedMultiplier,
    )) {
      return false;
    }

    spin();
    return true;
  }

  bool stop({required AutoSpinController autoSpinController}) {
    return autoSpinController.stop();
  }

  void toggle({
    required AutoSpinController autoSpinController,
    required void Function(int spinCount, {int speedMultiplier}) start,
    required void Function() stop,
  }) {
    if (autoSpinController.active) {
      stop();
      return;
    }

    start(100, speedMultiplier: autoSpinController.speedMultiplier);
  }

  void continueIfReady({
    required AutoSpinController autoSpinController,
    required bool Function() isBusy,
    required void Function() spin,
    Duration delay = const Duration(milliseconds: 600),
  }) {
    if (!autoSpinController.canContinue(isBusy: isBusy())) return;
    Future.delayed(delay, () {
      if (autoSpinController.canContinue(isBusy: isBusy())) {
        spin();
      }
    });
  }
}
