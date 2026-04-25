import 'dart:math';
import '../models/slot_symbol.dart';
import '../models/pool_state.dart';

/// One tumble step: which symbols won + the grid state AFTER removal/gravity/refill.
class TumbleStep {
  /// Asset paths of regular symbols that won (8+ count) this tumble.
  /// UI uses this to fade out matching cells before showing [gridAfter].
  final Set<String> winningPaths;

  /// Grid state after this tumble's removal + gravity + refill.
  final List<List<String>> gridAfter;

  /// Base win amount for this tumble (before global multiplier / scatter bonus).
  final double winAmount;

  const TumbleStep({
    required this.winningPaths,
    required this.gridAfter,
    required this.winAmount,
  });
}

/// Result of a single spin (including all tumble rounds).
class SpinResult {
  /// The grid that drops in initially (before any tumbles).
  final List<List<String>> initialGrid;
  /// Ordered tumble steps. Empty if the initial grid had no winning matches.
  final List<TumbleStep> tumbles;
  final double totalWin;
  final int tumbleCount;
  final bool freeSpinsTriggered;
  /// True if this trigger occurred WHILE the player was already in a Free Spins
  /// round (i.e. a re-trigger). ViewModel should award +5 spins instead of +10.
  final bool isRetrigger;
  final int scatterCount;
  final double scatterPayout;

