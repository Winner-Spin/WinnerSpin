class GamePresentationGuards {
  const GamePresentationGuards._();

  static bool canPromptBuyFreeSpins({
    required bool anteBetActive,
    required bool bigWinShowing,
    required bool isBusy,
    required bool celebrationActive,
    required bool canBuyFreeSpinsForUi,
  }) {
    return !anteBetActive &&
        !bigWinShowing &&
        !isBusy &&
        !celebrationActive &&
        canBuyFreeSpinsForUi;
  }

  static bool shouldReleaseCelebrationLock({
    required bool hasMultiplierSequence,
    required bool hasBigWin,
    required bool hasFreeSpinWinFlight,
  }) {
    return !hasMultiplierSequence && !hasBigWin && !hasFreeSpinWinFlight;
  }

  static bool shouldContinueAutoSpin({
    required bool celebrationActive,
    required bool freeSpinAwardSequenceActive,
    required bool hasPendingFreeSpinAward,
    required bool scatterPulseActive,
    required bool hasActiveFreeSpinOverlay,
    required bool showFreeSpinTransition,
    required bool fsSummaryPopupVisible,
  }) {
    return !celebrationActive &&
        !freeSpinAwardSequenceActive &&
        !hasPendingFreeSpinAward &&
        !scatterPulseActive &&
        !hasActiveFreeSpinOverlay &&
        !showFreeSpinTransition &&
        !fsSummaryPopupVisible;
  }
}
