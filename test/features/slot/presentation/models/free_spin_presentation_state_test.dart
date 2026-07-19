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
}
