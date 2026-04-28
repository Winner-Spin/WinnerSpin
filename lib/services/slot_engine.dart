import '../models/pool_state.dart';
import '../models/spin_result.dart';
import 'engine/ante_config.dart';
import 'engine/buy_config.dart';
import 'engine/engine_runtime.dart';
import 'engine/grid_generator.dart';
import 'engine/pool_guard.dart';
import 'engine/rtp_config.dart';
import 'engine/tumble_simulator.dart';
import 'engine/weighted_random.dart';

/// Public, stateless slot engine. Orchestrates the per-spin decision flow
/// (FS trigger, win/lose, rejection sampling) by delegating to dedicated
/// sub-modules under `engine/`.
class SlotEngine {
  SlotEngine._();

  /// Re-exported board dimensions for callers outside the engine package.
  static const int columns = kEngineColumns;
  static const int rows = kEngineRows;

  /// Re-exported buy price for backward-compat with the ViewModel.
  static const double buyFeaturePriceMultiplier = BuyConfig.priceMultiplier;

  /// Buy-FS pool affordability check. Wraps [PoolGuard.canAffordBuyFs] so
  /// callers don't have to import the engine package directly.
  static bool canAffordBuyFs(PoolState pool, double betAmount) =>
      PoolGuard.canAffordBuyFs(pool, betAmount);

  /// Single-spin orchestrator.
  ///
  /// Flow:
  ///   1. Build weighted symbol pool + roll multiplier cap.
  ///   2. Decide if FS triggers (gated by Virtual Cost guard).
  ///   3. Decide win/lose (FS rounds use boosted hit rate).
  ///   4. Generate winning or safe grid; run cascade tumbles.
  ///   5. Reject samples that exceed the per-mode max-win cap and retry.
  static SpinResult spin(
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
    bool anteBet = false,
    bool buyFs = false,
  }) {
    final mode = pool.currentMode;
    final weights = WeightedRandom.buildAdjustedWeights(mode, isFreeSpins);
    final spinMaxMults = GridGenerator.rollMaxMultipliers(isFreeSpins: isFreeSpins);

    // betAmount=0 happens during initial UI grid generation at app startup.
    // Returning a zero-win result short-circuits the win loop's infinite spin.
    if (betAmount <= 0) {
      return SpinResult(
        initialGrid: GridGenerator.generateSafe(weights, spinMaxMults, isFreeSpins: isFreeSpins),
        tumbles: const [],
        totalWin: 0,
        tumbleCount: 0,
        freeSpinsTriggered: false,
        scatterCount: 0,
        scatterPayout: 0,
      );
    }

    final maxAllowedWin =
        PoolGuard.getMaxWinMultiplier(mode, pool, betAmount, isFreeSpins: isFreeSpins) * betAmount;

    // FS trigger decision — base or retrigger rate, optionally bumped by
    // ante on base spins. Both paths gated by the Virtual Cost guard.
    final bool isRetriggerAttempt = isFreeSpins;
    final double baseFsRate = isRetriggerAttempt
        ? (RtpConfig.fsRetriggerRate[mode] ?? 0.0)
        : (RtpConfig.fsTriggerRate[mode] ?? 0.0);
    final double fsRate = (anteBet && !isRetriggerAttempt)
        ? baseFsRate * AnteConfig.fsTriggerMultiplier
        : baseFsRate;
    final bool canAffordFs = PoolGuard.canAffordFsRound(
          pool, betAmount, mode, isRetriggerAttempt,
          isAnte: anteBet && !isRetriggerAttempt,
        ) &&
        maxAllowedWin >= (3.25 * betAmount);
    final bool triggersFs = canAffordFs && (engineRng.nextDouble() < fsRate);

    // FS rounds boost hit rate so the round feels lucky.
    final double effectiveHitRate = isFreeSpins
        ? _min(0.95, (RtpConfig.hitRate[mode] ?? 0.30) * (RtpConfig.fsHitRateBoost[mode] ?? 1.25))
        : (RtpConfig.hitRate[mode] ?? 0.30);
    final shouldWin = triggersFs || engineRng.nextDouble() < effectiveHitRate;

    if (!shouldWin) {
      final grid = GridGenerator.generateSafe(weights, spinMaxMults, isFreeSpins: isFreeSpins);
      return TumbleSimulator.run(grid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
    }

    // Rejection sampling: try natural cascades up to 50 times; reject any
    // that exceed the budget and keep retrying.
    for (int attempt = 0; attempt < 50; attempt++) {
      final initialGrid = GridGenerator.generateWinning(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      final simResult = TumbleSimulator.run(initialGrid, weights, betAmount,
          safeRefill: false, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
    }

    // Fallback: safe-refill (single-cascade only) keeps the win bounded.
    int fallbackAttempts = 0;
    while (fallbackAttempts++ < 100) {
      final fallbackGrid = GridGenerator.generateWinning(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      final simResult = TumbleSimulator.run(fallbackGrid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
    }

    // Hard fail-safe: if even the bounded fallback can't fit, return a safe grid.
    return TumbleSimulator.run(
      GridGenerator.generateSafe(weights, spinMaxMults, isFreeSpins: isFreeSpins),
      weights,
      betAmount,
      safeRefill: true,
      maxMults: spinMaxMults,
      isFreeSpins: isFreeSpins,
    );
  }
}

double _min(double a, double b) => a < b ? a : b;
