// ─────────────────────────────────────────────────────────────────────────
// REALISTIC PLAYER BEHAVIOR RTP SIMULATION
// ─────────────────────────────────────────────────────────────────────────
//
// Simulates a realistic mixed-mode player session, repeating this cycle:
//   1. 50 farm base spins (no ante, 1.0× cost, baseline FS trigger)
//   2. 50 ante base spins (1.25× cost, 2× FS trigger, ante-FS reduction)
//   3. 1  buy bonus       (100× cost, guaranteed FS round, buy-FS boost)
//
// The cycle repeats 500,000 times → ~50.5M base actions + triggered FS rounds.
//
// Free spins always inherit the originating phase's flags (ante or buy)
// so multiplier scaling stays consistent across an entire round.
//
// Reports per-phase RTP separately + total RTP. All three phases should
// converge to ~96.5% RTP independently if the engine is well-isolated.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/game_mode.dart';

void main() {
  test('500K cycles of (50 farm + 50 ante + 1 buy)', () {
    const cycleCount = 500000;
    const farmSpinsPerCycle = 50;
    const anteSpinsPerCycle = 50;
    const baseBet = 100.0;
    const anteCost = baseBet * 1.25;
    const buyCost = baseBet * SlotEngine.buyFeaturePriceMultiplier;
    const targetRtp = 96.5;

    final pool = PoolState();

    // ─── Round-level state ────────────────────────────────────────
    int fsRemaining = 0;
    bool currentFsRoundFromAnte = false;
    bool currentFsRoundFromBuy = false;

    // ─── Aggregate counters ───────────────────────────────────────
    int totalSpins = 0;
    int totalFsSpins = 0;
    int retriggers = 0;
    int winningSpins = 0;
    double totalWagered = 0;
    double totalPaidOut = 0;
    double maxSingleWin = 0;

    // ─── Per-phase counters ───────────────────────────────────────
    // Wagered → which channel paid the cost
    // PaidOut → which channel "owns" the FS round (for FS spins)
    //          or which phase the base spin belonged to
    int farmBaseSpins = 0;
    int anteBaseSpins = 0;
    int buyCount = 0;
    int farmFsSpins = 0;
    int anteFsSpins = 0;
    int buyFsSpins = 0;
    int farmFsTriggers = 0;
    int anteFsTriggers = 0;
    double farmWagered = 0;
    double anteWagered = 0;
    double buyWagered = 0;
    double farmPaidOut = 0; // farm base wins + farm-FS wins
    double antePaidOut = 0; // ante base wins + ante-FS wins
    double buyPaidOut = 0; // bought-FS wins only
    double farmFsRoundSum = 0;
    double anteFsRoundSum = 0;
    double buyFsRoundSum = 0;
    int farmFsRounds = 0;
    int anteFsRounds = 0;
    int buyFsRounds = 0;

    final modeCounts = <GameMode, int>{
      for (final m in GameMode.values) m: 0,
    };

    // ─── Helper: execute one spin and update all state ────────────
    void runSpin({required bool isFreeSpin, required bool antePhase}) {
      final modeNow = pool.currentMode;
      modeCounts[modeNow] = (modeCounts[modeNow] ?? 0) + 1;

      // Determine flags for engine call
      final bool anteFlag = isFreeSpin ? currentFsRoundFromAnte : antePhase;
      final bool buyFlag = isFreeSpin && currentFsRoundFromBuy;

      // Engine
      final result = SlotEngine.spin(
        pool,
        baseBet,
        isFreeSpins: isFreeSpin,
        anteBet: anteFlag,
        buyFs: buyFlag,
      );

      pool.recordPayout(result.totalWin);
      totalPaidOut += result.totalWin;
      totalSpins++;
      if (result.totalWin > 0) winningSpins++;
      if (result.totalWin > maxSingleWin) maxSingleWin = result.totalWin;

      // Attribute payout to channel
      if (isFreeSpin) {
        totalFsSpins++;
        if (currentFsRoundFromBuy) {
          buyPaidOut += result.totalWin;
          buyFsSpins++;
          buyFsRoundSum += result.totalWin;
        } else if (currentFsRoundFromAnte) {
          antePaidOut += result.totalWin;
          anteFsSpins++;
          anteFsRoundSum += result.totalWin;
        } else {
          farmPaidOut += result.totalWin;
          farmFsSpins++;
          farmFsRoundSum += result.totalWin;
        }
      } else {
        if (antePhase) {
          antePaidOut += result.totalWin;
        } else {
          farmPaidOut += result.totalWin;
        }
      }

      // FS trigger handling
      if (result.freeSpinsTriggered) {
        if (result.isRetrigger) {
          retriggers++;
          fsRemaining += 5;
        } else {
          fsRemaining += 10;
          if (!isFreeSpin) {
            // Base spin triggered FS — flag round with originating phase
            currentFsRoundFromAnte = antePhase;
            currentFsRoundFromBuy = false; // base spins don't initiate buy
            if (antePhase) {
              anteFsTriggers++;
            } else {
              farmFsTriggers++;
            }
          }
        }
      }

      // Round-end detection — the FS spin that just consumed the last FS
      if (isFreeSpin && fsRemaining == 0) {
        if (currentFsRoundFromBuy) {
          buyFsRounds++;
        } else if (currentFsRoundFromAnte) {
          anteFsRounds++;
        } else {
          farmFsRounds++;
        }
        currentFsRoundFromAnte = false;
        currentFsRoundFromBuy = false;
      }
    }

    // ─── Helper: run N base spins of a phase, draining any FS rounds ─
    void runBasePhase(int spinCount, {required bool antePhase}) {
      int remaining = spinCount;
      while (remaining > 0 || fsRemaining > 0) {
        if (fsRemaining > 0) {
          fsRemaining--;
          runSpin(isFreeSpin: true, antePhase: antePhase);
        } else {
          // Base spin: charge cost
          if (antePhase) {
            pool.recordBet(anteCost);
            totalWagered += anteCost;
            anteWagered += anteCost;
            anteBaseSpins++;
          } else {
            pool.recordBet(baseBet);
            totalWagered += baseBet;
            farmWagered += baseBet;
            farmBaseSpins++;
          }
          runSpin(isFreeSpin: false, antePhase: antePhase);
          remaining--;
        }
      }
    }

    // ─── Helper: run one buy bonus round ──────────────────────────
    void runBuyRound() {
      pool.recordBet(buyCost);
      totalWagered += buyCost;
      buyWagered += buyCost;
      buyCount++;
      fsRemaining = 10;
      currentFsRoundFromBuy = true;
      while (fsRemaining > 0) {
        fsRemaining--;
        runSpin(isFreeSpin: true, antePhase: false);
      }
    }

    // ─── Main cycle loop ──────────────────────────────────────────
    for (int cycle = 0; cycle < cycleCount; cycle++) {
      runBasePhase(farmSpinsPerCycle, antePhase: false);
      runBasePhase(anteSpinsPerCycle, antePhase: true);
      runBuyRound();
    }

    // ─── Output ───────────────────────────────────────────────────
    final actualRtp = totalWagered > 0 ? (totalPaidOut / totalWagered) * 100 : 0;
    final farmRtp = farmWagered > 0 ? (farmPaidOut / farmWagered) * 100 : 0;
    final anteRtp = anteWagered > 0 ? (antePaidOut / anteWagered) * 100 : 0;
    final buyRtp = buyWagered > 0 ? (buyPaidOut / buyWagered) * 100 : 0;
    final hitRate = (winningSpins / totalSpins) * 100;

    final farmFsRoundAvg = farmFsRounds > 0 ? farmFsRoundSum / farmFsRounds : 0;
    final anteFsRoundAvg = anteFsRounds > 0 ? anteFsRoundSum / anteFsRounds : 0;
    final buyFsRoundAvg = buyFsRounds > 0 ? buyFsRoundSum / buyFsRounds : 0;

    final farmTriggerRate = farmBaseSpins > 0
        ? (farmFsTriggers / farmBaseSpins) * 100
        : 0;
    final anteTriggerRate = anteBaseSpins > 0
        ? (anteFsTriggers / anteBaseSpins) * 100
        : 0;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('     REALISTIC PLAYER RTP — 500K × (50 FARM + 50 ANTE + 1 BUY)');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ CYCLE PATTERN');
    buf.writeln('  Pattern             : 50 farm → 50 ante → 1 buy → repeat');
    buf.writeln('  Cycles completed    : $cycleCount');
    buf.writeln('  Buys executed       : $buyCount');
    buf.writeln('');
    buf.writeln('▼ VOLUME');
    buf.writeln('  Total spins         : $totalSpins');
    buf.writeln('    ├─ Farm base      : $farmBaseSpins');
    buf.writeln('    ├─ Ante base      : $anteBaseSpins');
    buf.writeln('    └─ Free spins     : $totalFsSpins');
    buf.writeln('       ├─ Farm-FS     : $farmFsSpins');
    buf.writeln('       ├─ Ante-FS     : $anteFsSpins');
    buf.writeln('       └─ Buy-FS      : $buyFsSpins');
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
    buf.writeln('  FARM phase RTP      : ${farmRtp.toStringAsFixed(2)}% (Δ ${(farmRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('    Wagered           : ${farmWagered.toStringAsFixed(2)} TL  ($farmBaseSpins base spins)');
    buf.writeln('    Paid out          : ${farmPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  ────────────────');
    buf.writeln('  ANTE phase RTP      : ${anteRtp.toStringAsFixed(2)}% (Δ ${(anteRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('    Wagered           : ${anteWagered.toStringAsFixed(2)} TL  ($anteBaseSpins base spins @ 1.25×)');
    buf.writeln('    Paid out          : ${antePaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  ────────────────');
    buf.writeln('  BUY phase RTP       : ${buyRtp.toStringAsFixed(2)}% (Δ ${(buyRtp - targetRtp).toStringAsFixed(2)})');
    buf.writeln('    Wagered           : ${buyWagered.toStringAsFixed(2)} TL  ($buyCount buys @ 100×)');
    buf.writeln('    Paid out          : ${buyPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ HIT METRICS');
    buf.writeln('  Hit rate            : ${hitRate.toStringAsFixed(2)}%');
    buf.writeln('  Max single win      : ${maxSingleWin.toStringAsFixed(2)} TL '
        '(${(maxSingleWin / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('');
    buf.writeln('▼ FREE SPINS — PER PHASE');
    buf.writeln('  Farm:');
    buf.writeln('    Triggers          : $farmFsTriggers');
    buf.writeln('    Trigger rate      : ${farmTriggerRate.toStringAsFixed(3)}% per farm-base spin');
    buf.writeln('    Rounds completed  : $farmFsRounds');
    buf.writeln('    Avg round payout  : ${farmFsRoundAvg.toStringAsFixed(2)} TL '
        '(${(farmFsRoundAvg / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('  Ante:');
    buf.writeln('    Triggers          : $anteFsTriggers');
    buf.writeln('    Trigger rate      : ${anteTriggerRate.toStringAsFixed(3)}% per ante-base spin');
    buf.writeln('    Rounds completed  : $anteFsRounds');
    buf.writeln('    Avg round payout  : ${anteFsRoundAvg.toStringAsFixed(2)} TL '
        '(${(anteFsRoundAvg / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('  Buy:');
    buf.writeln('    Buys              : $buyCount');
    buf.writeln('    Rounds completed  : $buyFsRounds');
    buf.writeln('    Avg round payout  : ${buyFsRoundAvg.toStringAsFixed(2)} TL '
        '(${(buyFsRoundAvg / baseBet).toStringAsFixed(1)}x bet)');
    buf.writeln('  Total retriggers    : $retriggers');
    buf.writeln('');
    buf.writeln('▼ MODE DISTRIBUTION (across all spins)');
    modeCounts.forEach((mode, count) {
      final pct = (count / totalSpins) * 100;
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
