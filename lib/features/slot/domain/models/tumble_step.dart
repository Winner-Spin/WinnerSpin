import 'cluster_win.dart';

/// One tumble step: which symbols won + the grid state AFTER removal/gravity/refill.
class TumbleStep {
  /// Asset paths of regular symbols that won (8+ count) this tumble.
  /// UI uses this to fade out matching cells before showing [gridAfter].
  final Set<String> winningPaths;

  /// Grid state after this tumble's removal + gravity + refill.
  final List<List<String>> gridAfter;

  /// Base win amount for this tumble (before global multiplier / scatter bonus).
  final double winAmount;

  /// Tracks the specific win amount and positions for each exploded symbol type in this tumble.
  final List<ClusterWin> clusterWins;

  const TumbleStep({
    required this.winningPaths,
    required this.gridAfter,
    required this.winAmount,
    this.clusterWins = const [],
  });
}
