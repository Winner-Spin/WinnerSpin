import '../models/symbol_registry.dart';
import 'engine_runtime.dart';

/// Sums multiplier-symbol values on the grid.
class MultiplierCollector {
  MultiplierCollector._();

  /// Sums the [multiplierValue] of every multiplier symbol on the grid.
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

  /// Returns the visible multiplier total unchanged.
  ///
  /// Player-facing multiplier math must match the symbols shown on screen:
  /// if the grid shows 2x, the win uses exactly 2x in every game mode.
  static double finalize(double rawMultiplier) => rawMultiplier;
}
