import '../enums/game_mode.dart';

class RtpConfig {
  RtpConfig._();

  /// Funded-profile targets calibrated to a 96.5% guarded long-run RTP.
  static const Map<GameMode, double> modeTargetRtp = {
    GameMode.recovery: 0.890,
    GameMode.tight: 0.920,
    GameMode.normal: 0.965,
    GameMode.generous: 0.980,
    GameMode.jackpot: 1.080,
  };

  static const Map<GameMode, double> hitRate = {
    GameMode.recovery: 0.3075,
    GameMode.tight: 0.2745,
    GameMode.normal: 0.2937,
    GameMode.generous: 0.240,
    GameMode.jackpot: 0.100,
  };

  static const Map<GameMode, double> fsHitRateBoost = {
    GameMode.recovery: 1.22,
    GameMode.tight: 1.22,
    GameMode.normal: 1.275,
    GameMode.generous: 1.325,
    GameMode.jackpot: 1.375,
  };

  static const Map<GameMode, double> fsTriggerRate = {
    GameMode.recovery: 0.00075,
    GameMode.tight: 0.00141,
    GameMode.normal: 0.00315,
    GameMode.generous: 0.00502,
    GameMode.jackpot: 0.01334,
  };

  static const Map<GameMode, double> fsRetriggerRate = {
    GameMode.recovery: 0.0,
    GameMode.tight: 0.01,
    GameMode.normal: 0.02,
    GameMode.generous: 0.03,
    GameMode.jackpot: 0.05,
  };

  static const Map<GameMode, double> fsAvgPayoutPerSpin = {
    GameMode.recovery: 4.0,
    GameMode.tight: 6.0,
    GameMode.normal: 10.0,
    GameMode.generous: 15.0,
    GameMode.jackpot: 22.0,
  };

  static const double fsSafetyFactor = 2.0;

  static const double buyFsSafetyFactor = 3.0;

  static const int fsAwardInitial = 10;
  static const int fsAwardRetrigger = 5;

  static const double chainProbBase = 0.0;

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
