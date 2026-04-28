import '../enums/game_mode.dart';

/// Numeric calibration constants that drive the slot engine's RTP behavior.
/// Treat these as load-bearing — they're calibrated to ~96.5% across all
/// engine modes (farm / ante / buy / mixed) and verified by the RTP test
/// suite. Don't change a value without re-running the suite.
class RtpConfig {
  RtpConfig._();

  /// Probability of a winning spin per game mode.
  static const Map<GameMode, double> hitRate = {
    GameMode.recovery: 0.310,
    GameMode.tight: 0.260,
    GameMode.normal: 0.260,
    GameMode.generous: 0.240,
    GameMode.jackpot: 0.260,
  };

  /// Multiplier applied to [hitRate] inside a Free Spins round.
  /// Higher modes get larger boosts so jackpot/generous FS feel premium.
  static const Map<GameMode, double> fsHitRateBoost = {
    GameMode.recovery: 1.22,
    GameMode.tight: 1.22,
    GameMode.normal: 1.275,
    GameMode.generous: 1.325,
    GameMode.jackpot: 1.375,
  };

  /// Probability of naturally triggering Free Spins per base spin.
  /// Bumped by ante override at the spin call site.
  static const Map<GameMode, double> fsTriggerRate = {
    GameMode.recovery: 0.00075,
    GameMode.tight: 0.00141,
    GameMode.normal: 0.00315,
    GameMode.generous: 0.00517,
    GameMode.jackpot: 0.0235,
  };

  /// Probability of re-triggering Free Spins from inside a FS round.
  static const Map<GameMode, double> fsRetriggerRate = {
    GameMode.recovery: 0.0,
    GameMode.tight: 0.01,
    GameMode.normal: 0.02,
    GameMode.generous: 0.03,
    GameMode.jackpot: 0.05,
  };

  /// Estimated avg per-FS-spin payout (xBet). Drives the Virtual Cost guard.
  /// Errs conservative — overestimates real cost to keep the pool safe.
  static const Map<GameMode, double> fsAvgPayoutPerSpin = {
    GameMode.recovery: 4.0,
    GameMode.tight: 6.0,
    GameMode.normal: 10.0,
    GameMode.generous: 15.0,
    GameMode.jackpot: 22.0,
  };

  /// Pool-cover headroom for naturally-triggered FS rounds.
  static const double fsSafetyFactor = 2.0;

  /// Stricter pool-cover headroom for player-initiated buys (whale clustering).
  static const double buyFsSafetyFactor = 3.0;

  /// Spins awarded per FS event.
  static const int fsAwardInitial = 10;
  static const int fsAwardRetrigger = 5;

  /// Base-game forced-chain probability. Zero — natural cascade rate already
  /// matches industry tumble-depth targets without seeding.
  static const double chainProbBase = 0.0;

  /// Weights for picking which symbol wins on a winning spin.
  static const Map<String, double> winSymbolWeights = {
    'muz': 35,
    'uzum': 25,
    'karpuz': 18,
    'seftali': 10,
    'elma': 6,
    'cilek': 3,
    'pembe_ayi': 1.5,
    'yesil_ayi': 0.8,
    'kalp': 0.3,
  };
}
