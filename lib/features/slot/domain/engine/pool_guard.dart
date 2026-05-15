import 'dart:math';

import '../enums/game_mode.dart';
import '../models/pool_state.dart';
import 'ante_config.dart';
import 'buy_config.dart';
import 'rtp_config.dart';

class PoolGuard {
  PoolGuard._();

  static double expectedFsCostMultiplier(GameMode mode, bool isRetrigger) {
    final perSpin = RtpConfig.fsAvgPayoutPerSpin[mode] ?? 10.0;
    final fsCount = isRetrigger
        ? RtpConfig.fsAwardRetrigger
        : RtpConfig.fsAwardInitial;
    const scatterReward = 3.0;
    return scatterReward + (perSpin * fsCount);
  }

  /// Checks pool can cover an FS round. Bypassed during warmup.
  static bool canAffordFsRound(
    PoolState pool,
    double betAmount,
    GameMode mode,
    bool isRetrigger, {
    bool isAnte = false,
  }) {
    if (pool.totalSpins < 50) return true;
    final safetyFactor = isAnte
        ? AnteConfig.fsSafetyFactor
        : RtpConfig.fsSafetyFactor;
    final virtualCost =
        expectedFsCostMultiplier(mode, isRetrigger) * betAmount * safetyFactor;
    return pool.poolBalance >= virtualCost;
  }

  /// Buy-FS variant — checks POST-fee headroom.
  static bool canAffordBuyFs(PoolState pool, double betAmount) {
    if (pool.totalSpins < 50) return true;
    final mode = pool.currentMode;
    final expectedCost = expectedFsCostMultiplier(mode, false) * betAmount;
    final buyFee = betAmount * BuyConfig.priceMultiplier;
    final virtualCost = expectedCost * RtpConfig.buyFsSafetyFactor;
    return (pool.poolBalance + buyFee) >= virtualCost;
  }

  /// Per-mode max win cap with pool-balance floor.
  static double getMaxWinMultiplier(
    GameMode mode,
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
  }) {
    double modeCeiling;
    if (isFreeSpins) {
      switch (mode) {
        case GameMode.recovery:
          modeCeiling = 60.0;
          break;
        case GameMode.tight:
          modeCeiling = 400.0;
          break;
        case GameMode.normal:
          modeCeiling = 8000.0;
          break;
        case GameMode.generous:
          modeCeiling = 15000.0;
          break;
        case GameMode.jackpot:
          modeCeiling = 21100.0;
          break;
      }
    } else {
      switch (mode) {
        case GameMode.recovery:
          modeCeiling = 30.0;
          break;
        case GameMode.tight:
          modeCeiling = 100.0;
          break;
        case GameMode.normal:
          modeCeiling = 2500.0;
          break;
        case GameMode.generous:
          modeCeiling = 5000.0;
          break;
        case GameMode.jackpot:
          modeCeiling = 10000.0;
          break;
      }
    }

    if (pool.totalSpins < 50) return modeCeiling;

    final safePoolMultiplier = (pool.poolBalance * 0.5) / betAmount;

    double absoluteMinimum;
    if (pool.poolBalance <= 0) {
      absoluteMinimum = 1.0;
    } else if (pool.poolBalance < betAmount * 10) {
      absoluteMinimum = 2.0;
    } else {
      absoluteMinimum = 5.0;
    }

    return max(absoluteMinimum, min(modeCeiling, safePoolMultiplier));
  }
}