  const SpinResult({
    required this.initialGrid,
    required this.tumbles,
    required this.totalWin,
    required this.tumbleCount,
    required this.freeSpinsTriggered,
    required this.scatterCount,
    required this.scatterPayout,
    this.isRetrigger = false,
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
    GameMode.recovery: 0.30,  // Softened (was 0.25) so recovery isn't a UX black hole
    GameMode.tight: 0.22,     // v4: 0.28 -> 0.22 to pull base RTP into 65-75% band
    GameMode.normal: 0.30,    // v4: 0.38 -> 0.30 (primary RTP brake)
    GameMode.generous: 0.38,  // v4: 0.48 -> 0.38
    GameMode.jackpot: 0.45,
  };

  /// Probability of naturally triggering Free Spins per game mode (base game).
  /// v4-final: tight/normal/generous trimmed -1% — final calibration cut found
  /// via three 10M-spin runs revealing a concave gradient curve:
  ///   cut 0%   → RTP 97.32 (deviation +0.82)
  ///   cut -1.5% → RTP 96.03 (deviation -0.47)
  ///   cut -3%  → RTP 95.62 (deviation -0.88)
  /// Linear interp in the 0%→-1.5% slope (0.86/cut%) lands target at ~-1%.
  /// Preserves FS-round payout magnitude — only FREQUENCY is reduced.
  static const Map<GameMode, double> _fsTriggerRate = {
    GameMode.recovery: 0.001,    // 0.1% — keeps a sliver of hope alive in recovery
    GameMode.tight: 0.00297,     // 0.297% (v4-final: 0.003 -> 0.00297, -1%)
    GameMode.normal: 0.0099,     // 0.99%  (v4-final: 0.01  -> 0.0099, -1% primary lever)
    GameMode.generous: 0.0198,   // 1.98%  (v4-final: 0.02  -> 0.0198, -1%)
    GameMode.jackpot: 0.03,      // 3.0% — preserved as the "show" jackpot rate
  };

  /// Probability of RE-TRIGGERING Free Spins while ALREADY inside a FS round.
  /// Higher than the initial trigger rate because:
  ///   1. The player is in a "lucky phase" — retriggers are part of the core thrill.
  ///   2. Each retrigger only awards +5 spins (vs +10 initial), so cost is bounded.
  static const Map<GameMode, double> _fsRetriggerRate = {
    GameMode.recovery: 0.0,     // 0% (recovery never grants FS in any form)
    GameMode.tight: 0.02,       // 2%
    GameMode.normal: 0.04,      // 4%
    GameMode.generous: 0.06,    // 6%
    GameMode.jackpot: 0.08,     // 8%
  };

  /// Estimated AVERAGE payout per single Free Spin (in xBet) per mode.
  /// Used by the Virtual Cost guard to forecast the future debt of awarding
  /// a FS round BEFORE the engine commits to it.
  /// NOTE: These constants are coarse estimates and SHOULD be calibrated by
  /// running a Monte-Carlo simulation (SlotEngine.spin in a loop with
  /// isFreeSpins=true, then averaging totalWin / betAmount).
  static const Map<GameMode, double> _fsAvgPayoutPerSpin = {
    GameMode.recovery: 2.0,
    GameMode.tight: 3.0,
    GameMode.normal: 5.0,
    GameMode.generous: 8.0,
    GameMode.jackpot: 12.0,
  };

  /// Safety multiplier on top of expected FS cost.
  /// 2.0 = "only commit to FS if pool can cover 2x the average cost."
  static const double _fsSafetyFactor = 2.0;

  /// Spins awarded per FS event.
  static const int _fsAwardInitial = 10;
  static const int _fsAwardRetrigger = 5;

  /// Estimated total cost of awarding a FS round (in xBet).
  /// = scatter reward (typical 4-scatter case) + (#spins × avg payout per spin)
  static double _expectedFsCostMultiplier(GameMode mode, bool isRetrigger) {
    final perSpin = _fsAvgPayoutPerSpin[mode] ?? 5.0;
    final fsCount = isRetrigger ? _fsAwardRetrigger : _fsAwardInitial;
    const scatterReward = 3.0; // 4-scatter pays 3x (90% of forced cases)
    return scatterReward + (perSpin * fsCount);
  }

  /// Virtual Cost budget guard. Returns true only if the pool can safely
  /// absorb the EXPECTED future cost of an entire FS round.
  /// Bypassed during the first 50-spin warmup to keep early UX exciting.
  static bool _canAffordFsRound(
    PoolState pool,
    double betAmount,
    GameMode mode,
    bool isRetrigger,
  ) {
    if (pool.totalSpins < 50) return true; // warmup: no budget gate
    final virtualCost =
        _expectedFsCostMultiplier(mode, isRetrigger) * betAmount * _fsSafetyFactor;
    return pool.poolBalance >= virtualCost;
  }

  /// Max win multiplier allowed per game mode (Protects RTP).
  /// Dynamically limits based on the current pool balance to prevent bankruptcy.
  static double _getMaxWinMultiplier(GameMode mode, PoolState pool, double betAmount) {
    // Determine the absolute ceiling based on the mode
    double modeCeiling;
    switch (mode) {
      case GameMode.recovery: modeCeiling = 30.0; break;     // Softened (was 10) — small hope still allowed
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
    final spinMaxMults = _rollMaxMultipliers();

    // Initial grid generation at app startup passes betAmount = 0.
    // If we run the win logic with 0 bet, totalWin becomes 0.0, which fails
    // the (totalWin > 0) check in the while loop, causing an infinite freeze.
    if (betAmount <= 0) {
      return SpinResult(
        initialGrid: _generateSafeGrid(weights, spinMaxMults, isFreeSpins: isFreeSpins),
        tumbles: const [],
        totalWin: 0,
        tumbleCount: 0,
        freeSpinsTriggered: false,
        scatterCount: 0,
        scatterPayout: 0,
      );
    }

    final maxAllowedWin = _getMaxWinMultiplier(mode, pool, betAmount) * betAmount;




    // ─── FREE SPINS TRIGGER DECISION (with Virtual Cost guard) ───
    //
    // Two distinct paths:
    //   1. Base game  → may trigger initial FS round (+10 spins)
    //   2. Inside FS  → may RE-trigger (+5 spins)
    //
    // BOTH paths now go through the Virtual Cost guard, which estimates the
    // total future debt of the awarded FS round (scatter payout + N spins ×
    final bool isRetriggerAttempt = isFreeSpins;
    final double fsRate = isRetriggerAttempt
        ? (_fsRetriggerRate[mode] ?? 0.0)
        : (_fsTriggerRate[mode] ?? 0.0);
    final bool canAffordFs =
        _canAffordFsRound(pool, betAmount, mode, isRetriggerAttempt) &&
            maxAllowedWin >= (3.25 * betAmount); // also keep per-spin floor
    final bool triggersFs = canAffordFs && (_rng.nextDouble() < fsRate);





    // 1. Decide win or loss based on hit rate
    final shouldWin = triggersFs || _rng.nextDouble() < (_hitRate[mode] ?? 0.40);

    if (!shouldWin) {
      // Guaranteed losing spin (no 8+ matches, max 3 scatters)
      final grid = _generateSafeGrid(weights, spinMaxMults, isFreeSpins: isFreeSpins);
      return _runSimulation(grid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins);
    }

    // 2. Winning Spin: Try to generate a NATURAL cascade sequence
    // Rejection sampling: We generate a cascade. If it pays too much, we throw it away and try again.
    for (int attempt = 0; attempt < 50; attempt++) {
      final initialGrid = _generateWinningGrid(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      
      // Simulate tumbles naturally (allowing chance for chains/combos)
      final simResult = _runSimulation(initialGrid, weights, betAmount,
          safeRefill: false, maxMults: spinMaxMults, isFreeSpins: isFreeSpins);

      // Check if the simulation resulted in a win within our allowed budget
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult; // Valid natural cascade found!
      }
    }

    // 3. Fallback: If natural cascade failed 50 times (too lucky), force a safe ending.
    int fallbackAttempts = 0;
    while (fallbackAttempts++ < 100) {
      final fallbackGrid = _generateWinningGrid(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      // safeRefill: true ensures no new combos drop, keeping the win amount strictly bounded


      final simResult = _runSimulation(fallbackGrid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins);

      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult; // Valid fallback found within budget!
      }
    }

    // 4. Hard Fail-Safe: If 100 fallback attempts mathematically failed to meet budget,
    return _runSimulation(_generateSafeGrid(weights, spinMaxMults, isFreeSpins: isFreeSpins), weights, betAmount,
        safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins);
  }

  // ─── SIMULATION ENGINE ────────────────────────────────────────

  /// Runs the full tumble loop in memory and returns the final SpinResult.
  static SpinResult _runSimulation(
    List<List<String>> startGrid,
    List<_WeightedSymbol> weights,
    double betAmount,
    {required bool safeRefill,
    required int maxMults,
    bool isFreeSpins = false}
  ) {
    final grid = _deepCopy(startGrid);

    final scatterSymbol = SymbolRegistry.all.firstWhere((s) => s.isScatter);
    final scatterPath = scatterSymbol.assetPath;

    double totalBaseWin = 0;
    int tumbleCount = 0;
    final tumbles = <TumbleStep>[];

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

      final winningPaths = winners.toSet();
      _removeSymbols(grid, winners);
      _applyGravity(grid);

      if (safeRefill) {
        _fillEmptySafe(grid, weights, maxMults, isFreeSpins: isFreeSpins);
      } else {
        _fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins); // Natural cascade chance!
      }

      tumbles.add(TumbleStep(
        winningPaths: winningPaths,
        gridAfter: _deepCopy(grid),
        winAmount: tumbleWin,
      ));
    }

    final finalMultiplier = _collectMultipliers(grid);

    // Evaluate scatters AFTER all tumbles to allow natural cascades to build up scatters
    final scatterCount = _countAsset(grid, scatterPath);
    final scatterPayout = scatterSymbol.getScatterPayoutForCount(scatterCount) * betAmount;
    // Sweet Bonanza-style asymmetric trigger:
    //   - Base game: need 4+ scatters to start a FS round.
    //   - Inside FS: only 3+ scatters needed to retrigger.
    final freeSpinsTriggered = isFreeSpins ? (scatterCount >= 3) : (scatterCount >= 4);

    double totalWin = (totalBaseWin * max(1.0, finalMultiplier)) + scatterPayout;

    return SpinResult(
      initialGrid: _deepCopy(startGrid), // UI shows this first, then plays through tumbles
      tumbles: tumbles,
      totalWin: totalWin,
      tumbleCount: tumbleCount,
      freeSpinsTriggered: freeSpinsTriggered,
      // A retrigger is, by definition, a FS-trigger that occurs WHILE the
      // player is already inside a free spins round.
      isRetrigger: isFreeSpins && freeSpinsTriggered,
      scatterCount: scatterCount,
      scatterPayout: scatterPayout,
    );
  }

