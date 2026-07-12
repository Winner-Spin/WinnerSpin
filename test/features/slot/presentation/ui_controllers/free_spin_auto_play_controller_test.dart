import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/free_spin_auto_play_controller.dart';

void main() {
  testWidgets('does not spin before the award popup is acknowledged', (
    tester,
  ) async {
    final controller = FreeSpinAutoPlayController();
    var spinCalls = 0;

    controller.pauseForAwardAcknowledgement();
    controller.continueIfReady(
      canStart: () => true,
      spin: () => spinCalls++,
      delay: const Duration(milliseconds: 10),
    );
    await tester.pump(const Duration(milliseconds: 20));

    expect(spinCalls, 0);

    controller.acknowledgeAward();
    controller.continueIfReady(
      canStart: () => true,
      spin: () => spinCalls++,
      delay: const Duration(milliseconds: 10),
    );
    await tester.pump(const Duration(milliseconds: 9));
    expect(spinCalls, 0);

    await tester.pump(const Duration(milliseconds: 1));
    expect(spinCalls, 1);

    controller.dispose();
  });

  testWidgets('rechecks presentation readiness when the delay expires', (
    tester,
  ) async {
    final controller = FreeSpinAutoPlayController();
    var canStart = true;
    var spinCalls = 0;

    controller.continueIfReady(
      canStart: () => canStart,
      spin: () => spinCalls++,
      delay: const Duration(milliseconds: 10),
    );
    canStart = false;
    await tester.pump(const Duration(milliseconds: 10));
    expect(spinCalls, 0);

    canStart = true;
    controller.continueIfReady(
      canStart: () => canStart,
      spin: () => spinCalls++,
      delay: const Duration(milliseconds: 10),
    );
    await tester.pump(const Duration(milliseconds: 10));
    expect(spinCalls, 1);

    controller.dispose();
  });

  testWidgets('an award popup cancels an already scheduled free spin', (
    tester,
  ) async {
    final controller = FreeSpinAutoPlayController();
    var spinCalls = 0;

    controller.continueIfReady(
      canStart: () => true,
      spin: () => spinCalls++,
      delay: const Duration(milliseconds: 10),
    );
    controller.pauseForAwardAcknowledgement();
    await tester.pump(const Duration(milliseconds: 20));

    expect(spinCalls, 0);
    expect(controller.awaitingAwardAcknowledgement, isTrue);

    controller.dispose();
  });

  testWidgets('coalesces duplicate continuation requests', (tester) async {
    final controller = FreeSpinAutoPlayController();
    var spinCalls = 0;

    void requestContinuation() {
      controller.continueIfReady(
        canStart: () => true,
        spin: () => spinCalls++,
        delay: const Duration(milliseconds: 10),
      );
    }

    requestContinuation();
    requestContinuation();
    await tester.pump(const Duration(milliseconds: 10));

    expect(spinCalls, 1);
    controller.dispose();
  });
}
