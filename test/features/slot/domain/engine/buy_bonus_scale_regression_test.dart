import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/engine_runtime.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';

void main() {
  test('bought round scales linearly with proportional pool history', () {
    for (var seed = 0; seed < 20; seed++) {
      final small = _runBoughtRound(
        seed: seed,
        bet: 100,
        historicalBets: 1000000,
        historicalPayouts: 965000,
      );
      final large = _runBoughtRound(
        seed: seed,
        bet: 5000,
        historicalBets: 50000000,
        historicalPayouts: 48250000,
      );

      expect(large.triggerX, closeTo(small.triggerX, 0.000000001));
      expect(large.freeSpinX, closeTo(small.freeSpinX, 0.000000001));
      expect(large.spinCount, small.spinCount);
    }
  });

  test('500k buy cannot concentrate the purchase price in its entry', () {
    const trials = 1000;
    var triggerX = 0.0;
    var freeSpinX = 0.0;
    var maxTriggerX = 0.0;

    resetEngineRngForTesting(20260811);
    for (var trial = 0; trial < trials; trial++) {
      final round = _runBoughtRoundWithoutRngReset(
        seed: trial,
        bet: 5000,
        historicalBets: 1000000,
        historicalPayouts: 965000,
      );
      triggerX += round.triggerX;
      freeSpinX += round.freeSpinX;
      maxTriggerX = max(maxTriggerX, round.triggerX);
    }

    final averageTriggerX = triggerX / trials;
    final averageFreeSpinX = freeSpinX / trials;
    final averageTriggerShare =
        averageTriggerX / (averageTriggerX + averageFreeSpinX);

    // ignore: avoid_print
    print(
      '500K buy: avg entry ${averageTriggerX.toStringAsFixed(2)}x, '
      'avg FS ${averageFreeSpinX.toStringAsFixed(2)}x, '
      'entry share ${(averageTriggerShare * 100).toStringAsFixed(1)}%, '
      'max entry ${maxTriggerX.toStringAsFixed(0)}x',
    );

    expect(maxTriggerX, lessThanOrEqualTo(10));
    expect(averageFreeSpinX, greaterThan(averageTriggerX * 5));
    expect(averageTriggerShare, lessThan(0.20));
  });
}

_BoughtRoundStats _runBoughtRound({
  required int seed,
  required double bet,
  required double historicalBets,
  required double historicalPayouts,
}) {
  resetEngineRngForTesting(seed);
  return _runBoughtRoundWithoutRngReset(
    seed: seed,
    bet: bet,
    historicalBets: historicalBets,
    historicalPayouts: historicalPayouts,
  );
}

_BoughtRoundStats _runBoughtRoundWithoutRngReset({
  required int seed,
  required double bet,
  required double historicalBets,
  required double historicalPayouts,
}) {
  final pool = PoolState(
    totalBetsPlaced: historicalBets,
    totalPaidOut: historicalPayouts,
    totalSpins: 200,
    modeRandom: Random(seed),
  );
  pool.recordBet(bet * SlotEngine.buyFeaturePriceMultiplier);

  final trigger = SlotEngine.spin(pool, bet, forceFsTrigger: true);
  pool.recordPayout(trigger.totalWin);

  var remaining = trigger.freeSpinsTriggered ? 10 : 0;
  var freeSpinWin = 0.0;
  var spinCount = 0;
  while (remaining > 0) {
    remaining--;
    spinCount++;
    expect(spinCount, lessThan(100), reason: 'Retrigger loop must terminate.');

    final result = SlotEngine.spin(pool, bet, isFreeSpins: true, buyFs: true);
    pool.recordPayout(result.totalWin);
    freeSpinWin += result.totalWin;
    if (result.freeSpinsTriggered && result.isRetrigger) {
      remaining += 5;
    }
  }

  return _BoughtRoundStats(
    triggerX: trigger.totalWin / bet,
    freeSpinX: freeSpinWin / bet,
    spinCount: spinCount,
  );
}

class _BoughtRoundStats {
  const _BoughtRoundStats({
    required this.triggerX,
    required this.freeSpinX,
    required this.spinCount,
  });

  final double triggerX;
  final double freeSpinX;
  final int spinCount;
}
