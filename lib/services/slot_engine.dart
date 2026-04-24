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
    GameMode.recovery: 0.25,
    GameMode.tight: 0.32,
    GameMode.normal: 0.40, // Increased to match Sweet Bonanza
    GameMode.generous: 0.48,
    GameMode.jackpot: 0.45,
  };

  /// Probability of naturally triggering Free Spins per game mode.
  static const Map<GameMode, double> _fsTriggerRate = {
    GameMode.recovery: 0.0,     // 0%
    GameMode.tight: 0.003,      // 0.3%
    GameMode.normal: 0.01,      // 1.0%
    GameMode.generous: 0.02,    // 2.0%
    GameMode.jackpot: 0.03,     // 3.0%
  };

  /// Max win multiplier allowed per game mode (Protects RTP).
  /// Dynamically limits based on the current pool balance to prevent bankruptcy.
  static double _getMaxWinMultiplier(GameMode mode, PoolState pool, double betAmount) {
    // Determine the absolute ceiling based on the mode
    double modeCeiling;
    switch (mode) {
      case GameMode.recovery: modeCeiling = 10.0; break;     // Very tight limit
      case GameMode.tight: modeCeiling = 100.0; break;       // Tight limit
      case GameMode.normal: modeCeiling = 2500.0; break;     // High volatility target
      case GameMode.generous: modeCeiling = 5000.0; break;   // Very generous
      case GameMode.jackpot: modeCeiling = 10000.0; break;   // Insane potential
    }

    // For the first 50 spins, ignore pool balance to draw players in
    if (pool.totalSpins < 50) return modeCeiling;

    // After 50 spins, never allow a single spin to drain more than 50% of the pool.
    // Calculate the multiplier that would drain 50% of the pool balance.
    final safePoolMultiplier = (pool.poolBalance * 0.5) / betAmount;

    // Gradual Budget Floor to prevent cliff effects
    double absoluteMinimum;
    if (pool.poolBalance <= 0) {
      absoluteMinimum = 1.0;
    } else if (pool.poolBalance < betAmount * 10) {
      absoluteMinimum = 2.0;
    } else {
      absoluteMinimum = 5.0;
    }

    return max(absoluteMinimum, min(modeCeiling, safePoolMultiplier));
  }

  /// Weights for picking WHICH symbol wins initially.
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

  static SpinResult spin(PoolState pool, double betAmount, {bool isFreeSpins = false}) {
    final mode = pool.currentMode;
    final weights = _buildAdjustedWeights(mode, isFreeSpins);

    // Initial grid generation at app startup passes betAmount = 0.
    // If we run the win logic with 0 bet, totalWin becomes 0.0, which fails
    // the (totalWin > 0) check in the while loop, causing an infinite freeze.
    if (betAmount <= 0) {
      return SpinResult(
        grid: _generateSafeGrid(weights),
        totalWin: 0,
        tumbleCount: 0,
        freeSpinsTriggered: false,
        scatterCount: 0,
        scatterPayout: 0,
      );
    }

    final maxAllowedWin = _getMaxWinMultiplier(mode, pool, betAmount) * betAmount;

    // A free spin trigger costs at LEAST 3.25x the bet (3x scatter + 0.25x min win).
    // If the maxAllowedWin is less than that, we CANNOT afford to trigger free spins.
    final bool canAffordFs = maxAllowedWin >= (3.25 * betAmount);

    // Check if we should trigger free spins naturally in this spin
    // (Only triggers if we are NOT already in free spins AND we can afford it)
    final bool triggersFs = !isFreeSpins && canAffordFs && (_rng.nextDouble() < (_fsTriggerRate[mode] ?? 0.01));

    // 1. Decide win or loss based on hit rate
    final shouldWin = triggersFs || _rng.nextDouble() < (_hitRate[mode] ?? 0.40);

    if (!shouldWin) {
      // Guaranteed losing spin (no 8+ matches, max 3 scatters)
      final grid = _generateSafeGrid(weights);
      return _runSimulation(grid, weights, betAmount, safeRefill: true);
    }

    // 2. Winning Spin: Try to generate a NATURAL cascade sequence
    // Rejection sampling: We generate a cascade. If it pays too much, we throw it away and try again.
    for (int attempt = 0; attempt < 50; attempt++) {
      final initialGrid = _generateWinningGrid(weights, mode, forceScatters: triggersFs);
      
      // Simulate tumbles naturally (allowing chance for chains/combos)
      final simResult = _runSimulation(initialGrid, weights, betAmount, safeRefill: false);

      // Check if the simulation resulted in a win within our allowed budget
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult; // Valid natural cascade found!
      }
    }

    // 3. Fallback: If natural cascade failed 50 times (too lucky), force a safe ending.
    // We loop this as well to ENSURE we NEVER exceed the maxAllowedWin budget.
    int fallbackAttempts = 0;
    while (fallbackAttempts++ < 100) {
      final fallbackGrid = _generateWinningGrid(weights, mode, forceScatters: triggersFs);
      // safeRefill: true ensures no new combos drop, keeping the win amount strictly bounded
      final simResult = _runSimulation(fallbackGrid, weights, betAmount, safeRefill: true);
      
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult; // Valid fallback found within budget!
      }
    }

    // 4. Hard Fail-Safe: If 100 fallback attempts mathematically failed to meet budget,
    // abort the win and return a guaranteed losing grid to prevent application freeze.
    return _runSimulation(_generateSafeGrid(weights), weights, betAmount, safeRefill: true);
  }

  // ─── SIMULATION ENGINE ────────────────────────────────────────

  /// Runs the full tumble loop in memory and returns the final SpinResult.
  static SpinResult _runSimulation(
    List<List<String>> startGrid, 
    List<_WeightedSymbol> weights, 
    double betAmount, 
    {required bool safeRefill}
  ) {
    final grid = _deepCopy(startGrid);
    
    final scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;
    final scatterCount = _countAsset(grid, scatterPath);
    final scatterSymbol = SymbolRegistry.all.firstWhere((s) => s.isScatter);
    final scatterPayout = scatterSymbol.getScatterPayoutForCount(scatterCount) * betAmount;
    final freeSpinsTriggered = scatterCount >= 4;

    double totalBaseWin = 0;
    int tumbleCount = 0;

    while (true) {
      final counts = _countRegularSymbols(grid);

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

      if (winners.isEmpty) break; // No more wins in this tumble

      totalBaseWin += tumbleWin;
      tumbleCount++;

      _removeSymbols(grid, winners);
      _applyGravity(grid);
      
      if (safeRefill) {
        _fillEmptySafe(grid, weights);
      } else {
        _fillEmptyRandom(grid, weights); // Natural cascade chance!
      }
    }

    final finalMultiplier = _collectMultipliers(grid);
    double totalWin = (totalBaseWin * max(1.0, finalMultiplier)) + scatterPayout;

    return SpinResult(
      grid: _deepCopy(startGrid), // UI needs the initial state, not the empty exploded grid
      totalWin: totalWin,
      tumbleCount: tumbleCount,
      freeSpinsTriggered: freeSpinsTriggered,
      scatterCount: scatterCount,
      scatterPayout: scatterPayout,
    );
  }

  // ─── GRID GENERATION ──────────────────────────────────────────

  /// Generates a grid where NO regular symbol reaches 8, and scatters are capped at 3.
  static List<List<String>> _generateSafeGrid(List<_WeightedSymbol> weights) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};

    return List.generate(columns, (_) {
      return List.generate(rows, (_) {
        return _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: 3);
      });
    });
  }

  /// Generates a grid with exactly 8-12 of ONE symbol, rest safe.
  static List<List<String>> _generateWinningGrid(List<_WeightedSymbol> weights, GameMode mode, {bool forceScatters = false}) {
    final winSymbol = _pickWinningSymbol(mode);
    final winCount = _pickWinCount();
    final cells = List<String>.filled(_totalSlots, '');

    final positions = List.generate(_totalSlots, (i) => i)..shuffle(_rng);
    
    int posIndex = 0;
    for (int i = 0; i < winCount && posIndex < _totalSlots; i++) {
      cells[positions[posIndex++]] = winSymbol.assetPath;
    }

    int scatterCount = 0;
    String scatterPath = '';
    // Force scatters if trigger is active
    if (forceScatters) {
      scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;
      
      // Determine scatter count: 90% for 4, 8% for 5, 2% for 6
      final r = _rng.nextDouble();
      if (r < 0.90) {
        scatterCount = 4;
      } else if (r < 0.98) {
        scatterCount = 5;
      } else {
        scatterCount = 6;
      }

      for (int i = 0; i < scatterCount && posIndex < _totalSlots; i++) {
        cells[positions[posIndex++]] = scatterPath;
      }
    }

    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{winSymbol.assetPath: winCount};
    if (scatterCount > 0) {
      counts[scatterPath] = scatterCount;
    }

    for (int i = 0; i < _totalSlots; i++) {
      if (cells[i].isEmpty) {
        cells[i] = _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: 3);
      }
    }

    return List.generate(columns, (col) {
      return List.generate(rows, (row) => cells[col * rows + row]);
    });
  }

  /// Picks a symbol while enforcing caps.
  static String _pickSafe(
    List<_WeightedSymbol> weights, 
    double totalWeight,
    Map<String, int> counts, 
    {required int maxRegular, required int maxScatter}
  ) {
    for (int attempt = 0; attempt < 20; attempt++) {
      final picked = _pickWeighted(weights, totalWeight);
      final sym = SymbolRegistry.byPath(picked);
      
      if (sym == null) return picked;
      
      if (sym.isMultiplier) {
        final currentMults = counts['TOTAL_MULTIPLIERS'] ?? 0;
        if (currentMults < 3) {
          counts['TOTAL_MULTIPLIERS'] = currentMults + 1;
          return picked;
        } else {
          continue; // Cap reached, try again
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
    
    // Fallback: Pick first under-cap regular symbol
    for (final w in weights) {
      final sym = SymbolRegistry.byPath(w.assetPath);
      if (sym != null && sym.isRegular && (counts[w.assetPath] ?? 0) < maxRegular) {
        counts[w.assetPath] = (counts[w.assetPath] ?? 0) + 1;
        return w.assetPath;
      }
    }
    return weights.first.assetPath;
  }

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

  static int _pickWinCount() {
    final r = _rng.nextDouble();
    if (r < 0.45) return 8;  // 45%
    if (r < 0.70) return 9;  // 25%
    if (r < 0.85) return 10; // 15%
    if (r < 0.95) return 11; // 10%
    return 12;               // 5% 
  }

  // ─── WEIGHTED RANDOM ──────────────────────────────────────────

  static List<_WeightedSymbol> _buildAdjustedWeights(GameMode mode, bool isFreeSpins) {
    final multipliers = SymbolRegistry.weightMultipliers[mode]!;
    
    // Dynamically adjust Free Spins multiplier boost based on game mode (pool state)
    double fsMultiplierBoost = 1.0;
    if (isFreeSpins) {
      switch (mode) {
        case GameMode.recovery: fsMultiplierBoost = 2.0; break;
        case GameMode.tight: fsMultiplierBoost = 5.0; break;
        case GameMode.normal: fsMultiplierBoost = 10.0; break;
        case GameMode.generous: fsMultiplierBoost = 15.0; break;
        case GameMode.jackpot: fsMultiplierBoost = 25.0; break;
      }
    }

    return [
      for (final sym in SymbolRegistry.all)
        _WeightedSymbol(
          sym.assetPath, 
          // Boost multiplier weights dynamically if in Free Spins mode!
          sym.baseWeight * (multipliers[sym.tier] ?? 1.0) * (sym.isMultiplier ? fsMultiplierBoost : 1.0)
        ),
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

  // ─── COUNTING & TUMBLE UTILS ──────────────────────────────────

  static Map<String, int> _countRegularSymbols(List<List<String>> grid) {
    final counts = <String, int>{};
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isEmpty) continue;
        final sym = SymbolRegistry.byPath(path);
        if (sym != null && sym.isRegular) counts[path] = (counts[path] ?? 0) + 1;
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

  /// Refills empty spaces safely (Caps regular symbols to prevent new wins)
  static void _fillEmptySafe(List<List<String>> grid, List<_WeightedSymbol> weights) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};
    int totalMults = 0;
    
    // Count existing to enforce caps
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          counts[path] = (counts[path] ?? 0) + 1;
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isMultiplier) totalMults++;
        }
      }
    }
    counts['TOTAL_MULTIPLIERS'] = totalMults;

    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) {
          grid[c][r] = _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: 3);
        }
      }
    }
  }

  /// Refills empty spaces purely based on random weights (NATURAL CASCADES!)
  static void _fillEmptyRandom(List<List<String>> grid, List<_WeightedSymbol> weights) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    
    int totalMults = 0;
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isMultiplier) totalMults++;
        }
      }
    }

    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) {
          // Pick randomly, but cap multipliers to 3
          for (int attempt = 0; attempt < 20; attempt++) {
            final picked = _pickWeighted(weights, totalW);
            final sym = SymbolRegistry.byPath(picked);
            if (sym != null && sym.isMultiplier) {
              if (totalMults < 3) {
                totalMults++;
                grid[c][r] = picked;
                break;
              }
            } else {
              grid[c][r] = picked;
              break;
            }
          }
          if (grid[c][r].isEmpty) grid[c][r] = weights.first.assetPath;
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
