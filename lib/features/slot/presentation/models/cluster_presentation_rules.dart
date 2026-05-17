import '../../domain/models/cluster_win.dart';

class ClusterPresentationRules {
  const ClusterPresentationRules._();

  static ClusterWin? highestAmount(Iterable<ClusterWin> clusters) {
    ClusterWin? best;
    for (final cluster in clusters) {
      if (best == null || cluster.amount > best.amount) {
        best = cluster;
      }
    }
    return best;
  }
}
