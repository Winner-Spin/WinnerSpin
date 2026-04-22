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

  /// Determines the current game mode by comparing actual RTP to target.
  /// Requires at least 50 spins before deviating from normal mode,
  /// ensuring the pool has enough statistical data.
  GameMode get currentMode {
    if (totalSpins < 50) return GameMode.normal;
    final deficit = _rtpDeficit;
    if (deficit > 0.10) return GameMode.jackpot;   // underpaying by 10%+
    if (deficit > 0.05) return GameMode.generous;   // underpaying by 5-10%
    if (deficit > -0.03) return GameMode.normal;    // within ±3% of target
    if (deficit > -0.08) return GameMode.tight;     // overpaying by 3-8%
    return GameMode.recovery;                        // overpaying by 8%+
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
