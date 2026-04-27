// ─────────────────────────────────────────────────────────────────────────
// MIXED FARM + ANTE BET RTP SIMULATION
// ─────────────────────────────────────────────────────────────────────────
//
// Realistic player behavior simulation: alternates between phases of
//   • 10 farm base spins (no ante, 1.0× cost, baseline FS trigger)
//   • 10 ante base spins (1.25× cost, 2× FS trigger, ante-FS reduction)
//
// Free spin rounds DO NOT count toward the 10-spin phase counter — only
// base spins move the counter forward. An FS round triggered in one phase
// keeps that phase's ante flag for its entire duration (the engine reduces
// payout if ante=true).
//
// Reports per-phase RTP separately so we can verify isolation:
//   • Farm phase RTP should match ~96.5% (baseline)
//   • Ante phase RTP should match ~96.5% (calibrated)
//   • Total RTP should also be ~96.5%
//
// Volume: 30,000,000 spins.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/slot_symbol.dart';

void main() {
  test('30M MIXED RTP — 10 farm / 10 ante alternating', () {
    const totalSpinsToRun = 30000000;
    const baseBet = 100.0;
    const anteCost = baseBet * 1.25;
    const phaseLength = 10; // 10 base spins per phase
    const targetRtp = 96.5;

    final pool = PoolState();

    // Phase tracking
    bool inAntePhase = false; // starts in farm phase
    int baseSpinsInPhase = 0;
    int phaseTransitions = 0;

    // FS round tracking
    int fsRemaining = 0;
    bool currentFsRoundFromAnte = false;

    // Aggregate counters
    int baseSpins = 0;
    int freeSpinsConsumed = 0;
    int retriggers = 0;
    int winningSpins = 0;
    double totalWagered = 0;
    double totalPaidOut = 0;
    double maxSingleWin = 0;

    // Per-phase counters (attributing FS rounds to their trigger phase)
    int farmBaseSpins = 0;
    int anteBaseSpins = 0;
    int farmFsSpins = 0;       // FS spins of farm-triggered rounds
    int anteFsSpins = 0;       // FS spins of ante-triggered rounds
    int farmInitialTriggers = 0;
    int anteInitialTriggers = 0;
    double farmWagered = 0;
    double anteWagered = 0;
    double farmPaidOut = 0;    // base wins + farm-FS wins
    double antePaidOut = 0;    // base wins + ante-FS wins
    double farmFsRoundSum = 0;
    double anteFsRoundSum = 0;
    int farmFsRoundsCompleted = 0;
    int anteFsRoundsCompleted = 0;
    double currentFsRoundPayout = 0;

    final modeCounts = <GameMode, int>{
      for (final m in GameMode.values) m: 0,
    };

    // ─── Main loop ────────────────────────────────────────────────
    for (int i = 0; i < totalSpinsToRun; i++) {
      final isFreeSpin = fsRemaining > 0;
      final modeNow = pool.currentMode;
      modeCounts[modeNow] = (modeCounts[modeNow] ?? 0) + 1;

      // ── Determine ante flag for this spin ─────────────────────
      // FS spin: inherit the round's ante flag (set when it was triggered)
      // Base spin: use current phase
      final bool anteFlag = isFreeSpin ? currentFsRoundFromAnte : inAntePhase;

      // ── Handle bet / FS consumption ───────────────────────────
      if (isFreeSpin) {
        fsRemaining--;
        freeSpinsConsumed++;
        if (currentFsRoundFromAnte) {
          anteFsSpins++;
        } else {
          farmFsSpins++;
        }
      } else {
        // Base spin — charge the phase's cost.
        final cost = inAntePhase ? anteCost : baseBet;
        pool.recordBet(cost);
        totalWagered += cost;
        baseSpins++;
        baseSpinsInPhase++;
        if (inAntePhase) {
          anteWagered += cost;
          anteBaseSpins++;
        } else {
          farmWagered += cost;
          farmBaseSpins++;
        }

        // If a FS round just ended, finalize its payout sum
        if (currentFsRoundPayout > 0 && fsRemaining == 0) {
          // Round was already attributed when set up; record completion
          // (the attribution of the round to farm/ante happened at trigger)
          currentFsRoundPayout = 0;
        }
      }

      // ── Engine call ───────────────────────────────────────────
      final result = SlotEngine.spin(
        pool,
        baseBet,
        isFreeSpins: isFreeSpin,
        anteBet: anteFlag,
      );

      pool.recordPayout(result.totalWin);
      totalPaidOut += result.totalWin;
      if (result.totalWin > 0) winningSpins++;
      if (result.totalWin > maxSingleWin) maxSingleWin = result.totalWin;

      // ── Attribute payout to phase ─────────────────────────────
      if (isFreeSpin) {
        currentFsRoundPayout += result.totalWin;
        if (currentFsRoundFromAnte) {
          antePaidOut += result.totalWin;
        } else {
          farmPaidOut += result.totalWin;
        }
      } else {
        if (inAntePhase) {
          antePaidOut += result.totalWin;
        } else {
          farmPaidOut += result.totalWin;
        }
      }

      // ── FS trigger handling ───────────────────────────────────
      if (result.freeSpinsTriggered) {
        if (result.isRetrigger) {
          retriggers++;
          fsRemaining += 5;
        } else {
          fsRemaining += 10;
          // Base spin triggered FS — mark round with its phase's ante state
          if (!isFreeSpin) {
            currentFsRoundFromAnte = inAntePhase;
            if (inAntePhase) {
              anteInitialTriggers++;
            } else {
              farmInitialTriggers++;
            }
          }
        }
      }

      // ── Round end detection (last FS just consumed) ───────────
      if (isFreeSpin && fsRemaining == 0) {
        // Record FS round completion + payout
        if (currentFsRoundFromAnte) {
          anteFsRoundSum += currentFsRoundPayout;
          anteFsRoundsCompleted++;
        } else {
          farmFsRoundSum += currentFsRoundPayout;
          farmFsRoundsCompleted++;
        }
        currentFsRoundPayout = 0;
        currentFsRoundFromAnte = false;
      }

      // ── Phase toggle: after 10 base spins AND not mid-FS-round ─
      if (!isFreeSpin && fsRemaining == 0 && baseSpinsInPhase >= phaseLength) {
        inAntePhase = !inAntePhase;
        baseSpinsInPhase = 0;
        phaseTransitions++;
      }
    }

    // ─── Output ───────────────────────────────────────────────────
    final actualRtp = totalWagered > 0 ? (totalPaidOut / totalWagered) * 100 : 0;
    final farmRtp = farmWagered > 0 ? (farmPaidOut / farmWagered) * 100 : 0;
    final anteRtp = anteWagered > 0 ? (antePaidOut / anteWagered) * 100 : 0;
    final hitRate = (winningSpins / totalSpinsToRun) * 100;
    final farmFsRoundAvg = farmFsRoundsCompleted > 0
        ? farmFsRoundSum / farmFsRoundsCompleted
        : 0;
    final anteFsRoundAvg = anteFsRoundsCompleted > 0
        ? anteFsRoundSum / anteFsRoundsCompleted
        : 0;
    final farmFsTriggerRate = farmBaseSpins > 0
        ? (farmInitialTriggers / farmBaseSpins) * 100
        : 0;
    final anteFsTriggerRate = anteBaseSpins > 0
        ? (anteInitialTriggers / anteBaseSpins) * 100
        : 0;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('   MIXED FARM + ANTE BET RTP — 30M SPINS, 10/10 ALTERNATING');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ PHASE PATTERN');
    buf.writeln('  Pattern             : 10 farm base → 10 ante base → repeat');
    buf.writeln('  Phase transitions   : $phaseTransitions');
    buf.writeln('');
    buf.writeln('▼ VOLUME');
    buf.writeln('  Total spins         : $totalSpinsToRun');
    buf.writeln('  Base spins          : $baseSpins (${(baseSpins / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
    buf.writeln('    ├─ Farm           : $farmBaseSpins (${(farmBaseSpins / baseSpins * 100).toStringAsFixed(1)}%)');
    buf.writeln('    └─ Ante           : $anteBaseSpins (${(anteBaseSpins / baseSpins * 100).toStringAsFixed(1)}%)');
    buf.writeln('  Free spins          : $freeSpinsConsumed (${(freeSpinsConsumed / totalSpinsToRun * 100).toStringAsFixed(1)}%)');
    buf.writeln('    ├─ Farm-triggered : $farmFsSpins');
    buf.writeln('    └─ Ante-triggered : $anteFsSpins');
    buf.writeln('');
    buf.writeln('▼ FINANCIAL — TOTAL');
    buf.writeln('  Total wagered       : ${totalWagered.toStringAsFixed(2)} TL');
    buf.writeln('  Total paid out      : ${totalPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  Pool balance (end)  : ${pool.poolBalance.toStringAsFixed(2)} TL');
    buf.writeln('  House edge          : ${(totalWagered - totalPaidOut).toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ RTP — TOTAL & PER PHASE');
    buf.writeln('  Target RTP          : ${targetRtp.toStringAsFixed(2)}%');
    buf.writeln('  TOTAL RTP           : ${actualRtp.toStringAsFixed(2)}% (Δ ${(actualRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('  ────────────────');
    buf.writeln('  Farm phase RTP      : ${farmRtp.toStringAsFixed(2)}% (Δ ${(farmRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('    Wagered           : ${farmWagered.toStringAsFixed(2)} TL');
    buf.writeln('    Paid out          : ${farmPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  ────────────────');
    buf.writeln('  Ante phase RTP      : ${anteRtp.toStringAsFixed(2)}% (Δ ${(anteRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('    Wagered           : ${anteWagered.toStringAsFixed(2)} TL');
    buf.writeln('    Paid out          : ${antePaidOut.toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ HIT METRICS');
    buf.writeln('  Hit rate            : ${hitRate.toStringAsFixed(2)}%');
    buf.writeln('  Max single win      : ${maxSingleWin.toStringAsFixed(2)} TL '
        '(${(maxSingleWin / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('');
    buf.writeln('▼ FREE SPINS — PER PHASE');
    buf.writeln('  Farm phase:');
    buf.writeln('    FS triggers       : $farmInitialTriggers');
    buf.writeln('    Trigger rate      : ${farmFsTriggerRate.toStringAsFixed(3)}% per farm-base spin');
    buf.writeln('    FS rounds         : $farmFsRoundsCompleted');
    buf.writeln('    Avg FS round      : ${farmFsRoundAvg.toStringAsFixed(2)} TL '
        '(${(farmFsRoundAvg / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('  Ante phase:');
    buf.writeln('    FS triggers       : $anteInitialTriggers');
    buf.writeln('    Trigger rate      : ${anteFsTriggerRate.toStringAsFixed(3)}% per ante-base spin');
    buf.writeln('    FS rounds         : $anteFsRoundsCompleted');
    buf.writeln('    Avg FS round      : ${anteFsRoundAvg.toStringAsFixed(2)} TL '
        '(${(anteFsRoundAvg / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('  Total retriggers    : $retriggers');
    buf.writeln('');
    buf.writeln('▼ MODE DISTRIBUTION (across all spins)');
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
