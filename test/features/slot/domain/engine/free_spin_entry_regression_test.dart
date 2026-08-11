import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/engine_runtime.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/enums/game_mode.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/ante_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_result_settlement_controller.dart';

void main() {
  group('initial Free Spins entry math', () {
    test('cupcake pays 3x, 5x, and 10x for 4, 5, and 6 symbols', () {
      final cupcake = SymbolRegistry.byId('cupcake');

      expect(cupcake, isNotNull);
      expect(cupcake!.getScatterPayoutForCount(4), 3);
      expect(cupcake.getScatterPayoutForCount(5), 5);
      expect(cupcake.getScatterPayoutForCount(6), 10);
    });

    test('bought entry guarantees scatters without a regular cluster win', () {
      resetEngineRngForTesting(1729);
      final result = SlotEngine.spin(
        _wellFundedJackpotPool(),
        100,
        forceFsTrigger: true,
      );

      expect(result.freeSpinsTriggered, isTrue);
      expect(result.scatterCount, inInclusiveRange(4, 6));
      expect(result.baseWin, 0);
      expect(_largestRegularCount(result.initialGrid), lessThan(8));
    });

    test('natural entry guarantees scatters without a regular cluster win', () {
      resetEngineRngForTesting(20260811);
      final pool = _wellFundedJackpotPool();
      SpinResult? trigger;

      for (var spin = 0; spin < 10000 && trigger == null; spin++) {
        final result = SlotEngine.spin(pool, 100);
        if (result.freeSpinsTriggered) trigger = result;
      }

      expect(trigger, isNotNull, reason: 'Seeded jackpot run must trigger FS.');
      expect(trigger!.scatterCount, inInclusiveRange(4, 6));
      expect(trigger.baseWin, 0);
      expect(_largestRegularCount(trigger.initialGrid), lessThan(8));
    });
  });

  group('Free Spins entry accounting invariants', () {
    test('entry win remains the displayed Free Spins accumulated win', () {
      final freeSpins = FreeSpinsController();
      final ante = AnteController();
      final settlement = SpinResultSettlementController();

      final awarded = settlement.applyFreeSpinAward(
        result: _entryResult(totalWin: 50),
        freeSpinsController: freeSpins,
        anteController: ante,
        currentSpinFromBuy: false,
      );

      expect(awarded, isTrue);
      expect(freeSpins.remaining, 10);
      expect(freeSpins.accumulatedWin, 50);

      freeSpins.dispose();
      ante.dispose();
    });

    test('pool mode is recalculated after a payout instead of being locked', () {
      final pool = PoolState(
        totalBetsPlaced: 1000,
        totalPaidOut: 0,
        totalSpins: 50,
      );

      expect(pool.currentMode, GameMode.jackpot);

      pool.recordPayout(2000);

      expect(pool.currentMode, GameMode.recovery);
    });
  });
}

PoolState _wellFundedJackpotPool() => PoolState(
  totalBetsPlaced: 1000000000,
  totalPaidOut: 0,
  totalSpins: 200,
);

int _largestRegularCount(List<List<String>> grid) {
  final counts = <String, int>{};
  for (final path in grid.expand((column) => column)) {
    final symbol = SymbolRegistry.byPath(path);
    if (symbol?.isRegular ?? false) {
      counts[path] = (counts[path] ?? 0) + 1;
    }
  }
  if (counts.isEmpty) return 0;
  return counts.values.reduce((largest, count) {
    return count > largest ? count : largest;
  });
}

SpinResult _entryResult({required double totalWin}) {
  return SpinResult(
    initialGrid: List.generate(
      SlotEngine.columns,
      (_) => List.filled(SlotEngine.rows, ''),
    ),
    tumbles: const [],
    totalWin: totalWin,
    tumbleCount: 0,
    freeSpinsTriggered: true,
    scatterCount: 4,
    scatterPayout: totalWin,
  );
}
