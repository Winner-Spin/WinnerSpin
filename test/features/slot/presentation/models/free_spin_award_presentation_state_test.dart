import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/presentation/models/free_spin_award_presentation_state.dart';
import 'package:winner_spin/features/slot/presentation/models/pending_free_spin_award.dart';

void main() {
  test('restored free-spin round resumes without a phantom award popup', () {
    final state = FreeSpinAwardPresentationState();

    expect(
      state.isRestoredRoundEntry(isInFreeSpins: true, result: null),
      isTrue,
    );
    expect(
      state.takeAwardForFreeSpinState(
        isInFreeSpins: true,
        result: null,
      ),
      isNull,
    );
  });

  test('a newly triggered round still creates the initial award popup', () {
    final state = FreeSpinAwardPresentationState();
    final result = _result(freeSpinsTriggered: true);

    expect(
      state.isRestoredRoundEntry(isInFreeSpins: true, result: result),
      isFalse,
    );

    final award = state.takeAwardForFreeSpinState(
      isInFreeSpins: true,
      result: result,
    );

    expect(award, isNotNull);
    expect(award!.value, 10);
    expect(award.isRetrigger, isFalse);
  });

  test('retrigger count stays hidden until the popup is revealed', () {
    final state = FreeSpinAwardPresentationState();
    state.startAward(
      const PendingFreeSpinAward(
        value: 5,
        isRetrigger: true,
        winAmount: 0,
      ),
    );

    expect(state.displayedRemaining(12), 7);

    state.revealDeferredAward();

    expect(state.displayedRemaining(12), 12);
  });
}

SpinResult _result({required bool freeSpinsTriggered}) {
  return SpinResult(
    initialGrid: List.generate(
      SlotEngine.columns,
      (_) => List.filled(SlotEngine.rows, 'H1'),
    ),
    tumbles: const [],
    totalWin: 0,
    tumbleCount: 0,
    freeSpinsTriggered: freeSpinsTriggered,
    scatterCount: freeSpinsTriggered ? 4 : 0,
    scatterPayout: 0,
  );
}
