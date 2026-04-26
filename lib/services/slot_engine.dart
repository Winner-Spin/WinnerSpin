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
  /// v5 high-vol revised: hit rates restored to v4 levels after the first
  /// 10M run showed FS-round payout averaging ~33x bet (not the 96x we
  /// hoped for) due to per-spin multiplier capping. Base game must keep
  /// its v4 RTP contribution to land total RTP near 96.5%.
  static const Map<GameMode, double> _hitRate = {
    GameMode.recovery: 0.30,
    GameMode.tight: 0.22,
    GameMode.normal: 0.30,    // restored to v4 (was v5: 0.25)
    GameMode.generous: 0.38,
    GameMode.jackpot: 0.45,
  };

  /// Probability of naturally triggering Free Spins per game mode (base game).
  /// v5 high-vol single pipeline: rarer FS triggers paired with a 3x FS
  /// multiplier boost. Mirrors authentic Sweet Bonanza math — base game is
  /// meant to feel "grindy", real wins happen inside the FS round.
  /// Doubled by Ante Bet at the spin call site.
  /// Calibration journey:
  ///   0.004 normal → RTP 91.5% (-5.0)
  ///   0.006 normal → RTP 97.46 (+0.96)
  ///   slope ≈ 3 RTP points / 0.001 trigger → 0.0057 lands ~96.5
  /// FS trigger rate — restored to v5 baseline (0.0033 normal). FS round
  /// payout is now bounded by a tight multiplier cap (avg ~4.4), so each
  /// round pays ~95x bet — perfect alignment with the 100x buy bonus price
  /// (buy RTP ≈ 95%, industry-standard). FS contribution = 0.0033 × 95.
  static const Map<GameMode, double> _fsTriggerRate = {
    GameMode.recovery: 0.0004,    // 0.04%
    GameMode.tight: 0.001,        // 0.1%
    GameMode.normal: 0.00335,     // 0.335% (~1 per 299 spins) — micro-tuned
    GameMode.generous: 0.0067,    // 0.67%
    GameMode.jackpot: 0.03,       // 3.0% — preserved as the "show" jackpot rate
  };

  /// Probability of RE-TRIGGERING Free Spins while ALREADY inside a FS round.
  /// v5 high-vol: halved vs v4 because each FS round already pays ~96x bet
  /// thanks to the 3x multiplier boost — long retriggered runs would push
  /// per-round payout into 200x+ territory and inflate RTP past target.
  static const Map<GameMode, double> _fsRetriggerRate = {
    GameMode.recovery: 0.0,
    GameMode.tight: 0.01,       // v5: 0.02 -> 0.01
    GameMode.normal: 0.02,      // v5: 0.04 -> 0.02
    GameMode.generous: 0.03,    // v5: 0.06 -> 0.03
    GameMode.jackpot: 0.05,     // v5: 0.08 -> 0.05
  };

  /// Estimated AVERAGE payout per single Free Spin (in xBet) per mode.
  /// Used by the Virtual Cost guard to forecast the future debt of awarding
  /// a FS round BEFORE the engine commits to it.
  /// v5 high-vol: ~2x bumped because the 3x multiplier boost makes FS spins
  /// pay much more on average. A 10-spin round in normal mode now averages
  /// ~96x bet (vs ~28x in v4). These are coarse estimates — the Virtual
  /// Cost guard intentionally errs on the side of caution.
  static const Map<GameMode, double> _fsAvgPayoutPerSpin = {
    GameMode.recovery: 4.0,     // v5: 2.0 -> 4.0
    GameMode.tight: 6.0,        // v5: 3.0 -> 6.0
    GameMode.normal: 10.0,      // v5: 5.0 -> 10.0 (~96x / 10 spins)
    GameMode.generous: 15.0,    // v5: 8.0 -> 15.0
    GameMode.jackpot: 22.0,     // v5: 12.0 -> 22.0
  };

  /// Safety multiplier on top of expected FS cost (natural triggers).
  /// 2.0 = "only commit to FS if pool can cover 2x the average cost."
  static const double _fsSafetyFactor = 2.0;

  /// Stricter safety multiplier for player-initiated buys.
  /// Buys are user-driven and clustered (whales repeat-buying), so the pool
  /// needs more headroom than for naturally-triggered FS rounds.
  static const double _buyFsSafetyFactor = 3.0;

  /// Spins awarded per FS event.
  static const int _fsAwardInitial = 10;
  static const int _fsAwardRetrigger = 5;

  /// Cost of the Buy Free Spins feature, in multiples of base bet.
  /// Industry standard for Sweet Bonanza-style slots is 100x.
  static const double buyFeaturePriceMultiplier = 100.0;

  /// Probability of FORCING a chain after each successful tumble.
  /// When triggered, the refill seeds 8-10 of a chain-target symbol so the
  /// next iteration of the tumble loop finds a guaranteed winner. This is
  /// the engineering trick that lets natural cascade chains reach Sweet
  /// Bonanza frequencies — pure random refill caps chain rate at ~5-10%
  /// because reaching 8+ of one symbol post-refill is statistically rare.
  ///
  /// Conservative tuning: chains compound (each tumble can re-trigger), so
  /// the per-tumble probability is kept low to avoid runaway 10+ tumble
  /// chains that explode RTP. Combined with natural chain rate, effective
  /// per-tumble continuation runs slightly above natural.
  ///
  /// Base game: 0% forced — natural cascade rate (~45% per tumble) already
  /// matches Sweet Bonanza targets (1: 49%, 2: 29%, 3: 14%, 4: 5% of wins).
  /// Forcing chains here over-shoots Sweet Bonanza distribution.
  static const double _chainProbBase = 0.0;

  /// FS forced chain probability TAPERS BY TUMBLE DEPTH.
  /// Schedule designed to mirror Sweet Bonanza's decreasing tumble-depth
  /// distribution: lots of 1-tumble wins, decreasing through 2-3-4, sharp
  /// drop after 4 to keep the long tail (5+) under ~5% of wins.
  /// Natural FS chain rate is ~10%; effective continuation = forced + natural.
  static double _fsForcedChainProb(int tumblesSoFar) {
    if (tumblesSoFar <= 1) return 0.55;
    if (tumblesSoFar == 2) return 0.42;
    if (tumblesSoFar == 3) return 0.30;
    if (tumblesSoFar == 4) return 0.18;
    return 0.08; // 5+ tumbles: gentle taper instead of cliff
  }

  /// Estimated total cost of awarding a FS round (in xBet).
  /// = scatter reward (typical 4-scatter case) + (#spins × avg payout per spin)
  static double _expectedFsCostMultiplier(GameMode mode, bool isRetrigger) {
    // Fallback matches the v5 normal-mode estimate so an unrecognised mode
    // doesn't quietly underestimate FS cost (the v4 fallback was 5.0).
    final perSpin = _fsAvgPayoutPerSpin[mode] ?? 10.0;
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

  /// Stricter Virtual Cost guard for player-initiated buy FS.
  /// Returns true if the pool can safely accommodate a 10-spin FS round
  /// purchased at [buyFeaturePriceMultiplier] × bet, with [_buyFsSafetyFactor]
  /// times the expected cost as a liquidity cushion.
  ///
  /// Note: the buy FEE itself (100×bet) is incoming pool revenue, but it's
  /// not yet credited at the moment of the call — so the guard checks the
  /// post-fee balance.
  static bool canAffordBuyFs(PoolState pool, double betAmount) {
    if (pool.totalSpins < 50) return true;
    final mode = pool.currentMode;
    final expectedCost = _expectedFsCostMultiplier(mode, false) * betAmount;
    final buyFee = betAmount * buyFeaturePriceMultiplier;
    final virtualCost = expectedCost * _buyFsSafetyFactor;
    // Pool will receive the buy fee; check post-fee headroom.
    return (pool.poolBalance + buyFee) >= virtualCost;
  }

  /// Max win multiplier allowed per game mode (Protects RTP).
  /// Dynamically limits based on the current pool balance to prevent bankruptcy.
  ///
  /// FS-aware: free spins use looser ceilings so chain-boosted natural
  /// cascades aren't cut short by rejection sampling. Without this fork,
  /// multi-cascade chains in FS rarely survive (they exceed the base 2500x
  /// cap, get rejected, and fall back to single-cascade safeRefill output).
  static double _getMaxWinMultiplier(
    GameMode mode,
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
  }) {
    // Determine the absolute ceiling based on the mode + FS state
    double modeCeiling;
    if (isFreeSpins) {
      // FS ceilings — Sweet Bonanza paritesi (~3x base ceilings).
      // Goal: let 4-5-cascade chains land without rejection.
      switch (mode) {
        case GameMode.recovery: modeCeiling = 60.0; break;
        case GameMode.tight: modeCeiling = 400.0; break;
        case GameMode.normal: modeCeiling = 8000.0; break;
        case GameMode.generous: modeCeiling = 15000.0; break;
        case GameMode.jackpot: modeCeiling = 21100.0; break;  // Sweet Bonanza max-win standard
      }
    } else {
      // Base game ceilings — KEPT AT v5 ORIGINAL VALUES.
      // Base cascade distribution naturally matches Sweet Bonanza targets
      // (1: 49%, 2: 29%, 3: 14%, 4: 5% of wins) without intervention.
      // Raising base caps lets natural cascades survive rejection more often,
      // which makes the distribution chain-heavier than Sweet Bonanza.
      switch (mode) {
        case GameMode.recovery: modeCeiling = 30.0; break;
        case GameMode.tight: modeCeiling = 100.0; break;
        case GameMode.normal: modeCeiling = 2500.0; break;
        case GameMode.generous: modeCeiling = 5000.0; break;
        case GameMode.jackpot: modeCeiling = 10000.0; break;
      }
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

  static SpinResult spin(
    PoolState pool,
    double betAmount, {
    bool isFreeSpins = false,
    bool anteBet = false,
  }) {
    final mode = pool.currentMode;
    final weights = _buildAdjustedWeights(mode, isFreeSpins);
    final spinMaxMults = _rollMaxMultipliers(isFreeSpins: isFreeSpins);

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

    final maxAllowedWin =
        _getMaxWinMultiplier(mode, pool, betAmount, isFreeSpins: isFreeSpins) * betAmount;




    // ─── FREE SPINS TRIGGER DECISION (with Virtual Cost guard) ───
    //
    // Two distinct paths:
    //   1. Base game  → may trigger initial FS round (+10 spins)
    //   2. Inside FS  → may RE-trigger (+5 spins)
    //
    // BOTH paths go through the Virtual Cost guard, which estimates the
    // total future debt of the awarded FS round (scatter payout + N spins ×
    // average payout per spin) and refuses to commit if the pool can't
    // safely cover it. See [_canAffordFsRound] for the math.
    final bool isRetriggerAttempt = isFreeSpins;
    final double baseFsRate = isRetriggerAttempt
        ? (_fsRetriggerRate[mode] ?? 0.0)
        : (_fsTriggerRate[mode] ?? 0.0);
    // Ante Bet (1.25× cost) doubles the FS trigger rate for THIS spin.
    // Only applies to base spins; in-FS retrigger rate is untouched.
    final double fsRate = (anteBet && !isRetriggerAttempt)
        ? baseFsRate * 2.0
        : baseFsRate;
    final bool canAffordFs =
        _canAffordFsRound(pool, betAmount, mode, isRetriggerAttempt) &&
            maxAllowedWin >= (3.25 * betAmount); // also keep per-spin floor
    final bool triggersFs = canAffordFs && (_rng.nextDouble() < fsRate);





    // 1. Decide win or loss based on hit rate.
    // Fallback matches the v5 normal-mode rate so an unrecognised mode
    // doesn't quietly inflate hit rate (the v4 fallback was 0.40).
    final shouldWin = triggersFs || _rng.nextDouble() < (_hitRate[mode] ?? 0.30);

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
        // Forced chain: a deliberate engineering trick to reach Sweet Bonanza
        // chain depths. Pure random refill struggles to produce 8+ of one
        // symbol post-cascade (mathematically rare), so we explicitly seed
        // a chain-eligible refill with [_chainProbBase]/[_chainProbFs]
        // probability. Otherwise fall back to plain random refill.
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
    // Last-resort fallback: every regular is at its per-grid cap (extremely
    // rare — mathematically requires 63+ regular slots on a 30-cell grid).
    // Return a GUARANTEED regular symbol rather than weights.first, which
    // could be a multiplier or scatter and would silently corrupt the
    // calibrated win/scatter math.
    return SymbolRegistry.all.firstWhere((s) => s.isRegular).assetPath;
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

  /// Per-spin cap on the number of multiplier symbols allowed on the grid.
  /// v5c: FS cap raised again — average ~4.75 was still binding hard at
  /// boost 60-80, capping FS round avg at ~60x bet. New distribution
  /// averages ~7.0 multipliers/spin to push avg FS round into the 85-95x
  /// band the user targets.
  static int _rollMaxMultipliers({bool isFreeSpins = false}) {
    final r = _rng.nextDouble();
    if (isFreeSpins) {
      //   3: 45%   4: 40%   5: 12%   6: 3%
      //   avg ~3.73 multipliers/spin — pulled down so avg FS round drops
      //   from 101.3x → ~96x (buy bonus RTP 96/100 = 96%, SB-grade).
      if (r < 0.45) return 3;
      if (r < 0.85) return 4;
      if (r < 0.97) return 5;
      return 6;
    }
    // Base game (v4 distribution preserved):
    //   2: 90%   3: 7%   4: 2%   5: 0.8%   6: 0.2%
    if (r < 0.90) return 2;
    if (r < 0.97) return 3;
    if (r < 0.99) return 4;
    if (r < 0.998) return 5;
    return 6;
  }

  // ─── WEIGHTED RANDOM ──────────────────────────────────────────

  static List<_WeightedSymbol> _buildAdjustedWeights(GameMode mode, bool isFreeSpins) {
    final multipliers = SymbolRegistry.weightMultipliers[mode]!;
    
    // Dynamically adjust Free Spins multiplier boost based on game mode.
    // v5 high-vol single pipeline: ~3x scale-up vs v4. With rarer FS triggers
    // (~1 per 250 spins in normal) and an avg FS round target of ~96x bet,
    // FS becomes the central "show" of the game while base spins are grindy.
    double fsMultiplierBoost = 1.0;
    if (isFreeSpins) {
      // v5d: cut by ~25% across all modes to compensate for cascade tapering
      // (chains pushed avg FS round from 98x to 191x; this cut targets ~144x).
      switch (mode) {
        case GameMode.recovery: fsMultiplierBoost = 13.5; break;
        case GameMode.tight: fsMultiplierBoost = 27.0; break;
        case GameMode.normal: fsMultiplierBoost = 60.0; break;
        case GameMode.generous: fsMultiplierBoost = 85.0; break;
        case GameMode.jackpot: fsMultiplierBoost = 109.0; break;
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

  /// Refills empty spaces with a FORCED-CHAIN seed: places 8-10 copies of a
  /// chain-target symbol into the empty cells (low-tier biased to control
  /// payout impact), then fills the remainder via [_fillEmptyRandom].
  ///
  /// The next iteration of the tumble loop will detect the seeded cluster
  /// and count it as a chain — this is how the engine reaches Sweet Bonanza
  /// chain depths despite a small (6×5) grid where natural chains are rare.
  static void _fillEmptyForcedChain(
    List<List<String>> grid,
    List<_WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    // Pick chain-target symbol — biased by _winSymbolWeights so low-tier
    // (high-frequency, low-payout) symbols dominate. This caps the RTP
    // impact of forced chains.
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

    // Count empty cell positions
    final emptyPositions = <List<int>>[];
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r].isEmpty) emptyPositions.add([c, r]);
      }
    }

    // Count existing target on grid (after gravity)
    int existing = 0;
    for (int c = 0; c < columns; c++) {
      for (int r = 0; r < rows; r++) {
        if (grid[c][r] == targetPath) existing++;
      }
    }

    // Aim for 8-10 total of the target on the grid post-refill.
    // 8 = guaranteed chain; 9-10 keep variety in payout amounts.
    final desiredTotal = 8 + _rng.nextInt(3); // 8, 9, or 10
    final toPlace = (desiredTotal - existing).clamp(0, emptyPositions.length);

    // Shuffle empty positions to scatter the target across columns
    emptyPositions.shuffle(_rng);
    for (int i = 0; i < toPlace; i++) {
      final pos = emptyPositions[i];
      grid[pos[0]][pos[1]] = targetPath;
    }

    // Fill the remaining empty cells via plain random refill
    _fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins);
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

  /// Refills empty spaces randomly based on weights (can create new cascades).
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
          // Last-resort fallback: 20 random picks all violated a cap.
          // Return a GUARANTEED regular symbol — see _pickSafe for the
          // same reasoning (avoid silent multiplier/scatter leak).
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
