import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/tumble_simulator.dart';
import 'package:winner_spin/features/slot/domain/engine/multiplier_collector.dart';
import 'package:winner_spin/features/slot/domain/engine/weighted_random.dart';
import 'package:winner_spin/features/slot/domain/enums/game_mode.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';

void main() {
  test('visible multiplier total is used unchanged', () {
    const visibleTotal = 2.0;

    expect(MultiplierCollector.finalize(visibleTotal), visibleTotal);
  });

  test('2x symbol win with a visible 5x multiplier pays exactly 10x', () {
    final banana = SymbolRegistry.all.firstWhere(
      (symbol) => symbol.id == 'banana',
    );
    final multiplier = SymbolRegistry.all.firstWhere(
      (symbol) => symbol.id == 'multi_5x',
    );
    final fillers = SymbolRegistry.all
        .where((symbol) => symbol.isRegular && symbol.id != banana.id)
        .map((symbol) => symbol.assetPath)
        .toList();
    final cells = <String>[
      ...List.filled(12, banana.assetPath),
      multiplier.assetPath,
      for (int i = 0; i < 17; i++) fillers[i % fillers.length],
    ];
    final grid = List.generate(
      6,
      (column) => List.generate(5, (row) => cells[column * 5 + row]),
    );

    final result = TumbleSimulator.run(
      grid,
      WeightedRandom.buildAdjustedWeights(GameMode.normal, false),
      1,
      safeRefill: true,
      maxMults: 1,
    );

    expect(result.baseWin, 2);
    expect(result.totalWin, 10);
  });
}
