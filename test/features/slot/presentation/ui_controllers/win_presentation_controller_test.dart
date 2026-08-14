import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/win_presentation_controller.dart';

void main() {
  testWidgets('waits for the final multiplier flight before final counting', (
    tester,
  ) async {
    final controller = WinPresentationController();
    addTearDown(controller.dispose);

    controller.start(baseWin: 100, multiplierValues: const [2], totalWin: 200);
    await tester.pump(WinPresentationController.holdAfterBaseCountUp);
    expect(controller.phase, WinPresentationPhase.multiplierCollecting);

    controller.onMultiplierLanded(0);
    await tester.pump(
      WinPresentationController.postLandPulse +
          WinPresentationController.formulaToFinalGap,
    );
    expect(controller.phase, WinPresentationPhase.multiplierCollecting);

    controller.onMultiplierPresentationComplete(0);
    await tester.pump(
      WinPresentationController.postLandPulse +
          WinPresentationController.formulaToFinalGap,
    );
    expect(controller.phase, WinPresentationPhase.finalCounting);

    await tester.pump(WinPresentationController.finalCountUpDuration);
    expect(controller.phase, WinPresentationPhase.done);
  });
}
