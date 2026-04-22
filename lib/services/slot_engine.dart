import 'dart:math';
import '../models/slot_symbol.dart';
import '../models/pool_state.dart';

/// Result of a single spin (including all tumble rounds).
class SpinResult {
  final List<List<String>> grid;
  final double totalWin;
  final int tumbleCount;
  final bool freeSpinsTriggered;
  final int scatterCount;
  final double scatterPayout;

  const SpinResult({
    required this.grid,
    required this.totalWin,
    required this.tumbleCount,
    required this.freeSpinsTriggered,
    required this.scatterCount,
    required this.scatterPayout,
  });
}

/// Pure, stateless math engine for slot calculations.
class SlotEngine {
  SlotEngine._();

  static final Random _rng = Random();
  static const int columns = 6;
  static const int rows = 5;
  static const int _totalSlots = columns * rows; // 30

  /// Hit rate per game mode (probability of a winning spin).
  static const Map<GameMode, double> _hitRate = {
    GameMode.recovery: 0.12,
    GameMode.tight: 0.18,
    GameMode.normal: 0.22,
    GameMode.generous: 0.30,
    GameMode.jackpot: 0.40,
  };

  /// Weights for picking WHICH symbol wins (low symbols win more often).
  static const Map<String, double> _winSymbolWeights = {
    'muz': 35,
    'uzum': 25,
    'karpuz': 18,
    'seftali': 10,
    'elma': 6,
    'cilek': 3,
    'pembe_ayi': 1.5,
    'yesil_ayi': 0.8,
    'kalp': 0.3,
  };

  // ─── PUBLIC API ───────────────────────────────────────────────

  static SpinResult spin(PoolState pool, double betAmount) {
    final mode = pool.currentMode;
    final weights = _buildAdjustedWeights(mode);

    // Step 1: Decide win or loss.
    final shouldWin = _rng.nextDouble() < (_hitRate[mode] ?? 0.22);

    // Step 2: Generate appropriate grid.
    final List<List<String>> grid;
    if (shouldWin) {
      grid = _generateWinningGrid(weights, mode);
    } else {
      grid = _generateSafeGrid(weights);
    }

    final uiGrid = _deepCopy(grid);

    // 3. Scatter check.
    final scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;
    final scatterCount = _countAsset(grid, scatterPath);
    final scatterSymbol = SymbolRegistry.all.firstWhere((s) => s.isScatter);
    final scatterPayout = scatterSymbol.getScatterPayoutForCount(scatterCount) * betAmount;
    final freeSpinsTriggered = scatterCount >= 4;

    // 4. Tumble loop.
    double totalWin = 0;
    int tumbleCount = 0;
    final workGrid = _deepCopy(grid);

    while (true) {
      final currentMultiplier = _collectMultipliers(workGrid);
      final counts = _countRegularSymbols(workGrid);

      final winners = <String>[];
      double tumbleWin = 0;

      for (final entry in counts.entries) {
        if (entry.value >= 8) {
          final sym = SymbolRegistry.byPath(entry.key);
          if (sym != null && sym.isRegular) {
            winners.add(entry.key);
            tumbleWin += sym.getPayoutForCount(entry.value) * betAmount;
          }
        }
      }

      if (winners.isEmpty) break;

      if (currentMultiplier > 0) {
        tumbleWin *= currentMultiplier;
      }

      totalWin += tumbleWin;
      tumbleCount++;

      _removeSymbols(workGrid, winners);
      _applyGravity(workGrid);
      // Refill with SAFE symbols (no accidental 8+ chains).
      _fillEmptySafe(workGrid, weights);
    }

    totalWin += scatterPayout;

    return SpinResult(
      grid: uiGrid,
      totalWin: totalWin,
      tumbleCount: tumbleCount,
      freeSpinsTriggered: freeSpinsTriggered,
      scatterCount: scatterCount,
      scatterPayout: scatterPayout,
    );
  }

  // ─── GRID GENERATION ──────────────────────────────────────────

