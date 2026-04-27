// ─────────────────────────────────────────────────────────────────────────
// WHALE CLUSTERING STRESS TEST
// ─────────────────────────────────────────────────────────────────────────
//
// SCENARIO
//   A "whale" player at peak bet (5,000 TL) attempts to repeatedly buy
//   the FS feature (~500,000 TL per purchase). Tests how the engine's
//   pool guard, hard floor, and Virtual Cost mechanisms react under
//   sustained whale-driven cost clustering.
//
// PHASES
//   1. Warmup     : 100,000 farm base spins at peak bet to build a
//                   realistic pool buffer (no whale buys yet)
//   2. Whale loop : 50,000 buy attempts. If pool guard rejects, the
//                   whale "waits" by running 50 farm base spins (pool
//                   refill), then retries. Mirrors realistic player
//                   pattern: "play, try to buy, play more, try again".
//
// METRICS REPORTED
//   • Buys executed vs rejected (guard activation rate)
//   • Pool balance trajectory (min, max, end during whale phase)
//   • Hard-floor mode overrides triggered during whale phase
//   • Whale-perspective RTP (whale paid in / whale paid out)
//   • Mega-win clustering (count of 1000x+ rounds, max single round)
//   • Worst pool drawdown event
//
// EXPECTED HEALTHY BEHAVIOR
//   • Pool balance never goes deeply negative (guard prevents)
//   • Some buy rejections occur during whale stress (guard works)
//   • Hard floor may trigger occasionally if whale gets lucky
//   • Whale-RTP converges to ~96.5% (no exploitable edge)
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/game_mode.dart';

