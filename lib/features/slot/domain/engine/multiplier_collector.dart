import '../models/symbol_registry.dart';
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

  /// Preserves the multiplier shown to the player in the final payout.
  static double finalize(double rawMultiplier) => rawMultiplier;
}
