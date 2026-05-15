/// Ante Bet overrides applied when `anteBet=true`.
class AnteConfig {
  AnteConfig._();

  static const double fsTriggerMultiplier = 2.0;

  static const double fsSafetyFactor = 2.5;

  /// Scales multiplier sum down in ante-triggered FS to keep RTP stable.
  static const double fsMultiplierScale = 0.80;
}
