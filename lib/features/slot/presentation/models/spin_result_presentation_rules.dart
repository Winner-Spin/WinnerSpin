import '../../domain/models/spin_result.dart';

class SpinResultPresentationRules {
  const SpinResultPresentationRules._();

  static bool hasMultiplierSequence(SpinResult? result) {
    return result != null &&
        result.baseWin > 0 &&
        result.finalMultipliers.isNotEmpty;
  }

  static bool shouldShowMainWinSequence({
    required SpinResult? result,
    required bool lastSpinWasFreeSpin,
    required bool isFreeSpinVisualMode,
  }) {
    return hasMultiplierSequence(result) &&
        !(lastSpinWasFreeSpin && !isFreeSpinVisualMode);
  }

  static bool hasFreeSpinWinFlight({
    required bool isInFreeSpins,
    required bool isCurrentSpinFromBuy,
    required SpinResult? result,
  }) {
    return isInFreeSpins &&
        !isCurrentSpinFromBuy &&
        result != null &&
        result.totalWin > 0;
  }
}
