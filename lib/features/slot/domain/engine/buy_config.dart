/// Buy Bonus ("FS Satın Al") overrides and pricing.
/// `fsMultiplierScale` is active only when the engine receives `buyFs=true`.
/// Tuning these never touches farm or ante RTP.
class BuyConfig {
  BuyConfig._();

  /// Buy Free Spins price as a multiple of base bet.
  static const double priceMultiplier = 100.0;

  /// Scales the multiplier sum UP inside bought FS rounds. Lifts buy RTP
  /// from the natural ~91% to industry-standard ~96.5%. Visuals unchanged.
  /// Recalibrated from 1.06 → 1.12 after the multiplier-weight + FS cap
  /// rebalance lowered the cap-bound multiplier sum.
  static const double fsMultiplierScale = 1.12;
}
