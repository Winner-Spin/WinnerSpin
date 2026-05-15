import '../enums/symbol_tier.dart';

class SlotSymbol {
  final String id;
  final String assetPath;
  final double baseWeight;
  final SymbolTier tier;

  /// Cluster-payout schedule: min-count → bet multiplier.
  final Map<int, double> payouts;

  /// Numeric value of multiplier symbols (e.g. 25 for the 25× multiplier).
  final int multiplierValue;

  /// Scatter-payout schedule, same key shape as [payouts].
  final Map<int, double> scatterPayouts;

  /// Render-time visual scale (does not affect engine math).
  final double displayScale;

  const SlotSymbol({
    required this.id,
    required this.assetPath,
    required this.baseWeight,
    required this.tier,
    this.payouts = const {},
    this.multiplierValue = 0,
    this.scatterPayouts = const {},
    this.displayScale = 1.0,
  });

  bool get isMultiplier => tier == SymbolTier.multiplier;
  bool get isScatter => tier == SymbolTier.scatter;
  bool get isRegular => !isMultiplier && !isScatter;

  /// Payout multiplier for [count] regular symbols.
  double getPayoutForCount(int count) {
    if (count < 8) return 0.0;
    final thresholds = payouts.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final threshold in thresholds) {
      if (count >= threshold) return payouts[threshold]!;
    }
    return 0.0;
  }

  /// Payout multiplier for [count] scatter symbols.
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
