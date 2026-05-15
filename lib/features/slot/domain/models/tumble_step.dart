import 'cluster_win.dart';

class TumbleStep {
  final Set<String> winningPaths;

  final List<List<String>> gridAfter;

  final double winAmount;

  final List<ClusterWin> clusterWins;

  const TumbleStep({
    required this.winningPaths,
    required this.gridAfter,
    required this.winAmount,
    this.clusterWins = const [],
  });
}
