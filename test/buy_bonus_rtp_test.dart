// ─────────────────────────────────────────────────────────────────────────
// BUY BONUS RTP SIMULATION
// ─────────────────────────────────────────────────────────────────────────
//
// Stress-tests the "Free Spins Satın Al" (Buy Bonus) feature in isolation.
// Every iteration: charge 100x bet, run a full 10-spin FS round (with
// retriggers), record payout. NO base-game spins.
//
// This is the cleanest measurement of the BUY-only RTP — what a player
// experiences if they exclusively buy the FS feature instead of farming.
//
// Volume: 3,000,000 buys × ~10.4 FS spins/round ≈ 31M engine calls
// (matches the 30M-spin baseline so results are directly comparable).
//
// Run with:
//   flutter test test/buy_bonus_rtp_test.dart
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/services/slot_engine.dart';
import 'package:winner_spin/models/pool_state.dart';
import 'package:winner_spin/models/slot_symbol.dart';

void main() {
  test('3,000,000 buy bonus RTP simulation (FS-only)', () {
    const totalBuys = 3000000;
    const betAmount = 100.0;
    const buyPriceMultiplier = SlotEngine.buyFeaturePriceMultiplier; // 100x

    final pool = PoolState();

    // ─── Counters ─────────────────────────────────────────────────
    int totalFsSpins = 0;
    int retriggers = 0;
    int winningFsSpins = 0;
    int zeroPayoutBuys = 0;

    double totalWagered = 0;
    double totalPaidOut = 0;
    double maxRoundPayout = 0;
    int maxRoundIndex = -1;

    // Per-round payout buckets for distribution analysis
    int below50x = 0;       // < 50x bet
    int between50_100 = 0;  // 50–100x
    int between100_200 = 0; // 100–200x
    int between200_500 = 0; // 200–500x
    int between500_1000 = 0;// 500–1000x
    int above1000 = 0;      // 1000x+ "mega buy"
    int above5000 = 0;      // 5000x+ "ultra mega"

    final modeAtBuyTime = <GameMode, int>{
      for (final m in GameMode.values) m: 0,
    };

    // ─── Main loop ────────────────────────────────────────────────
    for (int i = 0; i < totalBuys; i++) {
      // 1. Charge buy fee to pool (100x bet)
      final buyFee = betAmount * buyPriceMultiplier;
      pool.recordBet(buyFee);
      totalWagered += buyFee;
      modeAtBuyTime[pool.currentMode] =
          (modeAtBuyTime[pool.currentMode] ?? 0) + 1;

      // 2. Consume 10 FS spins (with retriggers)
      int fsRemaining = 10;
      double thisRoundPayout = 0;

      while (fsRemaining > 0) {
        fsRemaining--;
        totalFsSpins++;

        final result = SlotEngine.spin(pool, betAmount, isFreeSpins: true);
        pool.recordPayout(result.totalWin);
        totalPaidOut += result.totalWin;
        thisRoundPayout += result.totalWin;
        if (result.totalWin > 0) winningFsSpins++;

        // Retriggers extend the round
        if (result.freeSpinsTriggered && result.isRetrigger) {
          fsRemaining += 5;
          retriggers++;
        }
      }

      // 3. Track per-buy round stats
      final roundXBet = thisRoundPayout / betAmount;
      if (thisRoundPayout > maxRoundPayout) {
        maxRoundPayout = thisRoundPayout;
        maxRoundIndex = i;
      }
      if (thisRoundPayout == 0) zeroPayoutBuys++;

      if (roundXBet < 50) {
        below50x++;
      } else if (roundXBet < 100) {
        between50_100++;
      } else if (roundXBet < 200) {
        between100_200++;
      } else if (roundXBet < 500) {
        between200_500++;
      } else if (roundXBet < 1000) {
        between500_1000++;
      } else if (roundXBet < 5000) {
        above1000++;
      } else {
        above5000++;
      }
    }

    // ─── Output ───────────────────────────────────────────────────
    final actualRtp = (totalPaidOut / totalWagered) * 100;
    final avgRoundPayout = totalPaidOut / totalBuys;
    final avgRoundXBet = avgRoundPayout / betAmount;
    final avgFsSpinsPerBuy = totalFsSpins / totalBuys;
    final retriggerRatePerFs = (retriggers / totalFsSpins) * 100;
    final fsHitRate = (winningFsSpins / totalFsSpins) * 100;

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('         BUY BONUS RTP SIMULATION (FS-ONLY, 3M BUYS)');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('▼ VOLUME');
    buf.writeln('  Total buys          : $totalBuys');
    buf.writeln('  Total FS spins      : $totalFsSpins');
    buf.writeln('  Avg FS spins / buy  : ${avgFsSpinsPerBuy.toStringAsFixed(2)} (10 base + retriggers)');
    buf.writeln('  Bet per spin        : ${betAmount.toStringAsFixed(2)} TL');
    buf.writeln('  Buy price           : ${(betAmount * buyPriceMultiplier).toStringAsFixed(2)} TL (${buyPriceMultiplier.toInt()}x bet)');
    buf.writeln('');
    buf.writeln('▼ FINANCIAL');
    buf.writeln('  Total wagered (buy fees) : ${totalWagered.toStringAsFixed(2)} TL');
    buf.writeln('  Total paid out           : ${totalPaidOut.toStringAsFixed(2)} TL');
    buf.writeln('  Pool balance (end)       : ${pool.poolBalance.toStringAsFixed(2)} TL');
    buf.writeln('  House edge               : ${(totalWagered - totalPaidOut).toStringAsFixed(2)} TL');
    buf.writeln('');
    buf.writeln('▼ RTP');
    buf.writeln('  Buy bonus RTP       : ${actualRtp.toStringAsFixed(2)}%');
    buf.writeln('  SB-grade target     : 96.0–99.0%');
    buf.writeln('  Avg payout per buy  : ${avgRoundPayout.toStringAsFixed(2)} TL '
        '(${avgRoundXBet.toStringAsFixed(2)}x bet)');
    buf.writeln('  Avg net per buy     : ${(avgRoundPayout - betAmount * buyPriceMultiplier).toStringAsFixed(2)} TL '
        '(${(avgRoundXBet - buyPriceMultiplier).toStringAsFixed(2)}x bet)');
    buf.writeln('');
    buf.writeln('▼ FS BEHAVIOR');
    buf.writeln('  FS hit rate         : ${fsHitRate.toStringAsFixed(2)}%');
    buf.writeln('  Retriggers          : $retriggers');
    buf.writeln('  Retrigger rate / FS : ${retriggerRatePerFs.toStringAsFixed(3)}%');
    buf.writeln('  Zero-payout buys    : $zeroPayoutBuys '
        '(${(zeroPayoutBuys / totalBuys * 100).toStringAsFixed(2)}% of buys)');
    buf.writeln('  Max single round    : ${maxRoundPayout.toStringAsFixed(2)} TL '
        '(${(maxRoundPayout / betAmount).toStringAsFixed(1)}x bet) at buy #$maxRoundIndex');
    buf.writeln('');
    buf.writeln('▼ PER-BUY PAYOUT DISTRIBUTION (xBet)');
    buf.writeln('  < 50x         : ${below50x.toString().padLeft(8)} '
        '(${(below50x / totalBuys * 100).toStringAsFixed(2)}%)  — net loss');
    buf.writeln('  50x – 100x    : ${between50_100.toString().padLeft(8)} '
        '(${(between50_100 / totalBuys * 100).toStringAsFixed(2)}%)  — partial');
    buf.writeln('  100x – 200x   : ${between100_200.toString().padLeft(8)} '
        '(${(between100_200 / totalBuys * 100).toStringAsFixed(2)}%)  — break-even+');
    buf.writeln('  200x – 500x   : ${between200_500.toString().padLeft(8)} '
        '(${(between200_500 / totalBuys * 100).toStringAsFixed(2)}%)  — lucky');
    buf.writeln('  500x – 1000x  : ${between500_1000.toString().padLeft(8)} '
        '(${(between500_1000 / totalBuys * 100).toStringAsFixed(2)}%)  — big buy');
    buf.writeln('  1000x – 5000x : ${above1000.toString().padLeft(8)} '
        '(${(above1000 / totalBuys * 100).toStringAsFixed(2)}%)  — mega buy');
    buf.writeln('  5000x+        : ${above5000.toString().padLeft(8)} '
        '(${(above5000 / totalBuys * 100).toStringAsFixed(2)}%)  — ultra mega');
    buf.writeln('');
    buf.writeln('▼ MODE AT BUY TIME (which mode the pool was in when buy executed)');
    modeAtBuyTime.forEach((mode, count) {
      final pct = (count / totalBuys) * 100;
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
