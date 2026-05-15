import '../models/pool_state.dart';
import '../models/spin_result.dart';
import 'ante_config.dart';
import 'buy_config.dart';
import 'engine_runtime.dart';
import 'grid_generator.dart';
import 'pool_guard.dart';
import 'rtp_config.dart';
import 'tumble_simulator.dart';
import 'weighted_random.dart';

class SlotEngine {
  SlotEngine._();

  static const int columns = kEngineColumns;
  static const int rows = kEngineRows;

  static const double buyFeaturePriceMultiplier = BuyConfig.priceMultiplier;

  static bool canAffordBuyFs(PoolState pool, double betAmount) =>
      PoolGuard.canAffordBuyFs(pool, betAmount);

  static SpinResult spin(
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
    bool anteBet = false,
    bool buyFs = false,
    bool forceFsTrigger = false,
  }) {
    final mode = pool.currentMode;
    final weights = WeightedRandom.buildAdjustedWeights(mode, isFreeSpins);
    final spinMaxMults = GridGenerator.rollMaxMultipliers(
      isFreeSpins: isFreeSpins,
    );

    if (betAmount <= 0) {
      return SpinResult(
        initialGrid: GridGenerator.generateSafe(
          weights,
          spinMaxMults,
          isFreeSpins: isFreeSpins,
        ),
        tumbles: const [],
        totalWin: 0,
        tumbleCount: 0,
        freeSpinsTriggered: false,
        scatterCount: 0,
        scatterPayout: 0,
      );
    }

    final maxAllowedWin =
        PoolGuard.getMaxWinMultiplier(
          mode,
          pool,
          betAmount,
          isFreeSpins: isFreeSpins,
        ) *
        betAmount;

    final bool isRetriggerAttempt = isFreeSpins;
    final double baseFsRate = isRetriggerAttempt
        ? (RtpConfig.fsRetriggerRate[mode] ?? 0.0)
        : (RtpConfig.fsTriggerRate[mode] ?? 0.0);
    final double fsRate = (anteBet && !isRetriggerAttempt)
        ? baseFsRate * AnteConfig.fsTriggerMultiplier
        : baseFsRate;
    final bool canAffordFs =
        PoolGuard.canAffordFsRound(
          pool,
          betAmount,
          mode,
          isRetriggerAttempt,
          isAnte: anteBet && !isRetriggerAttempt,
        ) &&
        maxAllowedWin >= (3.25 * betAmount);
    final bool triggersFs =
        forceFsTrigger || (canAffordFs && (engineRng.nextDouble() < fsRate));

    final double effectiveHitRate = isFreeSpins
        ? _min(
            0.95,
            (RtpConfig.hitRate[mode] ?? 0.30) *
                (RtpConfig.fsHitRateBoost[mode] ?? 1.25),
          )
        : (RtpConfig.hitRate[mode] ?? 0.30);
    final shouldWin = triggersFs || engineRng.nextDouble() < effectiveHitRate;

    if (!shouldWin) {
      final grid = GridGenerator.generateSafe(
        weights,
        spinMaxMults,
        isFreeSpins: isFreeSpins,
      );
      return TumbleSimulator.run(
        grid,
        weights,
        betAmount,
        safeRefill: true,
        maxMults: spinMaxMults,
        isFreeSpins: isFreeSpins,
        anteBet: anteBet,
        buyFs: buyFs,
      );
    }

    SpinResult? lastForcedFallback;
    for (int attempt = 0; attempt < 50; attempt++) {
      final initialGrid = GridGenerator.generateWinning(
        weights,
        mode,
        spinMaxMults,
        forceScatters: triggersFs,
        isFreeSpins: isFreeSpins,
      );
      final simResult = TumbleSimulator.run(
        initialGrid,
        weights,
        betAmount,
        safeRefill: false,
        maxMults: spinMaxMults,
        isFreeSpins: isFreeSpins,
        anteBet: anteBet,
        buyFs: buyFs,
      );
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
      if (forceFsTrigger && simResult.freeSpinsTriggered) {
        lastForcedFallback = simResult;
      }
    }

    int fallbackAttempts = 0;
    while (fallbackAttempts++ < 100) {
      final fallbackGrid = GridGenerator.generateWinning(
        weights,
        mode,
        spinMaxMults,
        forceScatters: triggersFs,
        isFreeSpins: isFreeSpins,
      );
      final simResult = TumbleSimulator.run(
        fallbackGrid,
        weights,
        betAmount,
        safeRefill: true,
        maxMults: spinMaxMults,
        isFreeSpins: isFreeSpins,
        anteBet: anteBet,
        buyFs: buyFs,
      );
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
      if (forceFsTrigger && simResult.freeSpinsTriggered) {
        lastForcedFallback = simResult;
      }
    }

    // Buy Feature must return a scatter result once paid.
    if (forceFsTrigger && lastForcedFallback != null) {
      return lastForcedFallback;
    }

    return TumbleSimulator.run(
      GridGenerator.generateSafe(
        weights,
        spinMaxMults,
        isFreeSpins: isFreeSpins,
      ),
      weights,
      betAmount,
      safeRefill: true,
      maxMults: spinMaxMults,
      isFreeSpins: isFreeSpins,
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
