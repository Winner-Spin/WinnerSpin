import '../enums/game_mode.dart';

/// Buy Bonus overrides applied when `buyFs=true`.
class BuyConfig {
  BuyConfig._();

  static const double priceMultiplier = 100.0;

  /// Normalizes bought Free Spin value without altering visible payouts.
  static const Map<GameMode, double> _freeSpinHitRateScale = {
    GameMode.recovery: 2.13,
    GameMode.tight: 0.90,
    GameMode.normal: 0.93,
    GameMode.generous: 1.09,
    GameMode.jackpot: 1.96,
  };

  static double freeSpinHitRateScaleFor(GameMode mode) =>
      _freeSpinHitRateScale[mode] ?? 1.0;
}
