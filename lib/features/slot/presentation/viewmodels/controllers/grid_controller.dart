import 'package:flutter/foundation.dart';

import '../../../domain/engine/slot_engine.dart';
import '../../../domain/models/cluster_win.dart';

/// Owns the symbol grid + cascade-tumble visuals (fadingPaths,
/// activeExplosions, winningPositions). Cascade-step mutators notify
/// listeners; spin-boundary helpers like [capturePreviousGrid] mutate
/// silently when the change is part of a larger transaction.
class GridController extends ChangeNotifier {
  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  late List<List<String>> _grid;
  List<List<String>> _previousGrid = [];
  Set<String> _fadingPaths = const {};
  List<ClusterWin> _activeExplosions = const [];
  Set<int> _winningPositions = {};
  Set<int> _clearedPositions = const {};

  GridController(List<List<String>> initialGrid) {
    _grid = initialGrid;
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  List<List<String>> get grid => _grid;
  List<List<String>> get previousGrid => _previousGrid;
  Set<String> get fadingPaths => _fadingPaths;
  List<ClusterWin> get activeExplosions => _activeExplosions;
  Set<int> get winningPositions => _winningPositions;

  /// Cells that should render as empty even though the grid still
  /// holds a symbol there. Used by the win-presentation layer to
  /// remove a multiplier symbol the moment its asset has lifted off
  /// the cell, so the cell reads as "consumed". Encoded as
  /// `column * 100 + row`.
  Set<int> get clearedPositions => _clearedPositions;

  /// Snapshots the current grid so reels can animate from the previous
  /// layout to the next one. Mutates silently — paired with [setGrid]
  /// inside the same spin transaction.
  void capturePreviousGrid() {
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  void resetForNewSpin() {
    _fadingPaths = const {};
    _activeExplosions = const [];
    _winningPositions = {};
    _clearedPositions = const {};
    notifyListeners();
  }

  /// Marks a single (column, row) as cleared so the slot reel renders
  /// it empty for the rest of the current spin. Called from the win
  /// presentation layer when a multiplier asset lifts off its cell.
  void clearMultiplierPosition(int column, int row) {
    final key = column * 100 + row;
    if (_clearedPositions.contains(key)) return;
    _clearedPositions = {..._clearedPositions, key};
    notifyListeners();
  }

  void setGrid(List<List<String>> grid) {
    _grid = grid;
    notifyListeners();
  }

  /// Phase 1 of a tumble step: stages fading cells + cluster explosions.
  void startTumble({
    required Set<String> fadingPaths,
    required List<ClusterWin> activeExplosions,
  }) {
    _fadingPaths = fadingPaths;
    _activeExplosions = activeExplosions;
    notifyListeners();
  }

  /// Phase 2 of a tumble step: drops the new grid in and clears fade markers.
  void endTumble({required List<List<String>> newGrid}) {
    _grid = newGrid;
    _fadingPaths = const {};
    _activeExplosions = const [];
    notifyListeners();
  }

  void setWinningPositions(Set<int> positions) {
    _winningPositions = positions;
    notifyListeners();
  }
}
