import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_execution_controller.dart';

void main() {
  test('spin execution transfers pool state through compute', () async {
    final pool = PoolState(
      totalBetsPlaced: 1000000,
      totalPaidOut: 965000,
      totalSpins: 50,
    );

    final output = await SpinExecutionController().run(
      pool: pool,
      betAmount: 100,
      isFreeSpins: false,
      anteBet: false,
      buyFs: false,
    );

    expect(output.result.initialGrid, hasLength(SlotEngine.columns));
    expect(output.result.initialGrid.first, hasLength(SlotEngine.rows));
    expect(output.pool.totalSpins, 50);
  });
}
