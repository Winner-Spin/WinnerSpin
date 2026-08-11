import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/models/free_spin_presentation_state.dart';

void main() {
  test('restores the visible free-spin summary after app recreation', () {
    final state = FreeSpinPresentationState()
      ..capturePendingSpinWin(50)
      ..restoreRound(accumulatedWin: 245.75, awarded: 15);

    expect(state.accumulatedWin, 245.75);
    expect(state.awardedThisRound, 15);
    expect(state.pendingSpinWin, 0);
  });

  test('captures a natural entry win after a previous winning round', () {
    final state = _startRoundAfterPreviousWin();

    expect(state.shouldCaptureLastWin(10), isTrue);

    state
      ..capturePendingSpinWin(10)
      ..commitPendingSpinWin();

    expect(state.accumulatedWin, 10);
  });

  test('captures a bought entry win after a previous winning round', () {
    final state = _startRoundAfterPreviousWin();

    expect(state.shouldCaptureLastWin(10), isTrue);

    state.captureBuySpinWin(10);

    expect(state.accumulatedWin, 10);
  });
}

FreeSpinPresentationState _startRoundAfterPreviousWin() {
  final state = FreeSpinPresentationState()
    ..updateFreeSpinMode(true)
    ..updateLastSeenWin(25)
    ..updateFreeSpinMode(false);

  expect(state.shouldResetRound(true), isTrue);
  state
    ..resetRound()
    ..updateFreeSpinMode(true);
  return state;
}
