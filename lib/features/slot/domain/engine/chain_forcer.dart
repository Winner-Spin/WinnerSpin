import '../models/slot_symbol.dart';
import '../models/symbol_registry.dart';
import 'engine_runtime.dart';
import 'grid_generator.dart';
import 'rtp_config.dart';
import 'weighted_random.dart';

/// Cascade refill helpers — random fill, safe (no new wins) fill, and
/// forced-chain fill that seeds a guaranteed next-tumble cluster.
class ChainForcer {
  ChainForcer._();

  /// FS forced-chain probability tapered by tumble depth — keeps the long
  /// tail (5+ tumbles) under ~5% of wins while letting natural cascades
  /// hit industry-standard depth distribution.
  static double fsForcedChainProb(int tumblesSoFar) {
    if (tumblesSoFar <= 1) return 0.55;
    if (tumblesSoFar == 2) return 0.42;
    if (tumblesSoFar == 3) return 0.30;
    if (tumblesSoFar == 4) return 0.18;
    return 0.08;
  }

  /// Refills empty cells with 8–10 copies of one regular symbol so the next
  /// tumble has a guaranteed cluster. Target picked from low-tier (frequent,
  /// low-payout) symbols to bound the RTP impact of forced chains.
  static void fillEmptyForcedChain(
    List<List<String>> grid,
    List<WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final regulars = SymbolRegistry.all.where((s) => s.isRegular).toList();
    double totalW = 0;
    for (final s in regulars) {
      totalW += RtpConfig.winSymbolWeights[s.id] ?? 1.0;
    }
    double roll = engineRng.nextDouble() * totalW;
    SlotSymbol target = regulars.first;
    for (final s in regulars) {
      roll -= RtpConfig.winSymbolWeights[s.id] ?? 1.0;
      if (roll <= 0) {
        target = s;
        break;
      }
    }
    final targetPath = target.assetPath;

    final emptyPositions = <List<int>>[];
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r].isEmpty) emptyPositions.add([c, r]);
      }
    }

    int existing = 0;
    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r] == targetPath) existing++;
      }
    }

    // 8 guarantees a chain; 9–10 vary the payout magnitude.
    final desiredTotal = 8 + engineRng.nextInt(3);
    final toPlace = (desiredTotal - existing).clamp(0, emptyPositions.length);

    emptyPositions.shuffle(engineRng);
    for (int i = 0; i < toPlace; i++) {
      final pos = emptyPositions[i];
      grid[pos[0]][pos[1]] = targetPath;
    }

    fillEmptyRandom(grid, weights, maxMults, isFreeSpins: isFreeSpins);
  }

  /// Refills empty cells while capping regular-symbol counts to prevent any
  /// new winning cluster from forming.
  static void fillEmptySafe(
    List<List<String>> grid,
    List<WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);
    final counts = <String, int>{};
    int totalMults = 0;

    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          counts[path] = (counts[path] ?? 0) + 1;
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isMultiplier) totalMults++;
        }
      }
    }
    counts['TOTAL_MULTIPLIERS'] = totalMults;

    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r].isEmpty) {
          grid[c][r] = GridGenerator.pickSafe(
            weights,
            totalW,
            counts,
            maxRegular: 7,
            maxScatter: isFreeSpins ? 2 : 3,
            maxMultiplier: maxMults,
          );
        }
      }
    }
  }

  /// Refills empty cells with weighted random picks. Allows new cascades to
  /// form naturally; multiplier and scatter caps still respected.
  static void fillEmptyRandom(
    List<List<String>> grid,
    List<WeightedSymbol> weights,
    int maxMults, {
    bool isFreeSpins = false,
  }) {
    final totalW = weights.fold<double>(0, (s, w) => s + w.weight);

    int totalMults = 0;
    int totalScatters = 0;
    final scatterPath = SymbolRegistry.all.firstWhere((s) => s.isScatter).assetPath;

    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        final path = grid[c][r];
        if (path.isNotEmpty) {
          final sym = SymbolRegistry.byPath(path);
          if (sym != null && sym.isMultiplier) totalMults++;
          if (path == scatterPath) totalScatters++;
        }
      }
    }

    final maxScatter = isFreeSpins ? 2 : 3;

    for (int c = 0; c < kEngineColumns; c++) {
      for (int r = 0; r < kEngineRows; r++) {
        if (grid[c][r].isEmpty) {
          for (int attempt = 0; attempt < 20; attempt++) {
            final picked = WeightedRandom.pick(weights, totalW);
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

}
