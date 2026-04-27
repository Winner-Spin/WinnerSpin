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
  final Set<int> winningPositions;

  const SpinResult({
    required this.initialGrid,
    required this.tumbles,
    required this.totalWin,
    required this.tumbleCount,
    required this.freeSpinsTriggered,
    required this.scatterCount,
    required this.scatterPayout,
    this.winningPositions = const {},
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

  /// Probability of a winning spin per game mode.
  static const Map<GameMode, double> _hitRate = {
    GameMode.recovery: 0.310,
    GameMode.tight: 0.260,
    GameMode.normal: 0.260,
    GameMode.generous: 0.240,
    GameMode.jackpot: 0.260,
  };

  /// Multiplier applied to [_hitRate] inside a Free Spins round.
  /// Higher modes get larger boosts so jackpot/generous FS feel premium.
  static const Map<GameMode, double> _fsHitRateBoost = {
    GameMode.recovery: 1.22,
    GameMode.tight: 1.22,
    GameMode.normal: 1.275,
    GameMode.generous: 1.325,
    GameMode.jackpot: 1.375,
  };

  /// Probability of naturally triggering Free Spins per base spin.
  /// Doubled by Ante Bet at the spin call site (see [_anteFsTriggerMultiplier]).
  static const Map<GameMode, double> _fsTriggerRate = {
    GameMode.recovery: 0.00075,
    GameMode.tight: 0.00141,
    GameMode.normal: 0.00315,
    GameMode.generous: 0.00517,
    GameMode.jackpot: 0.0235,
  };

  /// Probability of re-triggering Free Spins from inside a FS round.
  static const Map<GameMode, double> _fsRetriggerRate = {
    GameMode.recovery: 0.0,
    GameMode.tight: 0.01,
    GameMode.normal: 0.02,
    GameMode.generous: 0.03,
    GameMode.jackpot: 0.05,
  };

  /// Estimated avg per-FS-spin payout (xBet). Drives the Virtual Cost guard.
  /// Errs conservative — overestimates real cost to keep the pool safe.
  static const Map<GameMode, double> _fsAvgPayoutPerSpin = {
    GameMode.recovery: 4.0,
    GameMode.tight: 6.0,
    GameMode.normal: 10.0,
    GameMode.generous: 15.0,
    GameMode.jackpot: 22.0,
  };

  /// Pool-cover headroom for naturally-triggered FS rounds.
  static const double _fsSafetyFactor = 2.0;

  /// Stricter pool-cover headroom for player-initiated buys (whale clustering).
  static const double _buyFsSafetyFactor = 3.0;

  // ── Ante Bet overrides ──
  // Active when anteBet=true. Never touches farm-mode RTP.

  /// Ante doubles the FS trigger rate (matches the "2× FS chance" UI claim).
  static const double _anteFsTriggerMultiplier = 2.0;

  /// Ante's pool-cover headroom — between natural (2.0) and buy (3.0).
  static const double _anteFsSafetyFactor = 2.5;

  /// Scales the multiplier sum DOWN inside ante-triggered FS rounds so the
  /// 2× trigger rate doesn't inflate ante RTP above 96.5%. Visuals unchanged.
  static const double _anteFsMultiplierScale = 0.80;

  // ── Buy Bonus overrides ──
  // Active when buyFs=true. Never touches farm or ante RTP.

  /// Scales the multiplier sum UP inside bought FS rounds. Lifts buy RTP
  /// from the natural ~91% to industry-standard ~96.5%. Visuals unchanged.
  static const double _buyFsMultiplierScale = 1.06;

  /// Spins awarded per FS event.
  static const int _fsAwardInitial = 10;
  static const int _fsAwardRetrigger = 5;

  /// Buy Free Spins price as a multiple of base bet.
  static const double buyFeaturePriceMultiplier = 100.0;

  /// Base-game forced-chain probability. Zero — natural cascade rate already
  /// matches industry tumble-depth targets without seeding.
  static const double _chainProbBase = 0.0;

  /// FS forced-chain probability tapered by tumble depth — keeps the long
  /// tail (5+ tumbles) under ~5% of wins while letting natural cascades
  /// hit industry-standard depth distribution.
  static double _fsForcedChainProb(int tumblesSoFar) {
    if (tumblesSoFar <= 1) return 0.55;
    if (tumblesSoFar == 2) return 0.42;
    if (tumblesSoFar == 3) return 0.30;
    if (tumblesSoFar == 4) return 0.18;
    return 0.08;
  }

  /// Estimated total xBet cost of awarding a FS round.
  static double _expectedFsCostMultiplier(GameMode mode, bool isRetrigger) {
    final perSpin = _fsAvgPayoutPerSpin[mode] ?? 10.0;
    final fsCount = isRetrigger ? _fsAwardRetrigger : _fsAwardInitial;
    const scatterReward = 3.0;
    return scatterReward + (perSpin * fsCount);
  }

  /// Virtual Cost budget guard. Bypassed during the 50-spin warmup.
  /// [isAnte] picks the stricter ante safety factor.
  static bool _canAffordFsRound(
    PoolState pool,
    double betAmount,
    GameMode mode,
    bool isRetrigger, {
    bool isAnte = false,
  }) {
    if (pool.totalSpins < 50) return true;
    final safetyFactor = isAnte ? _anteFsSafetyFactor : _fsSafetyFactor;
    final virtualCost =
        _expectedFsCostMultiplier(mode, isRetrigger) * betAmount * safetyFactor;
    return pool.poolBalance >= virtualCost;
  }

  /// Buy-FS variant of the Virtual Cost guard. The 100×bet fee itself is
  /// pool-incoming revenue, so the guard checks the POST-fee headroom.
  static bool canAffordBuyFs(PoolState pool, double betAmount) {
    if (pool.totalSpins < 50) return true;
    final mode = pool.currentMode;
    final expectedCost = _expectedFsCostMultiplier(mode, false) * betAmount;
    final buyFee = betAmount * buyFeaturePriceMultiplier;
    final virtualCost = expectedCost * _buyFsSafetyFactor;
    return (pool.poolBalance + buyFee) >= virtualCost;
  }

  /// Per-mode max win cap, FS-aware. Floors at the larger of:
  ///   • mode ceiling
  ///   • 50% of pool balance (post-warmup, prevents bankrupting drains)
  ///   • a small absolute minimum that scales with pool health
  static double _getMaxWinMultiplier(
    GameMode mode,
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
  }) {
    double modeCeiling;
    if (isFreeSpins) {
      switch (mode) {
        case GameMode.recovery: modeCeiling = 60.0; break;
        case GameMode.tight: modeCeiling = 400.0; break;
        case GameMode.normal: modeCeiling = 8000.0; break;
        case GameMode.generous: modeCeiling = 15000.0; break;
        case GameMode.jackpot: modeCeiling = 21100.0; break;
      }
    } else {
      switch (mode) {
        case GameMode.recovery: modeCeiling = 30.0; break;
        case GameMode.tight: modeCeiling = 100.0; break;
        case GameMode.normal: modeCeiling = 2500.0; break;
        case GameMode.generous: modeCeiling = 5000.0; break;
        case GameMode.jackpot: modeCeiling = 10000.0; break;
      }
    }

    if (pool.totalSpins < 50) return modeCeiling;

    final safePoolMultiplier = (pool.poolBalance * 0.5) / betAmount;

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

  /// Weights for picking which symbol wins on a winning spin.
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

  static SpinResult spin(
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
    bool anteBet = false,
    bool buyFs = false,
  }) {
    final mode = pool.currentMode;
    final weights = _buildAdjustedWeights(mode, isFreeSpins);
    final spinMaxMults = _rollMaxMultipliers(isFreeSpins: isFreeSpins);

    // betAmount=0 happens during initial UI grid generation at app startup.
    // Returning a zero-win result short-circuits the win loop's infinite spin.
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

    final maxAllowedWin =
        _getMaxWinMultiplier(mode, pool, betAmount, isFreeSpins: isFreeSpins) * betAmount;




    // FS trigger decision — base or retrigger rate, optionally bumped by
    // ante on base spins. Both paths gated by the Virtual Cost guard.
    final bool isRetriggerAttempt = isFreeSpins;
    final double baseFsRate = isRetriggerAttempt
        ? (_fsRetriggerRate[mode] ?? 0.0)
        : (_fsTriggerRate[mode] ?? 0.0);
    final double fsRate = (anteBet && !isRetriggerAttempt)
        ? baseFsRate * _anteFsTriggerMultiplier
        : baseFsRate;
    final bool canAffordFs = _canAffordFsRound(
          pool, betAmount, mode, isRetriggerAttempt,
          isAnte: anteBet && !isRetriggerAttempt,
        ) &&
        maxAllowedWin >= (3.25 * betAmount);
    final bool triggersFs = canAffordFs && (_rng.nextDouble() < fsRate);





    // FS rounds boost hit rate so the round feels lucky.
    final double effectiveHitRate = isFreeSpins
        ? min(0.95, (_hitRate[mode] ?? 0.30) * (_fsHitRateBoost[mode] ?? 1.25))
        : (_hitRate[mode] ?? 0.30);
    final shouldWin = triggersFs || _rng.nextDouble() < effectiveHitRate;

    if (!shouldWin) {
      final grid = _generateSafeGrid(weights, spinMaxMults, isFreeSpins: isFreeSpins);
      return _runSimulation(grid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
    }

    // Rejection sampling: try natural cascades up to 50 times; reject any
    // that exceed the budget and keep retrying.
    for (int attempt = 0; attempt < 50; attempt++) {
      final initialGrid = _generateWinningGrid(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      final simResult = _runSimulation(initialGrid, weights, betAmount,
          safeRefill: false, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
    }

    // Fallback: safe-refill (single-cascade only) keeps the win bounded.
    int fallbackAttempts = 0;
    while (fallbackAttempts++ < 100) {
      final fallbackGrid = _generateWinningGrid(weights, mode, spinMaxMults, forceScatters: triggersFs, isFreeSpins: isFreeSpins);
      final simResult = _runSimulation(fallbackGrid, weights, betAmount,
          safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins, anteBet: anteBet, buyFs: buyFs);
      if (simResult.totalWin > 0 && simResult.totalWin <= maxAllowedWin) {
        return simResult;
      }
    }

    // Hard fail-safe: if even the bounded fallback can't fit, return a safe grid.
    return _runSimulation(_generateSafeGrid(weights, spinMaxMults, isFreeSpins: isFreeSpins), weights, betAmount,
        safeRefill: true, maxMults: spinMaxMults, isFreeSpins: isFreeSpins);
  }

  /// Runs the full tumble loop in memory and returns the final SpinResult.
  static SpinResult _runSimulation(
    List<List<String>> startGrid,
    List<_WeightedSymbol> weights,
    double betAmount,
    {required bool safeRefill,
    required int maxMults,
    bool isFreeSpins = false,
    bool anteBet = false,
    bool buyFs = false}
  ) {
    final grid = _deepCopy(startGrid);

    final scatterSymbol = SymbolRegistry.all.firstWhere((s) => s.isScatter);
    final scatterPath = scatterSymbol.assetPath;

    double totalBaseWin = 0;
    int tumbleCount = 0;
    final tumbles = <TumbleStep>[];
    final winningPositions = <int>{};

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

      if (winners.isEmpty) break;

      final winnersSet = winners.toSet();
      for (int c = 0; c < columns; c++) {
        for (int r = 0; r < rows; r++) {
          if (winnersSet.contains(grid[c][r])) {
            winningPositions.add(c * 100 + r);
          }
        }
      }

      totalBaseWin += tumbleWin;
      tumbleCount++;

      final winningPaths = winners.toSet();
      _removeSymbols(grid, winners);
      _applyGravity(grid);

      if (safeRefill) {
        _fillEmptySafe(grid, weights, maxMults, isFreeSpins: isFreeSpins);
      } else {
        // Forced chain seeds 8+ of one symbol so the next tumble has a
        // guaranteed winner — natural refill rarely reaches that threshold.
        final chainProb = isFreeSpins
            ? _fsForcedChainProb(tumbleCount)
            : _chainProbBase;
        if (_rng.nextDouble() < chainProb) {
          _fillEmptyForcedChain(grid, weights, maxMults, isFreeSpins: isFreeSpins);
        } else {
          _fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins);
        }
      }

      tumbles.add(TumbleStep(
        winningPaths: winningPaths,
        gridAfter: _deepCopy(grid),
        winAmount: tumbleWin,
      ));
    }

    final rawMultiplier = _collectMultipliers(grid);
    // Mutually-exclusive FS multiplier scaling: ante scales down, buy scales
    // up, farm uses the raw value. Floor at 1.0 so scaling never turns a
    // winning multiplier into a no-boost result.
    double finalMultiplier;
    if (isFreeSpins && rawMultiplier > 1.0) {
      if (anteBet) {
        finalMultiplier = max(1.0, rawMultiplier * _anteFsMultiplierScale);
      } else if (buyFs) {
        finalMultiplier = max(1.0, rawMultiplier * _buyFsMultiplierScale);
      } else {
        finalMultiplier = rawMultiplier;
      }
    } else {
      finalMultiplier = rawMultiplier;
    }

    // Scatters are evaluated after all tumbles so cascades can build them up.
    // Asymmetric: 4+ scatters trigger from base, 3+ retrigger from inside FS.
    final scatterCount = _countAsset(grid, scatterPath);
    final scatterPayout = scatterSymbol.getScatterPayoutForCount(scatterCount) * betAmount;
    final freeSpinsTriggered = isFreeSpins ? (scatterCount >= 3) : (scatterCount >= 4);

    double totalWin = (totalBaseWin * max(1.0, finalMultiplier)) + scatterPayout;

    return SpinResult(
      initialGrid: _deepCopy(startGrid),
      tumbles: tumbles,
      totalWin: totalWin,
      tumbleCount: tumbleCount,
      freeSpinsTriggered: freeSpinsTriggered,
      isRetrigger: isFreeSpins && freeSpinsTriggered,
      scatterCount: scatterCount,
      scatterPayout: scatterPayout,
      winningPositions: winningPositions,
    );
  }

  /// Generates a grid where no regular symbol reaches 8 and scatters are capped.
  static List<List<String>> _generateSafeGrid(List<_WeightedSymbol> weights, int maxMults, {bool isFreeSpins = false}) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};

    return List.generate(columns, (_) {
      return List.generate(rows, (_) {
        return _pickSafe(weights, totalW, counts, maxRegular: 7, maxScatter: isFreeSpins ? 2 : 3, maxMultiplier: maxMults);
      });
    });
  }

  /// Generates a grid with exactly 8–12 of one symbol, rest safe.
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
    if (forceScatters) {
      scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;

      final r = _rng.nextDouble();
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

  /// Weighted-random symbol pick that enforces per-grid caps.
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
    // Hard fallback — return a guaranteed regular so we never silently leak
    // a scatter or multiplier into a "safe" cell.
    return SymbolRegistry.all.firstWhere((s) => s.isRegular).assetPath;
  }

  /// Picks the winning symbol on a winning spin, weighted by mode tier.
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

  /// Picks the winning-symbol count (8–12) biased toward the minimum payout.
  static int _pickWinCount() {
    final r = _rng.nextDouble();
    if (r < 0.75) return 8;
    if (r < 0.90) return 9;
    if (r < 0.96) return 10;
    if (r < 0.99) return 11;
    return 12;
  }

  /// Per-spin cap on multiplier-symbol count. FS allows 1–6, base 2–6.
  static int _rollMaxMultipliers({bool isFreeSpins = false}) {
    final r = _rng.nextDouble();
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

  /// Builds the per-spin weighted symbol pool. FS amplifies multiplier
  /// weights via the per-mode boost so the FS round delivers its premium feel.
  static List<_WeightedSymbol> _buildAdjustedWeights(GameMode mode, bool isFreeSpins) {
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
        _WeightedSymbol(
          sym.assetPath,
          sym.baseWeight * (multipliers[sym.tier] ?? 1.0) * (sym.isMultiplier ? fsMultiplierBoost : 1.0),
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

  /// Refills empty cells with 8–10 copies of one regular symbol so the next
  /// tumble has a guaranteed cluster. Target picked from low-tier (frequent,
  /// low-payout) symbols to bound the RTP impact of forced chains.
  static void _fillEmptyForcedChain(
    List<List<String>> grid,
    List<_WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final regulars = SymbolRegistry.all.where((s) => s.isRegular).toList();
    double totalW = 0;
    for (final s in regulars) {
      totalW += _winSymbolWeights[s.id] ?? 1.0;
    }
    double roll = _rng.nextDouble() * totalW;
    SlotSymbol target = regulars.first;
    for (final s in regulars) {
      roll -= _winSymbolWeights[s.id] ?? 1.0;
      if (roll <= 0) {
        target = s;
        break;
      }
    }
    final targetPath = target.assetPath;

    final emptyPositions = <List<int>>[];
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) emptyPositions.add([c, r]);
      }
    }

    int existing = 0;
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r] == targetPath) existing++;
      }
    }

    // 8 guarantees a chain; 9–10 vary the payout magnitude.
    final desiredTotal = 8 + _rng.nextInt(3);
    final toPlace = (desiredTotal - existing).clamp(0, emptyPositions.length);

    emptyPositions.shuffle(_rng);
    for (int i = 0; i < toPlace; i++) {
      final pos = emptyPositions[i];
      grid[pos[0]][pos[1]] = targetPath;
    }

    _fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins);
  }

  /// Refills empty cells while capping regular-symbol counts to prevent any
  /// new winning cluster from forming.
  static void _fillEmptySafe(List<List<String>> grid, List<_WeightedSymbol> weights, int maxMults, {bool isFreeSpins = false}) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};
    int totalMults = 0;

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

  /// Refills empty cells with weighted random picks. Allows new cascades to
  /// form naturally; multiplier and scatter caps still respected.
  static void _fillEmptyRandom(
    List<List<String>> grid,
    List<_WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);

    int totalMults = 0;
    int totalScatters = 0;
    final scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;

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
          // Hard fallback — never leak a scatter or multiplier into a cell
          // that violated its cap during all 20 retries.
          if (grid[c][r].isEmpty) {
            grid[c][r] = SymbolRegistry.all.firstWhere((s) => s.isRegular).assetPath;
          }
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
