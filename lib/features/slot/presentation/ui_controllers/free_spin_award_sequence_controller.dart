import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/free_spin_award_presentation_state.dart';
import '../models/free_spin_presentation_state.dart';
import '../models/game_presentation_timings.dart';
import '../models/pending_free_spin_award.dart';
import '../models/scatter_cell.dart';
import 'free_spin_overlay_controller.dart';

class FreeSpinAwardSequenceController {
  Timer? _freeSpinTransitionTimer;
  Timer? _scatterPulseTimer;

  bool get scatterPulseActive => _scatterPulseTimer?.isActive == true;

  void startAwardTransition({
    required PendingFreeSpinAward pending,
    required FreeSpinPresentationState freeSpinPresentation,
    required FreeSpinAwardPresentationState awardPresentation,
    required void Function(VoidCallback callback) setState,
    bool awardAlreadyApplied = false,
  }) {
    _freeSpinTransitionTimer?.cancel();
    if (!awardAlreadyApplied) {
      freeSpinPresentation.recordAward(
        pending.value,
        isRetrigger: pending.isRetrigger,
      );
    }

    setState(() {
      awardPresentation.startAward(pending);
    });
  }

  void showPendingAwardPopup({
    required FreeSpinAwardPresentationState awardPresentation,
    required FreeSpinOverlayController overlayController,
    required OverlayState? overlay,
    required List<ScatterCell> scatterCells,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    if (!awardPresentation.hasPendingPopup ||
        overlayController.hasActiveOverlay) {
      return;
    }

    final pending = awardPresentation.takePendingPopup();
    if (pending == null) return;
    _showAwardSequence(
      pending: pending,
      awardPresentation: awardPresentation,
      overlayController: overlayController,
      overlay: overlay,
      scatterCells: scatterCells,
      isMounted: isMounted,
      setState: setState,
      continueAutoSpinIfIdle: continueAutoSpinIfIdle,
    );
  }

  void showSummaryPopup({
    required FreeSpinPresentationState freeSpinPresentation,
    required FreeSpinAwardPresentationState awardPresentation,
    required FreeSpinOverlayController overlayController,
    required OverlayState? overlay,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback releaseFsRoundHold,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    if (awardPresentation.summaryPopupVisible) return;
    if (overlay == null) {
      playExitTransitionThenRelease(
        awardPresentation: awardPresentation,
        isMounted: isMounted,
        setState: setState,
        releaseFsRoundHold: releaseFsRoundHold,
        continueAutoSpinIfIdle: continueAutoSpinIfIdle,
      );
      return;
    }

    overlayController.clear();
    awardPresentation.clearPendingPopup();

    setState(awardPresentation.beginSummary);
    overlayController.showSummaryPopup(
      overlay: overlay,
      totalWin: freeSpinPresentation.accumulatedWin,
      totalFreeSpins: freeSpinPresentation.awardedThisRound,
      onDismiss: () {
        if (!isMounted()) return;
        setState(awardPresentation.endSummary);
        playExitTransitionThenRelease(
          awardPresentation: awardPresentation,
          isMounted: isMounted,
          setState: setState,
          releaseFsRoundHold: releaseFsRoundHold,
          continueAutoSpinIfIdle: continueAutoSpinIfIdle,
        );
        continueAutoSpinIfIdle();
      },
    );
  }

  void playExitTransitionThenRelease({
    required FreeSpinAwardPresentationState awardPresentation,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback releaseFsRoundHold,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    _freeSpinTransitionTimer?.cancel();
    setState(awardPresentation.showTransitionOverlay);
    Future.delayed(GamePresentationTimings.freeSpinVisualRevealDelay, () {
      if (!isMounted() || !awardPresentation.showTransition) return;
      releaseFsRoundHold();
    });
    _freeSpinTransitionTimer = Timer(
      GamePresentationTimings.freeSpinTransitionDuration,
      () {
        if (!isMounted()) return;
        setState(awardPresentation.hideTransitionOverlay);
        continueAutoSpinIfIdle();
      },
    );
  }

  void _showAwardSequence({
    required PendingFreeSpinAward pending,
    required FreeSpinAwardPresentationState awardPresentation,
    required FreeSpinOverlayController overlayController,
    required OverlayState? overlay,
    required List<ScatterCell> scatterCells,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    awardPresentation.beginSequence();
    if (pending.isRetrigger) {
      _showScatterPulse(
        minScatterCount: 3,
        scatterCells: scatterCells,
        awardPresentation: awardPresentation,
        isMounted: isMounted,
        setState: setState,
        onComplete: () => _showWinPopup(
          pending: pending,
          awardPresentation: awardPresentation,
          overlayController: overlayController,
          overlay: overlay,
          setState: setState,
          continueAutoSpinIfIdle: continueAutoSpinIfIdle,
        ),
      );
      return;
    }

    _showScatterPulse(
      minScatterCount: 4,
      scatterCells: scatterCells,
      awardPresentation: awardPresentation,
      isMounted: isMounted,
      setState: setState,
      onComplete: () => _startInitialVisualTransition(
        pending: pending,
        awardPresentation: awardPresentation,
        overlayController: overlayController,
        overlay: overlay,
        isMounted: isMounted,
        setState: setState,
        continueAutoSpinIfIdle: continueAutoSpinIfIdle,
      ),
    );
  }

  void _showWinPopup({
    required PendingFreeSpinAward pending,
    required FreeSpinAwardPresentationState awardPresentation,
    required FreeSpinOverlayController overlayController,
    required OverlayState? overlay,
    required void Function(VoidCallback callback) setState,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    if (overlay == null) return;

    if (pending.isRetrigger) {
      setState(awardPresentation.revealDeferredAward);
    }

    overlayController.showWinPopup(
      overlay: overlay,
      value: pending.value,
      isRetrigger: pending.isRetrigger,
      winAmount: pending.winAmount,
      onDismiss: () {
        awardPresentation.endSequence();
        continueAutoSpinIfIdle();
      },
    );
  }

  void _startInitialVisualTransition({
    required PendingFreeSpinAward pending,
    required FreeSpinAwardPresentationState awardPresentation,
    required FreeSpinOverlayController overlayController,
    required OverlayState? overlay,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback continueAutoSpinIfIdle,
  }) {
    if (!isMounted()) return;
    setState(awardPresentation.showTransitionOverlay);
    Future.delayed(GamePresentationTimings.freeSpinVisualRevealDelay, () {
      if (!isMounted() || !awardPresentation.showTransition) return;
      setState(awardPresentation.revealVisualMode);
    });
    _freeSpinTransitionTimer = Timer(
      GamePresentationTimings.freeSpinTransitionDuration,
      () {
        if (!isMounted()) return;
        setState(awardPresentation.hideTransitionOverlay);
        _showWinPopup(
          pending: pending,
          awardPresentation: awardPresentation,
          overlayController: overlayController,
          overlay: overlay,
          setState: setState,
          continueAutoSpinIfIdle: continueAutoSpinIfIdle,
        );
      },
    );
  }

  void _showScatterPulse({
    required int minScatterCount,
    required List<ScatterCell> scatterCells,
    required FreeSpinAwardPresentationState awardPresentation,
    required bool Function() isMounted,
    required void Function(VoidCallback callback) setState,
    required VoidCallback onComplete,
  }) {
    if (scatterCells.length < minScatterCount) {
      onComplete();
      return;
    }

    _scatterPulseTimer?.cancel();
    setState(awardPresentation.triggerScatterPulse);
    _scatterPulseTimer = Timer(
      GamePresentationTimings.scatterPulseDuration,
      () {
        if (!isMounted()) return;
        setState(awardPresentation.clearScatterPulse);
        onComplete();
      },
    );
  }

  void dispose() {
    _freeSpinTransitionTimer?.cancel();
    _scatterPulseTimer?.cancel();
  }
}
