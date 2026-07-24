import 'package:flutter/foundation.dart';

import '../../../domain/engine/slot_engine.dart';
import '../../../domain/models/cluster_win.dart';

class GridController extends ChangeNotifier {
  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  late List<List<String>> _grid;
  List<List<String>> _previousGrid = [];
  Set<String> _fadingPaths = const {};
  List<ClusterWin> _activeExplosions = const [];
  Set<int> _winningPositions = {};
  Set<int> _clearedPositions = const {};
  Set<int> _multiplierResiduePositions = const {};
  final ValueNotifier<int> _multiplierVisualRevision = ValueNotifier<int>(0);

  GridController(List<List<String>> initialGrid) {
    _grid = initialGrid;
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  List<List<String>> get grid => _grid;
  List<List<String>> get previousGrid => _previousGrid;
  Set<String> get fadingPaths => _fadingPaths;
  List<ClusterWin> get activeExplosions => _activeExplosions;
  Set<int> get winningPositions => _winningPositions;

  Set<int> get clearedPositions => _clearedPositions;
  Set<int> get multiplierResiduePositions => _multiplierResiduePositions;
  ValueListenable<int> get multiplierVisualListenable =>
      _multiplierVisualRevision;

  void capturePreviousGrid() {
    _previousGrid = List.generate(columns, (col) => List.from(_grid[col]));
  }

  void resetForNewSpin() {
    _fadingPaths = const {};
    _activeExplosions = const [];
    _winningPositions = {};
    notifyListeners();
  }

  void clearMultiplierPosition(int column, int row) {
    final key = column * 100 + row;
    if (_clearedPositions.contains(key)) return;
    _clearedPositions = {..._clearedPositions, key};
    _notifyMultiplierVisualChanged();
  }

  void revealMultiplierResidue(int column, int row) {
    final key = column * 100 + row;
    if (!_clearedPositions.contains(key) ||
        _multiplierResiduePositions.contains(key)) {
      return;
    }
    _multiplierResiduePositions = {..._multiplierResiduePositions, key};
    _notifyMultiplierVisualChanged();
  }

  void clearMultiplierResidues() {
    if (_clearedPositions.isEmpty && _multiplierResiduePositions.isEmpty) {
      return;
    }
    _clearedPositions = const {};
    _multiplierResiduePositions = const {};
    _notifyMultiplierVisualChanged();
  }

  void _notifyMultiplierVisualChanged() {
    _multiplierVisualRevision.value++;
  }

  void setGrid(List<List<String>> grid) {
    _grid = grid;
    notifyListeners();
  }

  void startTumble({
    required Set<String> fadingPaths,
    required List<ClusterWin> activeExplosions,
  }) {
    _fadingPaths = fadingPaths;
    _activeExplosions = activeExplosions;
    notifyListeners();
  }

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

  @override
  void dispose() {
    _multiplierVisualRevision.dispose();
    super.dispose();
  }
}
