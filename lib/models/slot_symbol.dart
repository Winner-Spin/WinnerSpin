import 'symbol_tier.dart';

/// A single slot symbol — its asset, weight, and payout schedule.
class SlotSymbol {
  final String id;
  final String assetPath;
  final double baseWeight;
  final SymbolTier tier;

  /// Cluster-payout schedule keyed by minimum count.
  /// {8: 0.25, 10: 0.75, 12: 2.0} → 8–9 symbols pay 0.25× bet, 10–11 pay 0.75×, 12+ pay 2×.
  final Map<int, double> payouts;

  /// Numeric value of multiplier symbols (e.g. 25 for the 25× multiplier).
  final int multiplierValue;

  /// Scatter-payout schedule, same key shape as [payouts].
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

  /// Resolves the payout multiplier for [count] regulars.
  /// Walks thresholds in descending order so the highest tier matches first.
  double getPayoutForCount(int count) {
    if (count < 8) return 0.0;
    final thresholds = payouts.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in thresholds) {
      if (count >= threshold) return payouts[threshold]!;
    }
    return 0.0;
  }

  /// Resolves the scatter payout multiplier for [count] scatters.
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
