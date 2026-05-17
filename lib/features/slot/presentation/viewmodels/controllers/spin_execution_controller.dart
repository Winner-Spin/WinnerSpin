import 'package:flutter/foundation.dart';

import '../../../domain/engine/spin_task.dart';
import '../../../domain/models/pool_state.dart';

class SpinExecutionController {
  Future<SpinTaskOutput> run({
    required PoolState pool,
    required double betAmount,
    required bool isFreeSpins,
    required bool anteBet,
    required bool buyFs,
    bool forceFsTrigger = false,
  }) {
    return compute(
      runSlotSpinTask,
      SpinTaskInput(
        pool: pool,
        betAmount: betAmount,
        isFreeSpins: isFreeSpins,
        anteBet: anteBet,
        buyFs: buyFs,
        forceFsTrigger: forceFsTrigger,
      ),
    );
  }
}
