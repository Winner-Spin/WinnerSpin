import '../enums/game_mode.dart';
import '../models/slot_symbol.dart';
import '../models/symbol_registry.dart';
import 'engine_runtime.dart';
import 'rtp_config.dart';
import 'weighted_random.dart';

/// Builds initial 6×5 grids — safe (guaranteed losing) or winning (with a
/// forced cluster of 8–12 of one symbol).
class GridGenerator {
  GridGenerator._();

  /// Generates a grid where no regular symbol reaches 8 and scatters are capped.
  static List<List<String>> generateSafe(
    List<WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};

    return List.generate(kEngineColumns, (_) {
      return List.generate(kEngineRows, (_) {
        return pickSafe(
          weights,
          totalW,
          counts,
          maxRegular: 7,
          maxScatter: isFreeSpins ? 2 : 3,
          maxMultiplier: maxMults,
        );
      });
    });
  }

  /// Generates a grid with exactly 8–12 of one symbol, rest safe.
  static List<List<String>> generateWinning(
    List<WeightedSymbol> weights,
    GameMode mode,
    int maxMults, {
    bool forceScatters = false,
    bool isFreeSpins = false,
  }) {
    final winSymbol = _pickWinningSymbol(mode);
    final winCount = _pickWinCount();
    final cells = List<String>.filled(kEngineTotalSlots, '');

    final positions = List.generate(kEngineTotalSlots, (i) => i)..shuffle(engineRng);

    int posIndex = 0;
    for (int i = 0; i < winCount && posIndex < kEngineTotalSlots; i++) {
      cells[positions[posIndex++]] = winSymbol.assetPath;
    }

    int scatterCount = 0;
    String scatterPath = '';
    if (forceScatters) {
      scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;

      final r = engineRng.nextDouble();
      if (isFreeSpins) {
        // Retrigger: 90% for 3, 8% for 4, 2% for 5.
        if (r < 0.90) {
          scatterCount = 3;
        } else if (r < 0.98) {
          scatterCount = 4;
        } else {
          scatterCount = 5;
        }
      } else {
        // Initial trigger: 90% for 4, 8% for 5, 2% for 6.
        if (r < 0.90) {
          scatterCount = 4;
        } else if (r < 0.98) {
          scatterCount = 5;
        } else {
          scatterCount = 6;
        }
      }

      for (int i = 0; i < scatterCount && posIndex < kEngineTotalSlots; i++) {
        cells[positions[posIndex++]] = scatterPath;
      }
    }

    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{winSymbol.assetPath: winCount};
    if (scatterCount > 0) {
      counts[scatterPath] = scatterCount;
    }

    for (int i = 0; i < kEngineTotalSlots; i++) {
      if (cells[i].isEmpty) {
        cells[i] = pickSafe(
          weights,
          totalW,
          counts,
          maxRegular: 7,
          maxScatter: isFreeSpins ? 2 : 3,
          maxMultiplier: maxMults,
        );
      }
    }

    return List.generate(kEngineColumns, (col) {
      return List.generate(kEngineRows, (row) => cells[col * kEngineRows + row]);
    });
  }

  /// Per-spin cap on multiplier-symbol count. FS allows 1–6, base 2–6.
  static int rollMaxMultipliers({bool isFreeSpins = false}) {
    final r = engineRng.nextDouble();
    if (isFreeSpins) {
      if (r < 0.08) return 1;
      if (r < 0.30) return 2;
      if (r < 0.62) return 3;
      if (r < 0.87) return 4;
      if (r < 0.97) return 5;
      return 6;
    }
    if (r < 0.90) return 2;
    if (r < 0.97) return 3;
    if (r < 0.99) return 4;
    if (r < 0.998) return 5;
    return 6;
  }

  /// Weighted-random symbol pick that enforces per-grid caps.
  /// Public so [ChainForcer] can reuse the same cap-aware picker without
  /// duplicating the logic.
  static String pickSafe(
    List<WeightedSymbol> weights,
    double totalWeight,
    Map<String, int> counts,
    {required int maxRegular, required int maxScatter, required int maxMultiplier}
  ) {
    for (int attempt = 0; attempt < 20; attempt++) {
      final picked = WeightedRandom.pick(weights, totalWeight);
      final sym = SymbolRegistry.byPath(picked);

      if (sym == null) return picked;

      if (sym.isMultiplier) {
        final currentMults = counts['TOTAL_MULTIPLIERS'] ?? 0;
        if (currentMults < maxMultiplier) {
          counts['TOTAL_MULTIPLIERS'] = currentMults + 1;
          return picked;
        } else {
          continue;
        }
      }

      final currentCount = counts[picked] ?? 0;
      if (sym.isScatter) {
        if (currentCount < maxScatter) {
          counts[picked] = currentCount + 1;
          return picked;
        }
      } else if (sym.isRegular) {
        if (currentCount < maxRegular) {
          counts[picked] = currentCount + 1;
          return picked;
        }
      }
    }

    // Pick the first under-cap regular as a deterministic fallback.
    for (final w in weights) {
      final sym = SymbolRegistry.byPath(w.assetPath);
      if (sym != null && sym.isRegular && (counts[w.assetPath] ?? 0) < maxRegular) {
        counts[w.assetPath] = (counts[w.assetPath] ?? 0) + 1;
        return w.assetPath;
      }
    }
    // Hard fallback — never leak a scatter or multiplier into a "safe" cell.
    return SymbolRegistry.all.firstWhere((s) => s.isRegular).assetPath;
  }

  /// Picks the winning symbol on a winning spin, weighted by mode tier.
  static SlotSymbol _pickWinningSymbol(GameMode mode) {
    final regular = SymbolRegistry.all.where((s) => s.isRegular).toList();
    final multipliers = SymbolRegistry.weightMultipliers[mode] ?? {};

    double totalW = 0;
    final adjustedWeights = <SlotSymbol, double>{};

    for (final sym in regular) {
      final baseW = RtpConfig.winSymbolWeights[sym.id] ?? 0;
      final mult = multipliers[sym.tier] ?? 1.0;
      final adjW = baseW * mult;
      adjustedWeights[sym] = adjW;
      totalW += adjW;
    }

    double roll = engineRng.nextDouble() * totalW;
    for (final sym in regular) {
      roll -= adjustedWeights[sym]!;
      if (roll <= 0) return sym;
    }
    return regular.first;
  }

  /// Picks the winning-symbol count (8–12) biased toward the minimum payout.
  static int _pickWinCount() {
    final r = engineRng.nextDouble();
    if (r < 0.75) return 8;
    if (r < 0.90) return 9;
    if (r < 0.96) return 10;
    if (r < 0.99) return 11;
    return 12;
  }
}
