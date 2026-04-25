// ─────────────────────────────────────────────────────────────────────────
// RTP MONTE-CARLO SIMULATION
// ─────────────────────────────────────────────────────────────────────────
//
// Pure in-memory simulation of SlotEngine + PoolState.
// NO Firebase reads/writes — safe to run repeatedly without burning quota.
//
// Run with:
//   flutter test test/rtp_simulation_test.dart
//
// What it measures:
//   • Actual RTP vs target 96.5%
//   • Hit rate (% spins that pay > 0)
//   • FS trigger rate + retrigger rate
//   • Mode distribution (how often the pool sits in each GameMode)
//   • Pool balance trajectory
//   • Max single win, average win
//   • Recovery mode "stickiness" (avg consecutive spins stuck in recovery)
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/slot_symbol.dart';

void main() {
  test('10,000 spin RTP simulation (FS enabled — FINAL)', () {
    const totalSpinsToRun = 10000;
    const betAmount = 100.0;
    const targetRtp = 96.5;

    final pool = PoolState();

    // ─── Counters ─────────────────────────────────────────────────
    int baseSpins = 0;
    int freeSpinsConsumed = 0;
    int initialFsTriggers = 0;
    int retriggers = 0;
    int winningSpins = 0;

    double totalWagered = 0;
    double totalPaidOut = 0;
    double sumOfWins = 0;
    double maxSingleWin = 0;
    int maxWinSpinIndex = -1;

    final modeCounts = <GameMode, int>{
      for (final m in GameMode.values) m: 0,
    };

    // Recovery stickiness tracking
    int currentRecoveryStreak = 0;
    int maxRecoveryStreak = 0;
    final recoveryStreaks = <int>[];

    int fsRemaining = 0;
    int fsRoundsCompleted = 0;
    double sumOfFsRoundPayouts = 0;
    double currentFsRoundPayout = 0;

    // ─── Main loop ────────────────────────────────────────────────
    for (int i = 0; i < totalSpinsToRun; i++) {
      final isFreeSpin = fsRemaining > 0;
      final modeNow = pool.currentMode;
      modeCounts[modeNow] = (modeCounts[modeNow] ?? 0) + 1;

      // Recovery streak tracking
      if (modeNow == GameMode.recovery) {
        currentRecoveryStreak++;
        if (currentRecoveryStreak > maxRecoveryStreak) {
          maxRecoveryStreak = currentRecoveryStreak;
        }
      } else if (currentRecoveryStreak > 0) {
        recoveryStreaks.add(currentRecoveryStreak);
        currentRecoveryStreak = 0;
      }

      if (isFreeSpin) {
        fsRemaining--;
        freeSpinsConsumed++;
      } else {
        pool.recordBet(betAmount);
        totalWagered += betAmount;
        baseSpins++;

        // If a FS round just ended (we were in FS last spin), record its total
        if (currentFsRoundPayout > 0 && fsRemaining == 0) {
          sumOfFsRoundPayouts += currentFsRoundPayout;
          fsRoundsCompleted++;
          currentFsRoundPayout = 0;
        }
      }

      final result = SlotEngine.spin(pool, betAmount, isFreeSpins: isFreeSpin);

      pool.recordPayout(result.totalWin);
      totalPaidOut += result.totalWin;
      sumOfWins += result.totalWin;
      if (result.totalWin > maxSingleWin) {
        maxSingleWin = result.totalWin;
        maxWinSpinIndex = i;
      }
      if (result.totalWin > 0) winningSpins++;

      if (isFreeSpin) {
        currentFsRoundPayout += result.totalWin;
      }

      if (result.freeSpinsTriggered) {
        if (result.isRetrigger) {
          retriggers++;
          fsRemaining += 5;
        } else {
          initialFsTriggers++;
          fsRemaining += 10;
        }
      }
    }

    // Close any open recovery streak
    if (currentRecoveryStreak > 0) recoveryStreaks.add(currentRecoveryStreak);
    // Close any open FS round
    if (currentFsRoundPayout > 0) {
      sumOfFsRoundPayouts += currentFsRoundPayout;
      fsRoundsCompleted++;
    }

    // ─── Output ───────────────────────────────────────────────────
    final actualRtp = totalWagered > 0 ? (totalPaidOut / totalWagered) * 100 : 0;
    final hitRate = (winningSpins / totalSpinsToRun) * 100;
    final fsTriggerRate = baseSpins > 0
        ? (initialFsTriggers / baseSpins) * 100
        : 0;
    final retriggerRatePerFsSpin = freeSpinsConsumed > 0
        ? (retriggers / freeSpinsConsumed) * 100
        : 0;
    final avgFsRoundPayout = fsRoundsCompleted > 0
        ? sumOfFsRoundPayouts / fsRoundsCompleted
        : 0;
    final avgRecoveryStreak = recoveryStreaks.isNotEmpty
        ? recoveryStreaks.reduce((a, b) => a + b) / recoveryStreaks.length
        : 0;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('         RTP MONTE-CARLO SIMULATION RESULTS (FINAL)');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ VOLUME');
    buf.writeln('  Total spins         : $totalSpinsToRun');
    buf.writeln('    ├─ Base game      : $baseSpins (${(baseSpins / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
    buf.writeln('    └─ Free spins     : $freeSpinsConsumed (${(freeSpinsConsumed / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
    buf.writeln('  Bet per spin        : ${betAmount.toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ FINANCIAL');
    buf.writeln('  Total wagered       : ${totalWagered.toStringAsFixed(2)} TL');
    buf.writeln('  Total paid out      : ${totalPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  Pool balance (end)  : ${pool.poolBalance.toStringAsFixed(2)} TL');
    buf.writeln('  House edge          : ${(totalWagered - totalPaidOut).toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ RTP');
    buf.writeln('  Target RTP          : ${targetRtp.toStringAsFixed(2)}%');
    buf.writeln('  Actual RTP          : ${actualRtp.toStringAsFixed(2)}%');
    buf.writeln('  Deviation           : ${(actualRtp - targetRtp).toStringAsFixed(2)}%');
    buf.writeln('');
    buf.writeln('▼ HIT METRICS');
    buf.writeln('  Hit rate            : ${hitRate.toStringAsFixed(2)}%');
    buf.writeln('  Avg win / spin      : ${(sumOfWins / totalSpinsToRun).toStringAsFixed(2)} TL');
    buf.writeln('  Avg win / win       : ${winningSpins > 0 ? (sumOfWins / winningSpins).toStringAsFixed(2) : "0.00"} TL');
    buf.writeln('  Max single win      : ${maxSingleWin.toStringAsFixed(2)} TL '
        '(${(maxSingleWin / betAmount).toStringAsFixed(1)}x bet) at spin #$maxWinSpinIndex');
    buf.writeln('');
    buf.writeln('▼ FREE SPINS');
    buf.writeln('  Initial triggers    : $initialFsTriggers');
    buf.writeln('  Retriggers          : $retriggers');
    buf.writeln('  Trigger rate (base) : ${fsTriggerRate.toStringAsFixed(3)}% per base spin');
    buf.writeln('  Retrigger rate (FS) : ${retriggerRatePerFsSpin.toStringAsFixed(3)}% per FS spin');
    buf.writeln('  FS rounds completed : $fsRoundsCompleted');
    buf.writeln('  Avg FS round payout : ${avgFsRoundPayout.toStringAsFixed(2)} TL '
        '(${(avgFsRoundPayout / betAmount).toStringAsFixed(1)}x bet)');
    buf.writeln('');
    buf.writeln('▼ MODE DISTRIBUTION');
    modeCounts.forEach((mode, count) {
      final pct = (count / totalSpinsToRun) * 100;
      final bar = '█' * (pct / 2).round();
      buf.writeln('  ${mode.name.padRight(9)} : ${count.toString().padLeft(6)} '
          '(${pct.toStringAsFixed(1).padLeft(5)}%) $bar');
    });
    buf.writeln('');
    buf.writeln('▼ RECOVERY STICKINESS');
    buf.writeln('  Recovery streaks    : ${recoveryStreaks.length}');
    buf.writeln('  Max consecutive     : $maxRecoveryStreak spins');
    buf.writeln('  Avg streak length   : ${avgRecoveryStreak.toStringAsFixed(1)} spins');
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');

    // ignore: avoid_print
    print(buf.toString());

    expect(totalPaidOut, greaterThanOrEqualTo(0));
  });
}
