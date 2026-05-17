import 'ante_controller.dart';
import 'auto_spin_controller.dart';
import 'balance_controller.dart';
import 'insufficient_funds_hint_controller.dart';
import 'spin_availability_controller.dart';

class SlotPlayerControlsController {
  bool toggleSpeed({
    required SpinAvailabilityController availabilityController,
    required AutoSpinController autoSpinController,
    required bool isBusy,
  }) {
    if (!availabilityController.canToggleSpeed(
      isBusy: isBusy,
      isAutoSpinning: autoSpinController.active,
    )) {
      return false;
    }

    autoSpinController.nextSpeed();
    return true;
  }

  bool toggleAnte({
    required SpinAvailabilityController availabilityController,
    required AnteController anteController,
    required AutoSpinController autoSpinController,
    required BalanceController balanceController,
    required bool isBusy,
    required bool isInFreeSpins,
  }) {
    if (!availabilityController.canToggleAnte(
      isBusy: isBusy,
      isAutoSpinning: autoSpinController.active,
      isInFreeSpins: isInFreeSpins,
    )) {
      return false;
    }

    anteController.toggle();
    balanceController.anteActiveShadow = anteController.active;
    return true;
  }

  bool increaseBet({
    required SpinAvailabilityController availabilityController,
    required AutoSpinController autoSpinController,
    required BalanceController balanceController,
    required bool isInFreeSpins,
  }) {
    if (!availabilityController.canChangeBet(
      isAutoSpinning: autoSpinController.active,
      isInFreeSpins: isInFreeSpins,
    )) {
      return false;
    }

    return balanceController.increaseBet();
  }

  bool decreaseBet({
    required SpinAvailabilityController availabilityController,
    required AutoSpinController autoSpinController,
    required BalanceController balanceController,
    required bool isInFreeSpins,
  }) {
    if (!availabilityController.canChangeBet(
      isAutoSpinning: autoSpinController.active,
      isInFreeSpins: isInFreeSpins,
    )) {
      return false;
    }

    return balanceController.decreaseBet();
  }

  bool depositGameMoney({
    required double amount,
    required BalanceController balanceController,
    required InsufficientFundsHintController insufficientHintController,
  }) {
    if (amount <= 0) return false;
    balanceController.depositGameMoney(amount);
    insufficientHintController.clear();
    return true;
  }
}
