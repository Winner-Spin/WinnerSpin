/// Ante Bet ("Çifte Şans") overrides applied on top of base RTP math.
/// Active only when the engine receives `anteBet=true`. Tuning these never
/// touches farm-mode RTP.
class AnteConfig {
  AnteConfig._();

  /// Ante doubles the FS trigger rate (matches the "2× FS chance" UI claim).
  static const double fsTriggerMultiplier = 2.0;

  /// Ante's pool-cover headroom — between natural (2.0) and buy (3.0).
  static const double fsSafetyFactor = 2.5;

  /// Scales the multiplier sum DOWN inside ante-triggered FS rounds so the
  /// 2× trigger rate doesn't inflate ante RTP above 96.5%. Visuals unchanged.
  static const double fsMultiplierScale = 0.80;
}
