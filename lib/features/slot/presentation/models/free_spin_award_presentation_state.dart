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

  bool isVisualMode(bool isInFreeSpins) {
    return isInFreeSpins && !deferInitialVisualMode;
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
      final isRetrigger = result?.isRetrigger == true;
      return PendingFreeSpinAward(
        value: isRetrigger ? 5 : 10,
        isRetrigger: isRetrigger,
        winAmount: result?.totalWin ?? 0,
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
  }

  void startAward(PendingFreeSpinAward pending) {
    if (pending.isRetrigger) {
      showTransition = false;
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
