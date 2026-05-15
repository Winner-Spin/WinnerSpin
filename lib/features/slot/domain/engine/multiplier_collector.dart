import 'dart:math';

import '../models/symbol_registry.dart';
import 'ante_config.dart';
import 'buy_config.dart';
import 'engine_runtime.dart';

class MultiplierCollector {
  MultiplierCollector._();

  static double rawSum(List<List<String>> grid) {
    double total = 0;
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        final sym = SymbolRegistry.byPath(grid[c][r]);
        if (sym != null && sym.isMultiplier) total += sym.multiplierValue;
      }
    }
    return total;
  }

  /// Applies ante/buy FS scaling. Floor at 1.0.
  static double finalize(
    double rawMultiplier, {
    required bool isFreeSpins,
    required bool anteBet,
    required bool buyFs,
  }) {
    if (!isFreeSpins || rawMultiplier <= 1.0) return rawMultiplier;
    if (anteBet) {
      return max(1.0, rawMultiplier * AnteConfig.fsMultiplierScale);
    }
    if (buyFs) {
      return max(1.0, rawMultiplier * BuyConfig.fsMultiplierScale);
    }
    return rawMultiplier;
  }
}
