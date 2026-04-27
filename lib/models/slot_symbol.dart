/// Tier classification for dynamic weight adjustment.
enum SymbolTier { low, mid, high, scatter, multiplier }

/// Game mode determined by pool state.
enum GameMode { recovery, tight, normal, generous, jackpot }

/// Represents a single slot symbol with its properties.
class SlotSymbol {
  final String id;
  final String assetPath;
  final double baseWeight;
  final SymbolTier tier;

  /// Payout multipliers: {minCount: payoutMultiplier}.
  /// e.g., {8: 0.25, 10: 0.75, 12: 2.0} means 8-9 symbols pay 0.25x bet.
  final Map<int, double> payouts;

  /// For multiplier symbols only.
  final int multiplierValue;

  /// For scatter symbols: {minCount: payoutMultiplier}.
  final Map<int, double> scatterPayouts;

  const SlotSymbol({
    required this.id,
    required this.assetPath,
    required this.baseWeight,
    required this.tier,
    this.payouts = const {},
    this.multiplierValue = 0,
    this.scatterPayouts = const {},
  });

  bool get isMultiplier => tier == SymbolTier.multiplier;
  bool get isScatter => tier == SymbolTier.scatter;
  bool get isRegular => !isMultiplier && !isScatter;

  /// Returns the payout multiplier for the given symbol count.
  /// Checks thresholds in descending order (12+, 10+, 8+).
  double getPayoutForCount(int count) {
    if (count < 8) return 0.0;
    final thresholds = payouts.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in thresholds) {
      if (count >= threshold) return payouts[threshold]!;
    }
    return 0.0;
  }

  /// Returns the scatter payout multiplier for the given count.
  double getScatterPayoutForCount(int count) {
    if (scatterPayouts.isEmpty) return 0.0;
    final thresholds = scatterPayouts.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final threshold in thresholds) {
      if (count >= threshold) return scatterPayouts[threshold]!;
    }
    return 0.0;
  }
}

/// Central symbol registry — single source of truth.
class SymbolRegistry {
  SymbolRegistry._();

