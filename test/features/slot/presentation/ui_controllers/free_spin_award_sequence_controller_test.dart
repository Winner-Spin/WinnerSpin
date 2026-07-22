import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/models/free_spin_award_presentation_state.dart';
import 'package:winner_spin/features/slot/presentation/models/free_spin_presentation_state.dart';
import 'package:winner_spin/features/slot/presentation/models/pending_free_spin_award.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/free_spin_award_sequence_controller.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/free_spin_overlay_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/free_spins/free_spin_win_popup.dart';

void main() {
  test('restored retrigger does not add its persisted +5 twice', () {
    final freeSpinPresentation = FreeSpinPresentationState()
      ..restoreRound(accumulatedWin: 120, awarded: 15);
    final sequenceController = FreeSpinAwardSequenceController();

    sequenceController.startAwardTransition(
      pending: const PendingFreeSpinAward(
        value: 5,
        isRetrigger: true,
        winAmount: 40,
      ),
      freeSpinPresentation: freeSpinPresentation,
      awardPresentation: FreeSpinAwardPresentationState(),
      setState: (callback) => callback(),
      awardAlreadyApplied: true,
    );

    expect(freeSpinPresentation.awardedThisRound, 15);
    sequenceController.dispose();
  });

  testWidgets('reveals the deferred count when the retrigger popup is shown', (
    tester,
  ) async {
    final overlayKey = GlobalKey<OverlayState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Overlay(
          key: overlayKey,
          initialEntries: [
            OverlayEntry(builder: (_) => const SizedBox.expand()),
          ],
        ),
      ),
    );

    final awardPresentation = FreeSpinAwardPresentationState()
      ..startAward(
        const PendingFreeSpinAward(value: 5, isRetrigger: true, winAmount: 0),
      );
    final overlayController = FreeSpinOverlayController();
    final sequenceController = FreeSpinAwardSequenceController();

    expect(awardPresentation.displayedRemaining(12), 7);

    sequenceController.showPendingAwardPopup(
      awardPresentation: awardPresentation,
      overlayController: overlayController,
      overlay: overlayKey.currentState,
      scatterCells: const [],
      isMounted: () => true,
      setState: (callback) => callback(),
      continueAutoSpinIfIdle: () {},
    );

    expect(awardPresentation.displayedRemaining(12), 12);
    expect(overlayController.hasActiveOverlay, isTrue);
    await tester.pump();
    final popup = tester.widget<FreeSpinWinPopup>(
      find.byType(FreeSpinWinPopup),
    );
    expect(popup.imageProvider, isA<ResizeImage>());

    overlayController.dispose();
    sequenceController.dispose();
  });
}
