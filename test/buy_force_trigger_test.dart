import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';

void main() {
  test('forceFsTrigger=true guarantees scatter trigger', () {
    final pool = PoolState(totalBetsPlaced: 100000, totalPaidOut: 50000, totalSpins: 200);
    int triggeredCount = 0;
    int scatterCount = 0;
    const trials = 100;
    for (int i = 0; i < trials; i++) {
      final result = SlotEngine.spin(
        pool,
        100,
        isFreeSpins: false,
        forceFsTrigger: true,
      );
      if (result.freeSpinsTriggered) triggeredCount++;
      if (result.scatterCount >= 4) scatterCount++;
    }
    print('triggered: $triggeredCount/$trials, with 4+ scatters: $scatterCount/$trials');
    expect(triggeredCount, trials, reason: 'Every spin should trigger FS');
    expect(scatterCount, trials, reason: 'Every spin should have 4+ scatters');
  });

  test('forceFsTrigger=true works on depleted pool (recovery mode)', () {
    // Recovery mode: payouts >> bets
    final pool = PoolState(totalBetsPlaced: 10000, totalPaidOut: 50000, totalSpins: 200);
    int triggeredCount = 0;
    const trials = 50;
    for (int i = 0; i < trials; i++) {
      final result = SlotEngine.spin(
        pool,
        100,
        isFreeSpins: false,
        forceFsTrigger: true,
      );
      if (result.freeSpinsTriggered) triggeredCount++;
    }
    print('depleted pool triggered: $triggeredCount/$trials');
    expect(triggeredCount, trials, reason: 'Force trigger must work even on depleted pool');
  });
}
