class FreeSpinPresentationState {
  double accumulatedWin = 0;
  double lastSeenLastWin = 0;
  double pendingSpinWin = 0;
  int awardedThisRound = 0;
  bool wasInFreeSpins = false;

  bool shouldResetRound(bool isInFreeSpins) {
    return isInFreeSpins && !wasInFreeSpins;
  }

  void resetRound() {
    accumulatedWin = 0;
    pendingSpinWin = 0;
    awardedThisRound = 0;
  }

  void updateFreeSpinMode(bool isInFreeSpins) {
    wasInFreeSpins = isInFreeSpins;
  }

  void recordAward(int value, {required bool isRetrigger}) {
    awardedThisRound = isRetrigger ? awardedThisRound + value : value;
  }

  bool shouldCaptureLastWin(double lastWin) {
    return lastWin > 0 && lastSeenLastWin == 0;
  }

  void updateLastSeenWin(double lastWin) {
    lastSeenLastWin = lastWin;
  }

  void captureBuySpinWin(double amount) {
    accumulatedWin = amount;
  }

  void capturePendingSpinWin(double amount) {
    pendingSpinWin = amount;
  }

  bool get hasPendingSpinWin => pendingSpinWin > 0;

  void clearPendingSpinWin() {
    pendingSpinWin = 0;
  }

  void addToAccumulatedWin(double amount) {
    accumulatedWin += amount;
  }

  void commitPendingSpinWin() {
    accumulatedWin += pendingSpinWin;
    pendingSpinWin = 0;
  }
}
