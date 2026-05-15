/// Buy Bonus overrides applied when `buyFs=true`.
class BuyConfig {
  BuyConfig._();

  static const double priceMultiplier = 100.0;

  /// Scales multiplier sum up in bought FS to reach ~96.5% RTP.
  static const double fsMultiplierScale = 1.12;
}
