import 'dart:math';

import '../models/spin_result.dart';
import '../models/symbol_registry.dart';
import '../models/tumble_step.dart';
import 'chain_forcer.dart';
import 'engine_runtime.dart';
import 'multiplier_collector.dart';
import 'rtp_config.dart';
import 'weighted_random.dart';

/// Runs the cascade tumble loop and produces the final [SpinResult].
class TumbleSimulator {
  TumbleSimulator._();

  static SpinResult run(
    List<List<String>> startGrid,
    List<WeightedSymbol> weights,
    double betAmount, {
    required bool safeRefill,
    required int maxMults,
    bool isFreeSpins = false,
    bool anteBet = false,
    bool buyFs = false,
  }) {
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
      for (int c = 0; c < kEngineColumns; c++) {
        for (int r = 0; r < kEngineRows; r++) {
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
        ChainForcer.fillEmptySafe(grid, weights, maxMults, isFreeSpins: isFreeSpins);
      } else {
        // Forced chain seeds 8+ of one symbol so the next tumble has a
        // guaranteed winner — natural refill rarely reaches that threshold.
        final chainProb = isFreeSpins
            ? ChainForcer.fsForcedChainProb(tumbleCount)
            : RtpConfig.chainProbBase;
        if (engineRng.nextDouble() < chainProb) {
          ChainForcer.fillEmptyForcedChain(grid, weights, maxMults, isFreeSpins: isFreeSpins);
        } else {
          ChainForcer.fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins);
        }
      }

      tumbles.add(TumbleStep(
        winningPaths: winningPaths,
        gridAfter: _deepCopy(grid),
        winAmount: tumbleWin,
      ));
    }

    final rawMultiplier = MultiplierCollector.rawSum(grid);
    final finalMultiplier = MultiplierCollector.finalize(
      rawMultiplier,
      isFreeSpins: isFreeSpins,
      anteBet: anteBet,
      buyFs: buyFs,
    );

    // Scatters are evaluated after all tumbles so cascades can build them up.
    // Asymmetric: 4+ scatters trigger from base, 3+ retrigger from inside FS.
    final scatterCount = _countAsset(grid, scatterPath);
    final scatterPayout = scatterSymbol.getScatterPayoutForCount(scatterCount) * betAmount;
    final freeSpinsTriggered = isFreeSpins ? (scatterCount >= 3) : (scatterCount >= 4);

    final totalWin = (totalBaseWin * max(1.0, finalMultiplier)) + scatterPayout;

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

  // ── Grid utilities ──

  static Map<String, int> _countRegularSymbols(List<List<String>> grid) {
    final counts = <String, int>{};
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
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
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r] == assetPath) count++;
      }
    }
    return count;
  }

  static void _removeSymbols(List<List<String>> grid, List<String> winnerPaths) {
    final winSet = winnerPaths.toSet();
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (winSet.contains(grid[c][r])) grid[c][r] = '';
      }
    }
  }

  static void _applyGravity(List<List<String>> grid) {
    for (int c = 0; c < kEngineColumns; c++) {
      final filled = <String>[];
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r].isNotEmpty) filled.add(grid[c][r]);
      }
      final empty = kEngineRows - filled.length;
      for (int r = 0; r < kEngineRows; r++) {
        grid[c][r] = r < empty ? '' : filled[r - empty];
      }
    }
  }

  static List<List<String>> _deepCopy(List<List<String>> grid) {
    return List.generate(kEngineColumns, (c) => List.from(grid[c]));
  }
}
