import '../../../domain/models/spin_result.dart';
import '../../../domain/models/symbol_registry.dart';

class SpinAvailabilityController {
  bool canBuyFreeSpins({
    required bool isBusy,
    required bool isAutoSpinning,
    required bool isInFreeSpins,
    required bool canAffordBuyFeature,
  }) {
    return !isBusy && !isAutoSpinning && !isInFreeSpins && canAffordBuyFeature;
  }

  bool canSpinForUi({
    required bool isInFreeSpins,
    required bool canAffordDisplayedBet,
  }) {
    return isInFreeSpins || canAffordDisplayedBet;
  }

  bool canSpin({required bool isInFreeSpins, required bool canAffordBet}) {
    return isInFreeSpins || canAffordBet;
  }

  bool shouldPulseLandingScatters({
    required bool isInFreeSpins,
    required SpinResult? pendingResult,
  }) {
    if (isInFreeSpins) return false;
    if (pendingResult == null || pendingResult.freeSpinsTriggered) {
      return false;
    }

    final scatterPath = SymbolRegistry.all
        .firstWhere((symbol) => symbol.isScatter)
        .assetPath;
    final scatterCount = pendingResult.initialGrid
        .expand((column) => column)
        .where((path) => path == scatterPath)
        .length;

    return scatterCount >= 4;
  }
}