  /// Generates a grid where NO regular symbol reaches 8+.
  static List<List<String>> _generateSafeGrid(List<_WeightedSymbol> weights) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};

    return List.generate(columns, (_) {
      return List.generate(rows, (_) {
        return _pickSafe(weights, totalW, counts, 7);
      });
    });
  }

  /// Generates a grid with exactly [winCount] of [winSymbol], rest safe.
  static List<List<String>> _generateWinningGrid(
      List<_WeightedSymbol> weights, GameMode mode) {
    // Pick which symbol wins.
    final winSymbol = _pickWinningSymbol(mode);
    // Pick how many (8-12), heavily weighted toward 8.
    final winCount = _pickWinCount();

    // Create a flat list of 30 positions.
    final cells = List<String>.filled(_totalSlots, '');

    // Place winning symbols at random positions.
    final positions = List.generate(_totalSlots, (i) => i)..shuffle(_rng);
    for (int i = 0; i < winCount && i < _totalSlots; i++) {
      cells[positions[i]] = winSymbol.assetPath;
    }

    // Fill remaining positions safely.
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{winSymbol.assetPath: winCount};

    for (int i = 0; i < _totalSlots; i++) {
      if (cells[i].isEmpty) {
        cells[i] = _pickSafe(weights, totalW, counts, 7);
      }
    }

    // Convert flat list to 6×5 grid.
    return List.generate(columns, (col) {
      return List.generate(rows, (row) => cells[col * rows + row]);
    });
  }

  /// Picks a symbol without exceeding [maxCount] for any regular symbol.
  static String _pickSafe(List<_WeightedSymbol> weights, double totalWeight,
      Map<String, int> counts, int maxCount) {
    for (int attempt = 0; attempt < 20; attempt++) {
      final picked = _pickWeighted(weights, totalWeight);
      final sym = SymbolRegistry.byPath(picked);
      // Multipliers and scatters are exempt from the cap.
      if (sym == null || !sym.isRegular) return picked;
      if ((counts[picked] ?? 0) < maxCount) {
        counts[picked] = (counts[picked] ?? 0) + 1;
        return picked;
      }
    }
    // Fallback: pick any under-cap regular symbol.
    for (final w in weights) {
      final sym = SymbolRegistry.byPath(w.assetPath);
      if (sym != null && sym.isRegular && (counts[w.assetPath] ?? 0) < maxCount) {
        counts[w.assetPath] = (counts[w.assetPath] ?? 0) + 1;
        return w.assetPath;
      }
    }
    return weights.first.assetPath;
  }

  /// Picks which symbol will be the winner, weighted toward low-value.
  static SlotSymbol _pickWinningSymbol(GameMode mode) {
    final regular = SymbolRegistry.all.where((s) => s.isRegular).toList();
    final totalW = _winSymbolWeights.values.fold<double>(0, (s, v) => s + v);
    double roll = _rng.nextDouble() * totalW;

    for (final sym in regular) {
      final w = _winSymbolWeights[sym.id] ?? 0;
      roll -= w;
      if (roll <= 0) return sym;
    }
    return regular.first;
  }

  /// Picks win count (8-12), heavily skewed toward 8.
  static int _pickWinCount() {
    final r = _rng.nextDouble();
    if (r < 0.55) return 8;  // 55%
    if (r < 0.80) return 9;  // 25%
    if (r < 0.92) return 10; // 12%
    if (r < 0.98) return 11; //  6%
    return 12;                //  2%
  }

  // ─── WEIGHTED RANDOM ──────────────────────────────────────────

  static List<_WeightedSymbol> _buildAdjustedWeights(GameMode mode) {
    final multipliers = SymbolRegistry.weightMultipliers[mode]!;
    return [
      for (final sym in SymbolRegistry.all)
        _WeightedSymbol(sym.assetPath, sym.baseWeight * (multipliers[sym.tier] ?? 1.0)),
    ];
  }

  static String _pickWeighted(List<_WeightedSymbol> weights, double totalWeight) {
    double roll = _rng.nextDouble() * totalWeight;
    for (final w in weights) {
      roll -= w.weight;
      if (roll <= 0) return w.assetPath;
    }
    return weights.last.assetPath;
  }

  // ─── COUNTING ─────────────────────────────────────────────────

  static Map<String, int> _countRegularSymbols(List<List<String>> grid) {
    final counts = <String, int>{};
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isEmpty) continue;
        final sym = SymbolRegistry.byPath(path);
        if (sym != null && sym.isRegular) {
          counts[path] = (counts[path] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  static int _countAsset(List<List<String>> grid, String assetPath) {
    int count = 0;
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r] == assetPath) count++;
      }
    }
    return count;
  }

  static double _collectMultipliers(List<List<String>> grid) {
    double total = 0;
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final sym = SymbolRegistry.byPath(grid[c][r]);
        if (sym != null && sym.isMultiplier) total += sym.multiplierValue;
      }
    }
    return total;
  }

  // ─── TUMBLE MECHANICS ─────────────────────────────────────────

  static void _removeSymbols(List<List<String>> grid, List<String> winnerPaths) {
    final winSet = winnerPaths.toSet();
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (winSet.contains(grid[c][r])) grid[c][r] = '';
      }
    }
  }

  static void _applyGravity(List<List<String>> grid) {
    for (int c = 0; c < columns; c++) {
      final filled = <String>[];
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isNotEmpty) filled.add(grid[c][r]);
      }
      final empty = rows - filled.length;
      for (int r = 0; r < rows; r++) {
        grid[c][r] = r < empty ? '' : filled[r - empty];
      }
    }
  }

  /// Fills empty cells safely (no accidental 8+ chains after tumble).
  static void _fillEmptySafe(List<List<String>> grid, List<_WeightedSymbol> weights) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    // Count existing symbols.
    final counts = <String, int>{};
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isRegular) {
            counts[path] = (counts[path] ?? 0) + 1;
          }
        }
      }
    }
    // Fill empties with cap of 7.
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) {
          grid[c][r] = _pickSafe(weights, totalW, counts, 7);
        }
      }
    }
  }

  static List<List<String>> _deepCopy(List<List<String>> grid) {
    return List.generate(columns, (c) => List.from(grid[c]));
  }
}

class _WeightedSymbol {
  final String assetPath;
  final double weight;
  const _WeightedSymbol(this.assetPath, this.weight);
}
