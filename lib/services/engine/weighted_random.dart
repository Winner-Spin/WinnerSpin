import '../../models/game_mode.dart';
import '../../models/symbol_registry.dart';
import 'engine_runtime.dart';

/// Asset-path + weight tuple used by the weighted-pick helper.
class WeightedSymbol {
  final String assetPath;
  final double weight;
  const WeightedSymbol(this.assetPath, this.weight);
}

/// Weighted-random helpers for symbol selection.
class WeightedRandom {
  WeightedRandom._();

  /// Builds the per-spin weighted symbol pool. Inside FS, multiplier weights
  /// are amplified by the per-mode boost so the round delivers its premium feel.
  static List<WeightedSymbol> buildAdjustedWeights(GameMode mode, bool isFreeSpins) {
    final multipliers = SymbolRegistry.weightMultipliers[mode]!;

    double fsMultiplierBoost = 1.0;
    if (isFreeSpins) {
      switch (mode) {
        case GameMode.recovery: fsMultiplierBoost = 22.0; break;
        case GameMode.tight: fsMultiplierBoost = 36.0; break;
        case GameMode.normal: fsMultiplierBoost = 55.0; break;
        case GameMode.generous: fsMultiplierBoost = 80.0; break;
        case GameMode.jackpot: fsMultiplierBoost = 110.0; break;
      }
    }

    return [
      for (final sym in SymbolRegistry.all)
        WeightedSymbol(
          sym.assetPath,
          sym.baseWeight * (multipliers[sym.tier] ?? 1.0) * (sym.isMultiplier ? fsMultiplierBoost : 1.0),
        ),
    ];
  }

  /// Picks one asset path proportional to its weight.
  static String pick(List<WeightedSymbol> weights, double totalWeight) {
    double roll = engineRng.nextDouble() * totalWeight;
    for (final w in weights) {
      roll -= w.weight;
      if (roll <= 0) return w.assetPath;
    }
    return weights.last.assetPath;
  }
}
