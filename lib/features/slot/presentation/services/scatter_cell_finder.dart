import '../../domain/models/symbol_registry.dart';
import '../models/scatter_cell.dart';

class ScatterCellFinder {
  const ScatterCellFinder._();

  static List<ScatterCell> findInGrid(List<List<String>> grid) {
    final scatterPath = SymbolRegistry.all
        .firstWhere((symbol) => symbol.isScatter)
        .assetPath;
    final cells = <ScatterCell>[];

    for (var col = 0; col < grid.length; col++) {
      final column = grid[col];
      for (var row = 0; row < column.length; row++) {
        if (column[row] == scatterPath) {
          cells.add(ScatterCell(column: col, row: row));
        }
      }
    }

    return cells;
  }
}
