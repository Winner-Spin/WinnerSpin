/// Ante Bet overrides applied when `anteBet=true`.
class AnteConfig {
  AnteConfig._();

  static const double fsTriggerMultiplier = 2.0;

  static const double fsSafetyFactor = 2.5;

  /// Calibrates ante Free Spin hit frequency without altering visible payouts.
  static const double freeSpinHitRateScale = 0.852;
}
