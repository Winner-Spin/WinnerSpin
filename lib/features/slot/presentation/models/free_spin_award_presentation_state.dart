import '../../domain/models/spin_result.dart';
import 'pending_free_spin_award.dart';

class FreeSpinAwardPresentationState {
  bool wasInFreeSpins = false;
  bool showTransition = false;
  Object? lastAwardPopupResult;
  PendingFreeSpinAward? pendingPopup;
  bool sequenceActive = false;
  bool summaryPopupVisible = false;
  bool deferInitialVisualMode = false;
  int scatterPulseTrigger = 0;
  int _deferredVisibleAward = 0;

  bool isVisualMode(bool isInFreeSpins) {
    return isInFreeSpins && !deferInitialVisualMode;
  }

  int displayedRemaining(int actualRemaining) {
    return (actualRemaining - _deferredVisibleAward)
        .clamp(0, actualRemaining)
        .toInt();
  }

  bool isRestoredRoundEntry({
    required bool isInFreeSpins,
    required SpinResult? result,
  }) {
    return isInFreeSpins && !wasInFreeSpins && result == null;
  }

  PendingFreeSpinAward? takeAwardForFreeSpinState({
    required bool isInFreeSpins,
    required SpinResult? result,
  }) {
    final isNewAward =
        result != null &&
        result.freeSpinsTriggered &&
        !identical(result, lastAwardPopupResult);

    if (isInFreeSpins && !wasInFreeSpins) {
      lastAwardPopupResult = result;
      if (result == null || !result.freeSpinsTriggered) return null;
      final isRetrigger = result.isRetrigger;
      return PendingFreeSpinAward(
        value: isRetrigger ? 5 : 10,
        isRetrigger: isRetrigger,
        winAmount: result.totalWin,
      );
    }

    if (isInFreeSpins && isNewAward && result.isRetrigger) {
      lastAwardPopupResult = result;
      return PendingFreeSpinAward(
        value: 5,
        isRetrigger: true,
        winAmount: result.totalWin,
      );
    }

    return null;
  }

  void updateFreeSpinMode(bool isInFreeSpins) {
    wasInFreeSpins = isInFreeSpins;
    if (!isInFreeSpins) {
      _deferredVisibleAward = 0;
    }
  }

  void startAward(PendingFreeSpinAward pending) {
    if (pending.isRetrigger) {
      showTransition = false;
      _deferredVisibleAward += pending.value;
    } else {
      deferInitialVisualMode = true;
    }
    pendingPopup = pending;
  }

  bool get hasPendingPopup => pendingPopup != null;

  PendingFreeSpinAward? takePendingPopup() {
    final pending = pendingPopup;
    pendingPopup = null;
    return pending;
  }

  void clearPendingPopup() {
    pendingPopup = null;
  }

  void beginSequence() {
    sequenceActive = true;
  }

  void endSequence() {
    sequenceActive = false;
  }

  void revealDeferredAward() {
    _deferredVisibleAward = 0;
  }

  void showTransitionOverlay() {
    showTransition = true;
  }

  void hideTransitionOverlay() {
    showTransition = false;
  }

  void revealVisualMode() {
    deferInitialVisualMode = false;
  }

  void beginSummary() {
    summaryPopupVisible = true;
  }

  void endSummary() {
    summaryPopupVisible = false;
  }

  void triggerScatterPulse() {
    scatterPulseTrigger++;
  }

  void clearScatterPulse() {
    scatterPulseTrigger = 0;
  }
}
