import 'dart:math';
import '../enums/game_mode.dart';

/// Tracks the virtual money pool for RTP enforcement. Held in memory during
/// gameplay and persisted to Firestore at [saveInterval] cadence.
class PoolState {
  double totalBetsPlaced;
  double totalPaidOut;
  int totalSpins;
  int _spinsSinceLastSave;

  static const double targetRTP = 0.965;

  /// Spins between Firestore writes (limits write cost).
  static const int saveInterval = 10;

  // ── Session-mode lock ──
  // A rolled mode sticks for [_minSessionSpins] + a random extra so the
  // player experiences each mode as a "lucky" or "cold" streak instead of
  // a per-spin coin flip.
  GameMode? _sessionMode;
  int _sessionExpiresAtSpin = 0;

  static const int _minSessionSpins = 50;
  static const int _maxSessionExtraSpins = 200;

  /// Static RNG so all PoolState instances share one stream.
  static final Random _rng = Random();

  PoolState({
    this.totalBetsPlaced = 0,
    this.totalPaidOut = 0,
    this.totalSpins = 0,
    int spinsSinceLastSave = 0,
  }) : _spinsSinceLastSave = spinsSinceLastSave;

  /// Bets placed minus payouts — positive means the house is up.
  double get poolBalance => totalBetsPlaced - totalPaidOut;

  /// House's expected take at the target RTP.
  double get expectedPool => totalBetsPlaced * (1 - targetRTP);

  /// Positive = underpaying vs target, negative = overpaying.
  double get _rtpDeficit {
    if (totalBetsPlaced <= 0) return 0;
    final actualRTP = totalPaidOut / totalBetsPlaced;
    return targetRTP - actualRTP;
  }

  /// Selects the game mode for the next spin.
  ///
  /// Three layers, in priority order:
  ///   1. Warmup — first 50 spins are always normal.
  ///   2. Hard floor — deficit beyond ±10% forces jackpot/recovery as a
  ///      catastrophic-drift safety net.
  ///   3. Session injection — otherwise roll from the target distribution
  ///      and lock the result for 50–250 spins.
  GameMode get currentMode {
    if (totalSpins < 50) return GameMode.normal;
    final deficit = _rtpDeficit;

    if (deficit > 0.10) return GameMode.jackpot;
    if (deficit < -0.10) return GameMode.recovery;

    if (_sessionMode != null && totalSpins < _sessionExpiresAtSpin) {
      return _sessionMode!;
    }

    final roll = _rng.nextDouble();
    GameMode mode;
    if (roll < 0.65) {
      mode = GameMode.normal;
    } else if (roll < 0.82) {
      mode = GameMode.generous;
    } else if (roll < 0.95) {
      mode = GameMode.tight;
    } else if (roll < 0.98) {
      mode = GameMode.jackpot;
    } else {
      mode = GameMode.recovery;
    }

    _sessionMode = mode;
    _sessionExpiresAtSpin = totalSpins +
        _minSessionSpins +
        _rng.nextInt(_maxSessionExtraSpins + 1);
    return mode;
  }

  void recordBet(double amount) {
    totalBetsPlaced += amount;
    totalSpins++;
    _spinsSinceLastSave++;
  }

  void recordPayout(double amount) {
    totalPaidOut += amount;
  }

  /// True when enough spins have elapsed to warrant a Firestore save.
  bool get shouldSave => _spinsSinceLastSave >= saveInterval;

  /// Resets the save counter after a successful Firestore write.
  void markSaved() {
    _spinsSinceLastSave = 0;
  }

  Map<String, dynamic> toMap() => {
        'totalBetsPlaced': totalBetsPlaced,
        'totalPaidOut': totalPaidOut,
        'totalSpins': totalSpins,
      };

  factory PoolState.fromMap(Map<String, dynamic> map) => PoolState(
        totalBetsPlaced: (map['totalBetsPlaced'] ?? 0).toDouble(),
        totalPaidOut: (map['totalPaidOut'] ?? 0).toDouble(),
        totalSpins: (map['totalSpins'] ?? 0) as int,
      );
}
