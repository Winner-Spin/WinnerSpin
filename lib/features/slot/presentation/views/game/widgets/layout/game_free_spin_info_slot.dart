import 'package:flutter/material.dart';

import '../../../../../domain/models/cluster_win.dart';
import '../../../../models/cluster_presentation_rules.dart';
import '../presentation/free_spins/free_spin_info_line.dart';

class GameFreeSpinInfoSlot extends StatelessWidget {
  const GameFreeSpinInfoSlot({
    super.key,
    required this.listenable,
    required this.activeExplosions,
    required this.lingeringCluster,
    required this.freeSpinsRemaining,
    required this.style,
  });

  final Listenable listenable;
  final List<ClusterWin> Function() activeExplosions;
  final ClusterWin? Function() lingeringCluster;
  final int Function() freeSpinsRemaining;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final explosions = activeExplosions();
        final clusterToShow =
            ClusterPresentationRules.highestAmount(explosions) ??
            lingeringCluster();

        return FreeSpinInfoLine(
          cluster: clusterToShow,
          freeSpinsRemaining: freeSpinsRemaining(),
          style: style,
        );
      },
    );
  }
}
