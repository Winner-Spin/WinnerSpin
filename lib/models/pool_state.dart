import 'dart:math';
import 'slot_symbol.dart';

/// Tracks the virtual money pool for RTP enforcement.
/// Kept in memory during gameplay; persisted to Firestore periodically.
class PoolState {
  double totalBetsPlaced;
  double totalPaidOut;
  int totalSpins;
  int _spinsSinceLastSave;

  static const double targetRTP = 0.965;

  /// Save to Firestore every N spins to minimize write costs.
  static const int saveInterval = 10;

  // ─── SESSION MODE STATE ───────────────────────────────────────
  // Once a mode is selected, it sticks for [_minSessionSpins] +
  // random extra spins. This emulates the natural "lucky session" /
  // "cold session" variance of pure-RNG cascade slots — without
  // dropping our compensatory floor for catastrophic drift.
  GameMode? _sessionMode;
  int _sessionExpiresAtSpin = 0;

  /// Minimum number of spins a chosen mode is held before re-rolling.
  static const int _minSessionSpins = 50;

  /// Maximum random extra spins added on top of [_minSessionSpins].
  /// Total session length: 50–250 spins (typical short slot session).
  static const int _maxSessionExtraSpins = 200;

  /// RNG used for session mode injection rolls.
  /// Static so all PoolState instances share the same stream
  /// (no need to seed per-instance).
  static final Random _rng = Random();

  PoolState({
    this.totalBetsPlaced = 0,
    this.totalPaidOut = 0,
    this.totalSpins = 0,
    int spinsSinceLastSave = 0,
  }) : _spinsSinceLastSave = spinsSinceLastSave;

  // ─── CALCULATED PROPERTIES ────────────────────────────────────

  /// Money sitting in the pool (total bets minus total payouts).
  double get poolBalance => totalBetsPlaced - totalPaidOut;

  /// How much the house is *expected* to hold at this point.
  double get expectedPool => totalBetsPlaced * (1 - targetRTP);

  /// How much we've actually paid back vs how much we should have.
  /// Positive deficit = underpaying, Negative deficit = overpaying.
  double get _rtpDeficit {
    if (totalBetsPlaced <= 0) return 0;
    final actualRTP = totalPaidOut / totalBetsPlaced;
    return targetRTP - actualRTP;
  }

  // ─── GAME MODE ────────────────────────────────────────────────

  /// Determines the current game mode using random session injection
  /// (Sweet Bonanza-style session variance).
  ///
  /// Architecture (v6d, post per-mode RTP balancing):
  ///   • Each mode is calibrated to ~96.5% RTP individually, so mixing
  ///     them freely doesn't drift total RTP.
  ///   • Random session selection picks a mode from a target
  ///     distribution (normal 65%, generous 17%, tight 13%,
  ///     jackpot 3%, recovery 2%).
  ///   • Once selected, mode is LOCKED for 50-250 spins — the typical
  ///     length of a play session. Player experiences each mode as a
  ///     "lucky" or "cold" streak.
  ///   • Hard floor (deficit > ±3%) overrides session lock as a
  ///     catastrophic safety net for calibration drift / whale events.
  GameMode get currentMode {
    if (totalSpins < 50) return GameMode.normal; // warmup
    final deficit = _rtpDeficit;

    // ── HARD FLOOR — only catastrophic drift overrides ─────────
    // Widened to ±10% so routine pool wobble (±2-3%) doesn't override
    // session distribution. Only true catastrophic drift triggers.
    if (deficit > 0.10) return GameMode.jackpot;    // underpaying by 10%+
    if (deficit < -0.10) return GameMode.recovery;  // overpaying by 10%+

    // ── SESSION LOCK — return locked mode if still valid ───────
    if (_sessionMode != null && totalSpins < _sessionExpiresAtSpin) {
      return _sessionMode!;
    }

    // ── ROLL NEW SESSION MODE ──────────────────────────────────
    // Target distribution (verified via per-mode RTP measurement):
    //   normal 65% (96.91% RTP)
    //   generous 17% (99.99%)
    //   tight 13% (89.75%)
    //   jackpot 3% (99.99%)
    //   recovery 2% (92.86%)
    //   Weighted RTP ≈ 96.52% — matches 96.5% target.
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

    // Lock for typical session length (50-250 spins).
    _sessionMode = mode;
    _sessionExpiresAtSpin = totalSpins +
        _minSessionSpins +
        _rng.nextInt(_maxSessionExtraSpins + 1);
    return mode;
  }

  // ─── MUTATION ─────────────────────────────────────────────────

  void recordBet(double amount) {
    totalBetsPlaced += amount;
    totalSpins++;
    _spinsSinceLastSave++;
  }

  void recordPayout(double amount) {
    totalPaidOut += amount;
  }

  /// Whether enough spins have elapsed to warrant a Firestore save.
  bool get shouldSave => _spinsSinceLastSave >= saveInterval;

  /// Reset the save counter after a successful Firestore write.
  void markSaved() {
    _spinsSinceLastSave = 0;
  }

  // ─── SERIALIZATION ────────────────────────────────────────────

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