void main() {
  test('Whale clustering stress — sustained peak-bet buys', () {
    const warmupSpins = 100000;
    const whaleAttempts = 50000;
    const refillSpinsAfterRejection = 50;
    const peakBet = 5000.0;
    const buyCost = peakBet * SlotEngine.buyFeaturePriceMultiplier; // 500,000 TL

    final pool = PoolState();

    // ─── Counters ─────────────────────────────────────────────────
    // Warmup
    int warmupBaseSpins = 0;
    int warmupFsTriggers = 0;
    double warmupWagered = 0;
    double warmupPaidOut = 0;

    // Whale phase
    int buysExecuted = 0;
    int buysRejected = 0;
    int refillSpins = 0;
    double whaleWagered = 0; // buy fees only
    double whalePaidOut = 0; // bought-FS payouts only
    int megaWins1000x = 0;
    int megaWins5000x = 0;
    double maxBuyRoundPayout = 0;
    int maxBuyRoundIndex = -1;

    // Pool tracking during whale phase
    double whalePoolMin = double.infinity;
    double whalePoolMax = -double.infinity;
    double whalePoolStart = 0;
    int hardFloorJackpotHits = 0;
    int hardFloorRecoveryHits = 0;

    // Drawdown tracking
    double peakBeforeDrawdown = 0;
    double worstDrawdown = 0; // largest negative swing

    final whaleModeCounts = <GameMode, int>{
      for (final m in GameMode.values) m: 0,
    };

    // ─── Helper: detect hard-floor mode override ──────────────────
    // Hard floor: deficit > +10% → jackpot, < -10% → recovery
    bool isHardFloorActive(PoolState p) {
      if (p.totalBetsPlaced <= 0) return false;
      final actualRtp = p.totalPaidOut / p.totalBetsPlaced;
      final deficit = 0.965 - actualRtp;
      return deficit.abs() > 0.10;
    }

    // ─── PHASE 1: WARMUP — pure farm play to build pool ───────────
    int fsRemaining = 0;
    for (int i = 0; i < warmupSpins; i++) {
      final isFreeSpin = fsRemaining > 0;
      if (isFreeSpin) {
        fsRemaining--;
      } else {
        pool.recordBet(peakBet);
        warmupWagered += peakBet;
        warmupBaseSpins++;
      }
      final result = SlotEngine.spin(pool, peakBet, isFreeSpins: isFreeSpin);
      pool.recordPayout(result.totalWin);
      warmupPaidOut += result.totalWin;
      if (result.freeSpinsTriggered) {
        if (!result.isRetrigger) warmupFsTriggers++;
        fsRemaining += result.isRetrigger ? 5 : 10;
      }
    }
    // Drain any remaining FS from warmup
    while (fsRemaining > 0) {
      fsRemaining--;
      final result = SlotEngine.spin(pool, peakBet, isFreeSpins: true);
      pool.recordPayout(result.totalWin);
      warmupPaidOut += result.totalWin;
      if (result.freeSpinsTriggered && result.isRetrigger) {
        fsRemaining += 5;
      }
    }

    final poolAfterWarmup = pool.poolBalance;
    whalePoolStart = poolAfterWarmup;
    whalePoolMin = poolAfterWarmup;
    whalePoolMax = poolAfterWarmup;
    peakBeforeDrawdown = poolAfterWarmup;

    // ─── PHASE 2: WHALE LOOP ──────────────────────────────────────
    for (int attempt = 0; attempt < whaleAttempts; attempt++) {
      // Track mode at this moment
      final modeNow = pool.currentMode;
      whaleModeCounts[modeNow] = (whaleModeCounts[modeNow] ?? 0) + 1;
      if (isHardFloorActive(pool)) {
        if (modeNow == GameMode.jackpot) {
          hardFloorJackpotHits++;
        } else if (modeNow == GameMode.recovery) {
          hardFloorRecoveryHits++;
        }
      }

      // Try to buy
      if (!SlotEngine.canAffordBuyFs(pool, peakBet)) {
        buysRejected++;
        // Whale waits — refill pool with farm spins
        for (int r = 0; r < refillSpinsAfterRejection; r++) {
          pool.recordBet(peakBet);
          final result = SlotEngine.spin(pool, peakBet);
          pool.recordPayout(result.totalWin);
          refillSpins++;
        }
        continue;
      }

      // Execute buy
      pool.recordBet(buyCost);
      whaleWagered += buyCost;
      buysExecuted++;

      // Run 10 FS spins of the bought round
      double thisRoundPayout = 0;
      int fsLeft = 10;
      while (fsLeft > 0) {
        fsLeft--;
        final result = SlotEngine.spin(
          pool,
          peakBet,
          isFreeSpins: true,
          buyFs: true,
        );
        pool.recordPayout(result.totalWin);
        whalePaidOut += result.totalWin;
        thisRoundPayout += result.totalWin;
        if (result.freeSpinsTriggered && result.isRetrigger) {
          fsLeft += 5;
        }
      }

      // Track mega wins
      final roundXBet = thisRoundPayout / peakBet;
      if (roundXBet >= 5000) megaWins5000x++;
      if (roundXBet >= 1000) megaWins1000x++;
      if (thisRoundPayout > maxBuyRoundPayout) {
        maxBuyRoundPayout = thisRoundPayout;
        maxBuyRoundIndex = attempt;
      }

      // Update pool tracking
      final balNow = pool.poolBalance;
      if (balNow < whalePoolMin) whalePoolMin = balNow;
      if (balNow > whalePoolMax) {
        whalePoolMax = balNow;
        peakBeforeDrawdown = balNow;
      }
      final drawdown = peakBeforeDrawdown - balNow;
      if (drawdown > worstDrawdown) worstDrawdown = drawdown;
    }

    final whalePoolEnd = pool.poolBalance;
    final whaleRtp = whaleWagered > 0
        ? (whalePaidOut / whaleWagered) * 100
        : 0;
    final rejectionRate = (buysRejected / whaleAttempts) * 100;

    // ─── Output ───────────────────────────────────────────────────
    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('       WHALE CLUSTERING STRESS TEST RESULTS');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ TEST CONFIGURATION');
    buf.writeln('  Peak bet            : ${peakBet.toStringAsFixed(0)} TL');
    buf.writeln('  Buy cost            : ${buyCost.toStringAsFixed(0)} TL (100× bet)');
    buf.writeln('  Warmup spins        : $warmupSpins farm base spins');
    buf.writeln('  Whale attempts      : $whaleAttempts buy tries');
    buf.writeln('  Refill on reject    : $refillSpinsAfterRejection spins');
    buf.writeln('');
    buf.writeln('▼ PHASE 1: WARMUP (Pure Farm Play)');
    buf.writeln('  Base spins          : $warmupBaseSpins');
    buf.writeln('  FS triggers         : $warmupFsTriggers');
    buf.writeln('  Wagered             : ${warmupWagered.toStringAsFixed(2)} TL');
    buf.writeln('  Paid out            : ${warmupPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  Pool after warmup   : ${poolAfterWarmup.toStringAsFixed(2)} TL');
    buf.writeln('  Warmup RTP          : ${(warmupPaidOut / warmupWagered * 100).toStringAsFixed(2)}%');
    buf.writeln('');
    buf.writeln('▼ PHASE 2: WHALE STRESS');
    buf.writeln('  Buys executed       : $buysExecuted (${(buysExecuted / whaleAttempts * 100).toStringAsFixed(1)}% of attempts)');
    buf.writeln('  Buys REJECTED       : $buysRejected (${rejectionRate.toStringAsFixed(1)}% of attempts) ← guard activation');
    buf.writeln('  Refill spins fired  : $refillSpins');
    buf.writeln('');
    buf.writeln('▼ POOL TRAJECTORY (during whale phase)');
    buf.writeln('  Pool start          : ${whalePoolStart.toStringAsFixed(2)} TL');
    buf.writeln('  Pool min            : ${whalePoolMin.toStringAsFixed(2)} TL');
    buf.writeln('  Pool max            : ${whalePoolMax.toStringAsFixed(2)} TL');
    buf.writeln('  Pool end            : ${whalePoolEnd.toStringAsFixed(2)} TL');
    buf.writeln('  Worst drawdown      : ${worstDrawdown.toStringAsFixed(2)} TL '
        '(${(worstDrawdown / peakBet).toStringAsFixed(0)}x peak bet)');
    buf.writeln('  Pool went negative? : ${whalePoolMin < 0 ? "❌ YES" : "✅ NO"}');
    buf.writeln('');
    buf.writeln('▼ WHALE-PERSPECTIVE RTP');
    buf.writeln('  Whale wagered       : ${whaleWagered.toStringAsFixed(2)} TL (buy fees only)');
    buf.writeln('  Whale paid out      : ${whalePaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  Whale RTP           : ${whaleRtp.toStringAsFixed(2)}%');
    buf.writeln('  Whale net           : ${(whalePaidOut - whaleWagered).toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ MEGA-WIN CLUSTERING');
    buf.writeln('  Buys executed       : $buysExecuted');
    buf.writeln('  1000x+ rounds       : $megaWins1000x (${(megaWins1000x / buysExecuted * 100).toStringAsFixed(2)}%)');
    buf.writeln('  5000x+ rounds       : $megaWins5000x (${(megaWins5000x / buysExecuted * 100).toStringAsFixed(2)}%)');
    buf.writeln('  Max single round    : ${maxBuyRoundPayout.toStringAsFixed(2)} TL '
        '(${(maxBuyRoundPayout / peakBet).toStringAsFixed(0)}x bet) at attempt #$maxBuyRoundIndex');
    buf.writeln('');
    buf.writeln('▼ HARD FLOOR ACTIVATIONS (during whale phase)');
    buf.writeln('  Force-jackpot fires : $hardFloorJackpotHits attempts (deficit > +10%)');
    buf.writeln('  Force-recovery fires: $hardFloorRecoveryHits attempts (deficit < -10%)');
    buf.writeln('');
    buf.writeln('▼ MODE DISTRIBUTION DURING WHALE PHASE');
    whaleModeCounts.forEach((mode, count) {
      final pct = (count / whaleAttempts) * 100;
      final bar = '█' * (pct / 2).round();
      buf.writeln('  ${mode.name.padRight(9)} : ${count.toString().padLeft(7)} '
          '(${pct.toStringAsFixed(1).padLeft(5)}%) $bar');
    });
    buf.writeln('');
    buf.writeln('▼ HEALTH ASSESSMENT');
    buf.writeln('  ${whalePoolMin >= 0 ? "✅" : "❌"} Pool stayed non-negative');
    buf.writeln('  ${rejectionRate > 0 ? "✅" : "⚠️"} Pool guard activated (${rejectionRate.toStringAsFixed(1)}% rejection rate)');
    buf.writeln('  ${(whaleRtp - 96.5).abs() < 2.0 ? "✅" : "⚠️"} Whale RTP within ±2% of target (${whaleRtp.toStringAsFixed(2)}%)');
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');

    // ignore: avoid_print
    print(buf.toString());

    expect(pool.poolBalance, isNotNaN);
  });
}
