// ─────────────────────────────────────────────────────────────────────────
// ANTE BET (ÇİFTE ŞANS) RTP SIMULATION
// ─────────────────────────────────────────────────────────────────────────
//
// Stress-tests the engine with Ante Bet ALWAYS ON across all base spins.
//
// Ante Bet mechanics:
//   • Cost: 1.25× base bet (player pays 25% extra)
//   • Effect: doubles the Free Spins trigger rate for that base spin
//   • Payout: still computed against 1.0× base bet (per spec)
//   • Pool: records the full 1.25× as wagered (the 25% is house income)
//
// Expected behavior:
//   • Wagered denominator inflates by 25% per base spin
//   • FS rounds happen ~2× more often
//   • Net RTP should converge near baseline 96.5% if engine is well-calibrated
//
// Volume: 30,000,000 spins (matches baseline rtp_simulation_test).
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/game_mode.dart';

void main() {
  test('30M spin RTP simulation — ANTE BET ALWAYS ON', () {
    const totalSpinsToRun = 30000000;
    const baseBet = 100.0;
    const anteCost = baseBet * 1.25;       // 125 TL per base spin
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

    int fsRemaining = 0;
    int fsRoundsCompleted = 0;
    double sumOfFsRoundPayouts = 0;
    double currentFsRoundPayout = 0;

    // Tracks whether the current FS round was triggered by ante. Mirrors
    // GameViewModel._currentFsRoundFromAnte — keeps ante-FS payout
    // reduction active across all spins of an ante-triggered round.
    bool currentFsRoundFromAnte = false;

    // ─── Main loop ────────────────────────────────────────────────
    for (int i = 0; i < totalSpinsToRun; i++) {
      final isFreeSpin = fsRemaining > 0;
      final modeNow = pool.currentMode;
      modeCounts[modeNow] = (modeCounts[modeNow] ?? 0) + 1;

      if (isFreeSpin) {
        fsRemaining--;
        freeSpinsConsumed++;
      } else {
        // Ante Bet ALWAYS ON: pay 1.25x bet, pool records 1.25x as wagered.
        pool.recordBet(anteCost);
        totalWagered += anteCost;
        baseSpins++;

        // If a FS round just ended (last spin was the last FS), record total.
        if (currentFsRoundPayout > 0 && fsRemaining == 0) {
          sumOfFsRoundPayouts += currentFsRoundPayout;
          fsRoundsCompleted++;
          currentFsRoundPayout = 0;
        }
      }

      // Engine call:
      //   - Base spin: anteBet=true (always, since this test forces ante on)
      //   - FS spin: anteBet=currentFsRoundFromAnte (carry over the round's flag)
      final bool anteFlag = isFreeSpin ? currentFsRoundFromAnte : true;
      final result = SlotEngine.spin(
        pool,
        baseBet,
        isFreeSpins: isFreeSpin,
        anteBet: anteFlag,
      );

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
          // Base spin (anteBet=true here) triggered FS → mark round as ante.
          if (!isFreeSpin) {
            currentFsRoundFromAnte = true;
          }
        }
      }

      // Round ended (no more FS to consume) → clear ante flag for next round.
      if (currentFsRoundFromAnte && fsRemaining == 0 && isFreeSpin) {
        currentFsRoundFromAnte = false;
      }
    }

    // Close any open FS round
    if (currentFsRoundPayout > 0) {
      sumOfFsRoundPayouts += currentFsRoundPayout;
      fsRoundsCompleted++;
    }

    // ─── Output ───────────────────────────────────────────────────
    final actualRtp = totalWagered > 0 ? (totalPaidOut / totalWagered) * 100 : 0;
    final hitRate = (winningSpins / totalSpinsToRun) * 100;
    final fsTriggerRatePerBase = baseSpins > 0
        ? (initialFsTriggers / baseSpins) * 100
        : 0;
    final retriggerRatePerFsSpin = freeSpinsConsumed > 0
        ? (retriggers / freeSpinsConsumed) * 100
        : 0;
    final avgFsRoundPayout = fsRoundsCompleted > 0
        ? sumOfFsRoundPayouts / fsRoundsCompleted
        : 0;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('   ANTE BET (ÇİFTE ŞANS) RTP SIMULATION — 30M SPINS');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ ANTE BET CONFIG');
    buf.writeln('  Base bet            : ${baseBet.toStringAsFixed(2)} TL');
    buf.writeln('  Ante cost           : ${anteCost.toStringAsFixed(2)} TL (1.25x base)');
    buf.writeln('  Extra fee per spin  : ${(anteCost - baseBet).toStringAsFixed(2)} TL (25% overhead)');
    buf.writeln('  FS trigger rate     : DOUBLED on base spins');
    buf.writeln('');
    buf.writeln('▼ VOLUME');
    buf.writeln('  Total spins         : $totalSpinsToRun');
    buf.writeln('    ├─ Base game      : $baseSpins (${(baseSpins / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
    buf.writeln('    └─ Free spins     : $freeSpinsConsumed (${(freeSpinsConsumed / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
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
        '(${(maxSingleWin / baseBet).toStringAsFixed(1)}x bet) at spin #$maxWinSpinIndex');
    buf.writeln('');
    buf.writeln('▼ FREE SPINS (ante doubles trigger rate)');
    buf.writeln('  Initial triggers    : $initialFsTriggers');
    buf.writeln('  Retriggers          : $retriggers');
    buf.writeln('  Trigger rate (base) : ${fsTriggerRatePerBase.toStringAsFixed(3)}% per base spin '
        '(baseline w/o ante: ~0.385%)');
    buf.writeln('  Retrigger rate (FS) : ${retriggerRatePerFsSpin.toStringAsFixed(3)}% per FS spin');
    buf.writeln('  FS rounds completed : $fsRoundsCompleted');
    buf.writeln('  Avg FS round payout : ${avgFsRoundPayout.toStringAsFixed(2)} TL '
        '(${(avgFsRoundPayout / baseBet).toStringAsFixed(1)}x base bet)');
    buf.writeln('');
    buf.writeln('▼ MODE DISTRIBUTION');
    modeCounts.forEach((mode, count) {
      final pct = (count / totalSpinsToRun) * 100;
      final bar = '█' * (pct / 2).round();
      buf.writeln('  ${mode.name.padRight(9)} : ${count.toString().padLeft(8)} '
          '(${pct.toStringAsFixed(1).padLeft(5)}%) $bar');
    });
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');

    // ignore: avoid_print
    print(buf.toString());

    expect(totalPaidOut, greaterThanOrEqualTo(0));
  });
}
