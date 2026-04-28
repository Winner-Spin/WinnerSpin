// ─────────────────────────────────────────────────────────────────────────
// TUMBLE / CASCADE DEPTH DISTRIBUTION DIAGNOSTIC
// ─────────────────────────────────────────────────────────────────────────
//
// Measures how often each cascade depth occurs in the engine.
// Counts both base-game spins and FS spins separately because their
// economy is very different (FS has ~10x more multipliers landing).
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';

void main() {
  test('10M spin tumble depth distribution', () {
    const totalSpinsToRun = 10000000;
    const betAmount = 100.0;

    final pool = PoolState();

    final baseTumbleHist = <int, int>{};
    final fsTumbleHist = <int, int>{};
    int baseMaxTumbles = 0;
    int fsMaxTumbles = 0;

    int fsRemaining = 0;

    for (int i = 0; i < totalSpinsToRun; i++) {
      final isFs = fsRemaining > 0;

      if (isFs) {
        fsRemaining--;
      } else {
        pool.recordBet(betAmount);
      }

      final result = SlotEngine.spin(pool, betAmount, isFreeSpins: isFs);
      pool.recordPayout(result.totalWin);

      if (isFs) {
        fsTumbleHist[result.tumbleCount] = (fsTumbleHist[result.tumbleCount] ?? 0) + 1;
        if (result.tumbleCount > fsMaxTumbles) fsMaxTumbles = result.tumbleCount;
      } else {
        baseTumbleHist[result.tumbleCount] = (baseTumbleHist[result.tumbleCount] ?? 0) + 1;
        if (result.tumbleCount > baseMaxTumbles) baseMaxTumbles = result.tumbleCount;
      }

      if (result.freeSpinsTriggered) {
        fsRemaining += result.isRetrigger ? 5 : 10;
      }
    }

    final baseTotal = baseTumbleHist.values.fold(0, (a, b) => a + b);
    final fsTotal = fsTumbleHist.values.fold(0, (a, b) => a + b);

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('         TUMBLE DEPTH DISTRIBUTION — 1M spins');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ BASE GAME ($baseTotal spins, max depth $baseMaxTumbles)');
    final baseSorted = baseTumbleHist.keys.toList()..sort();
    for (final depth in baseSorted) {
      final count = baseTumbleHist[depth]!;
      final pct = (count / baseTotal) * 100;
      final bar = '█' * (pct / 2).clamp(0, 50).round();
      buf.writeln('  ${depth.toString().padLeft(2)} tumble : '
          '${count.toString().padLeft(7)} '
          '(${pct.toStringAsFixed(2).padLeft(5)}%) $bar');
    }
    buf.writeln('');
    buf.writeln('▼ FREE SPINS ($fsTotal spins, max depth $fsMaxTumbles)');
    final fsSorted = fsTumbleHist.keys.toList()..sort();
    for (final depth in fsSorted) {
      final count = fsTumbleHist[depth]!;
      final pct = (count / fsTotal) * 100;
      final bar = '█' * (pct / 2).clamp(0, 50).round();
      buf.writeln('  ${depth.toString().padLeft(2)} tumble : '
          '${count.toString().padLeft(7)} '
          '(${pct.toStringAsFixed(2).padLeft(5)}%) $bar');
    }
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');

    // ignore: avoid_print
    print(buf.toString());

    expect(baseTotal + fsTotal, equals(totalSpinsToRun));
  });
}
