import '../models/pool_state.dart';
import '../models/spin_result.dart';
import 'slot_engine.dart';

class SpinTaskInput {
  final PoolState pool;
  final double betAmount;
  final bool isFreeSpins;
  final bool anteBet;
  final bool buyFs;

  const SpinTaskInput({
    required this.pool,
    required this.betAmount,
    this.isFreeSpins = false,
    this.anteBet = false,
    this.buyFs = false,
  });
}

class SpinTaskOutput {
  final SpinResult result;
  final PoolState pool;

  const SpinTaskOutput({required this.result, required this.pool});
}

// The pool returned here carries the isolate-side mutations from
// PoolState.currentMode (session-mode lock), which would otherwise be lost
// across the isolate boundary. Callers must replace their pool reference.
SpinTaskOutput runSlotSpinTask(SpinTaskInput input) {
  final result = SlotEngine.spin(
    input.pool,
    input.betAmount,
    isFreeSpins: input.isFreeSpins,
    anteBet: input.anteBet,
    buyFs: input.buyFs,
  );
  return SpinTaskOutput(result: result, pool: input.pool);
}
