/// Ante Bet overrides applied on top of base RTP math.
/// Active only when the engine receives `anteBet=true`.
class AnteConfig {
  AnteConfig._();

  /// Ante doubles the FS trigger rate.
  static const double fsTriggerMultiplier = 2.0;

  /// Ante's pool-cover headroom, between natural (2.0) and buy (3.0).
  static const double fsSafetyFactor = 2.5;
}
