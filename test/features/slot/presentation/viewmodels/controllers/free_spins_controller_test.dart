import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';

void main() {
  test('restores the accumulated win for an active free-spin round', () {
    final controller = FreeSpinsController();

    controller.hydrate({
      'freeSpinsRemaining': 6,
      'freeSpinAccumulatedWin': 137.45,
      'freeSpinsAwardedThisRound': 15,
    });

    expect(controller.isInRound, isTrue);
    expect(controller.remaining, 6);
    expect(controller.accumulatedWin, 137.45);
    expect(controller.awardedThisRound, 15);

    controller.dispose();
  });

  test('tracks wins and retriggers in the current free-spin round', () {
    final controller = FreeSpinsController();

    controller.awardInitial(initialWin: 12.50);
    controller.recordRoundWin(7.25);
    controller.awardRetrigger();

    expect(controller.remaining, 15);
    expect(controller.accumulatedWin, 19.75);
    expect(controller.awardedThisRound, 15);

    controller.dispose();
  });

  test('clears persisted round totals after the free-spin round ends', () {
    final controller = FreeSpinsController()
      ..awardInitial(initialWin: 20)
      ..recordRoundWin(30);

    for (var index = 0; index < 10; index++) {
      controller.consumeOne();
    }
    controller.finishRound();

    expect(controller.remaining, 0);
    expect(controller.accumulatedWin, 0);
    expect(controller.awardedThisRound, 0);

    controller.dispose();
  });

  test('ignores stale round totals when there are no free spins left', () {
    final controller = FreeSpinsController();

    controller.hydrate({
      'freeSpinsRemaining': 0,
      'freeSpinAccumulatedWin': 999,
      'freeSpinsAwardedThisRound': 10,
    });

    expect(controller.isInRound, isFalse);
    expect(controller.accumulatedWin, 0);
    expect(controller.awardedThisRound, 0);

    controller.dispose();
  });
}
