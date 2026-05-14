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

  /// Cells that should render as consumed even though the grid still
  /// holds a multiplier symbol there. The reel shows the colorful
  /// residue in these cells until the next drop-out completes.
  /// Encoded as `column * 100 + row`.
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
    // Residues are NOT cleared here on purpose — keeping them lets the
    // drop-out frames render dust where the multiplier exploded last
    // round (instead of replaying the bomb sprite). The reels reset
    // residues themselves the moment they start dropping the new
    // symbols in (see `onDropInStart`), so static-state never flashes
    // dust before the new symbol appears.
    notifyListeners();
  }

  /// Marks a single (column, row) as consumed so the slot reel renders
  /// residue for the rest of the current spin. Called from the win
  /// presentation layer when a multiplier asset lifts off its cell.
  void clearMultiplierPosition(int column, int row) {
    final key = column * 100 + row;
    if (_clearedPositions.contains(key)) return;
    _clearedPositions = {..._clearedPositions, key};
    notifyListeners();
  }

  void clearMultiplierResidues() {
    if (_clearedPositions.isEmpty) return;
    _clearedPositions = const {};
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
