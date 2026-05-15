import '../models/pool_state.dart';
import '../models/spin_result.dart';
import 'slot_engine.dart';

class SpinTaskInput {
  final PoolState pool;
  final double betAmount;
  final bool isFreeSpins;
  final bool anteBet;
  final bool buyFs;
  final bool forceFsTrigger;

  const SpinTaskInput({
    required this.pool,
    required this.betAmount,
    this.isFreeSpins = false,
    this.anteBet = false,
    this.buyFs = false,
    this.forceFsTrigger = false,
  });
}

class SpinTaskOutput {
  final SpinResult result;
  final PoolState pool;

  const SpinTaskOutput({required this.result, required this.pool});
}

// Returns pool with isolate-side mutations; callers must replace their reference.
SpinTaskOutput runSlotSpinTask(SpinTaskInput input) {
  final result = SlotEngine.spin(
    input.pool,
    input.betAmount,
    isFreeSpins: input.isFreeSpins,
    anteBet: input.anteBet,
    buyFs: input.buyFs,
    forceFsTrigger: input.forceFsTrigger,
  );
  return SpinTaskOutput(result: result, pool: input.pool);
}