  static const List<SlotSymbol> all = [
    // ── LOW TIER ────────────────────────────────────────────────
    SlotSymbol(
      id: 'muz',
      assetPath: 'lib/images/slot_main_screen/Items/muz.png',
      baseWeight: 35,
      tier: SymbolTier.low,
      payouts: {8: 0.25, 10: 0.75, 12: 2.0},
    ),
    SlotSymbol(
      id: 'uzum',
      assetPath: 'lib/images/slot_main_screen/Items/uzum.png',
      baseWeight: 30,
      tier: SymbolTier.low,
      payouts: {8: 0.40, 10: 0.90, 12: 4.0},
    ),
    SlotSymbol(
      id: 'karpuz',
      assetPath: 'lib/images/slot_main_screen/Items/karpuz.png',
      baseWeight: 28,
      tier: SymbolTier.low,
      payouts: {8: 0.50, 10: 1.00, 12: 5.0},
    ),

    // ── MID TIER ────────────────────────────────────────────────
    SlotSymbol(
      id: 'seftali',
      assetPath: 'lib/images/slot_main_screen/Items/seftali.png',
      baseWeight: 22,
      tier: SymbolTier.mid,
      payouts: {8: 0.80, 10: 1.20, 12: 8.0},
    ),
    SlotSymbol(
      id: 'elma',
      assetPath: 'lib/images/slot_main_screen/Items/Apple.png',
      baseWeight: 18,
      tier: SymbolTier.mid,
      payouts: {8: 1.00, 10: 1.50, 12: 10.0},
    ),

    // ── HIGH TIER ───────────────────────────────────────────────
    SlotSymbol(
      id: 'cilek',
      assetPath: 'lib/images/slot_main_screen/Items/cilek.png',
      baseWeight: 14,
      tier: SymbolTier.high,
      payouts: {8: 1.50, 10: 2.00, 12: 12.0},
    ),
    SlotSymbol(
      id: 'pembe_ayi',
      assetPath: 'lib/images/slot_main_screen/Items/pembe_ayi.png',
      baseWeight: 10,
      tier: SymbolTier.high,
      payouts: {8: 2.00, 10: 5.00, 12: 15.0},
    ),
    SlotSymbol(
      id: 'yesil_ayi',
      assetPath: 'lib/images/slot_main_screen/Items/yesil_ayi.png',
      baseWeight: 7,
      tier: SymbolTier.high,
      payouts: {8: 5.00, 10: 10.00, 12: 25.0},
    ),
    SlotSymbol(
      id: 'kalp',
      assetPath: 'lib/images/slot_main_screen/Items/Kalp.png',
      baseWeight: 4,
      tier: SymbolTier.high,
      payouts: {8: 10.00, 10: 25.00, 12: 50.0},
    ),

    // ── SCATTER ─────────────────────────────────────────────────
    SlotSymbol(
      id: 'cupcake',
      assetPath: 'lib/images/slot_main_screen/Items/cupCake.png',
      baseWeight: 8,
      tier: SymbolTier.scatter,
      scatterPayouts: {4: 3.0, 5: 5.0, 6: 100.0},
    ),

    // ── MULTIPLIERS (Base game: extremely rare) ─────────────
    SlotSymbol(
      id: 'multi_2x',
      assetPath: 'lib/images/slot_main_screen/Items/2x_carpan.png',
      baseWeight: 0.5,
      tier: SymbolTier.multiplier,
      multiplierValue: 2,
    ),
    SlotSymbol(
      id: 'multi_3x',
      assetPath: 'lib/images/slot_main_screen/Items/3x_carpan.png',
      baseWeight: 0.25,
      tier: SymbolTier.multiplier,
      multiplierValue: 3,
    ),
    SlotSymbol(
      id: 'multi_5x',
      assetPath: 'lib/images/slot_main_screen/Items/5x_carpan.png',
      baseWeight: 0.1,
      tier: SymbolTier.multiplier,
      multiplierValue: 5,
    ),
    SlotSymbol(
      id: 'multi_10x',
      assetPath: 'lib/images/slot_main_screen/Items/10x_carpan.png',
      baseWeight: 0.05,   // restored to v5 original
      tier: SymbolTier.multiplier,
      multiplierValue: 10,
    ),
    SlotSymbol(
      id: 'multi_25x',
      assetPath: 'lib/images/slot_main_screen/Items/25x_carpan.png',
      baseWeight: 0.02,   // restored to v5 original
      tier: SymbolTier.multiplier,
      multiplierValue: 25,
    ),
    SlotSymbol(
      id: 'multi_50x',
      assetPath: 'lib/images/slot_main_screen/Items/50x_carpan.png',
      baseWeight: 0.01,   // restored to v5 original
      tier: SymbolTier.multiplier,
      multiplierValue: 50,
    ),
    SlotSymbol(
      id: 'multi_100x',
      assetPath: 'lib/images/slot_main_screen/Items/100x_carpan.png',
      baseWeight: 0.002,  // restored to v5 original
      tier: SymbolTier.multiplier,
      multiplierValue: 100,
    ),
  ];

  /// Fast lookup by asset path.
  static final Map<String, SlotSymbol> _byPath = {
    for (final s in all) s.assetPath: s,
  };

  static SlotSymbol? byPath(String path) => _byPath[path];

  /// Dynamic weight multipliers per game mode and symbol tier.
  static const Map<GameMode, Map<SymbolTier, double>> weightMultipliers = {
    GameMode.recovery: {
      SymbolTier.low: 1.4,
      SymbolTier.mid: 1.1,
      SymbolTier.high: 0.5,
      SymbolTier.scatter: 0.6,
      SymbolTier.multiplier: 0.2,
    },
    GameMode.tight: {
      // v2 tightening: tight is now a real brake, not just "slightly less normal".
      // mid 1.05 -> 0.95, high 0.7 -> 0.5, multiplier 0.5 -> 0.4
      SymbolTier.low: 1.2,
      SymbolTier.mid: 0.95,
      SymbolTier.high: 0.5,
      SymbolTier.scatter: 0.8,
      SymbolTier.multiplier: 0.4,
    },
    GameMode.normal: {
      SymbolTier.low: 1.0,
      SymbolTier.mid: 1.0,
      SymbolTier.high: 1.0,
      SymbolTier.scatter: 1.0,
      SymbolTier.multiplier: 1.0,
    },
    GameMode.generous: {
      SymbolTier.low: 0.85,
      SymbolTier.mid: 1.1,
      SymbolTier.high: 1.3,
      SymbolTier.scatter: 1.2,
      SymbolTier.multiplier: 1.5,
    },
    GameMode.jackpot: {
      SymbolTier.low: 0.7,
      SymbolTier.mid: 1.2,
      SymbolTier.high: 1.8,
      SymbolTier.scatter: 1.5,
      SymbolTier.multiplier: 2.5,
    },
  };
}