  // ─── GRID GENERATION ──────────────────────────────────────────

  /// Generates a grid where NO regular symbol reaches 8, and scatters are capped.
  static List<List<String>> _generateSafeGrid(List<_WeightedSymbol> weights, int maxMults, {bool isFreeSpins = false}) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};

    return List.generate(columns, (_) {
      return List.generate(rows, (_) {
        return _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: isFreeSpins ? 2 : 3, maxMultiplier: maxMults);
      });
    });
  }

  /// Generates a grid with exactly 8-12 of ONE symbol, rest safe.
  static List<List<String>> _generateWinningGrid(List<_WeightedSymbol> weights, GameMode mode, int maxMults, {bool forceScatters = false, bool isFreeSpins = false}) {
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
      
      final r = _rng.nextDouble();
      if (isFreeSpins) {
        // Retrigger distribution: 90% for 3, 8% for 4, 2% for 5
        if (r < 0.90) {
          scatterCount = 3;
        } else if (r < 0.98) {
          scatterCount = 4;
        } else {
          scatterCount = 5;
        }
      } else {
        // Initial trigger distribution: 90% for 4, 8% for 5, 2% for 6
        if (r < 0.90) {
          scatterCount = 4;
        } else if (r < 0.98) {
          scatterCount = 5;
        } else {
          scatterCount = 6;
        }
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
        cells[i] = _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: isFreeSpins ? 2 : 3, maxMultiplier: maxMults);
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
    {required int maxRegular, required int maxScatter, required int maxMultiplier}
  ) {
    for (int attempt = 0; attempt < 20; attempt++) {
      final picked = _pickWeighted(weights, totalWeight);
      final sym = SymbolRegistry.byPath(picked);
      
      if (sym == null) return picked;
      
      if (sym.isMultiplier) {
        final currentMults = counts['TOTAL_MULTIPLIERS'] ?? 0;
        if (currentMults < maxMultiplier) {
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
    final multipliers = SymbolRegistry.weightMultipliers[mode] ?? {};
    
    double totalW = 0;
    final adjustedWeights = <SlotSymbol, double>{};
    
    for (final sym in regular) {
      final baseW = _winSymbolWeights[sym.id] ?? 0;
      final mult = multipliers[sym.tier] ?? 1.0;
      final adjW = baseW * mult;
      adjustedWeights[sym] = adjW;
      totalW += adjW;
    }

    double roll = _rng.nextDouble() * totalW;
    for (final sym in regular) {
      roll -= adjustedWeights[sym]!;
      if (roll <= 0) return sym;
    }
    return regular.first;
  }

  static int _pickWinCount() {
    // v4: aggressively biased toward 8 (minimum payout) to bring base RTP
    // into the 65–75% target band. Diagnostic showed v3 base RTP at 88.5%.
    //   8: 75%   9: 15%   10: 6%   11: 3%   12: 1%
    final r = _rng.nextDouble();
    if (r < 0.75) return 8;  // 75%
    if (r < 0.90) return 9;  // 15%
    if (r < 0.96) return 10; // 6%
    if (r < 0.99) return 11; // 3%
    return 12;               // 1%
  }

  static int _rollMaxMultipliers() {
    // v4: capacity tightened — multipliers should shine in Free Spins,
    // not in base game. Pulled higher tiers down hard.
    //   2: 90%   3: 7%   4: 2%   5: 0.8%   6: 0.2%
    final r = _rng.nextDouble();
    if (r < 0.90) return 2;   // 90%
    if (r < 0.97) return 3;   // 7%
    if (r < 0.99) return 4;   // 2%
    if (r < 0.998) return 5;  // 0.8%
    return 6;                 // 0.2%
  }

  // ─── WEIGHTED RANDOM ──────────────────────────────────────────

  static List<_WeightedSymbol> _buildAdjustedWeights(GameMode mode, bool isFreeSpins) {
    final multipliers = SymbolRegistry.weightMultipliers[mode]!;
    
    // Dynamically adjust Free Spins multiplier boost based on game mode (pool state)
    // v4-final: -10% calibration from original to land sustained RTP on %96.50.
    // Verified at 10M-spin scale; smaller samples were dominated by FS-round
    // variance and gave misleading point estimates.
    double fsMultiplierBoost = 1.0;
    if (isFreeSpins) {
      switch (mode) {
        case GameMode.recovery: fsMultiplierBoost = 2.0; break;
        case GameMode.tight: fsMultiplierBoost = 4.5; break;    // v4-final: 5.0 -> 4.5 (-10%)
        case GameMode.normal: fsMultiplierBoost = 9.0; break;   // v4-final: 10.0 -> 9.0 (-10%)
        case GameMode.generous: fsMultiplierBoost = 13.5; break; // v4-final: 15.0 -> 13.5 (-10%)
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
  static void _fillEmptySafe(List<List<String>> grid, List<_WeightedSymbol> weights, int maxMults, {bool isFreeSpins = false}) {
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
          grid[c][r] = _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: isFreeSpins ? 2 : 3, maxMultiplier: maxMults);
        }
      }
    }
  }

  /// Refills empty spaces randomly based on weights (Can create new cascades).
  static void _fillEmptyRandom(List<List<String>> grid, List<_WeightedSymbol> weights, int maxMults, {bool isFreeSpins = false}) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);

    int totalMults = 0;
    int totalScatters = 0;
    final scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;

    // Count existing to enforce caps
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isMultiplier) totalMults++;
          if (path == scatterPath) totalScatters++;
        }
      }
    }

    final maxScatter = isFreeSpins ? 2 : 3;

    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) {
          // Pick randomly, but cap multipliers to dynamic maxMults
          for (int attempt = 0; attempt < 20; attempt++) {
            final picked = _pickWeighted(weights, totalW);
            final sym = SymbolRegistry.byPath(picked);
            if (sym != null && sym.isMultiplier) {
              if (totalMults < maxMults) {
                totalMults++;
                grid[c][r] = picked;
                break;
              }
            } else if (sym != null && sym.isScatter) {
              if (totalScatters < maxScatter) {
                totalScatters++;
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
