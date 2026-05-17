import 'package:flutter/material.dart';

import '../../../../../domain/models/cluster_win.dart';
import '../presentation/effects/floating_win_overlay.dart';

class SlotPlayfield extends StatelessWidget {
  const SlotPlayfield({
    super.key,
    required this.screenH,
    required this.screenW,
    required this.gridLeft,
    required this.gridRight,
    required this.gridListenable,
    required this.floatingWinListenable,
    required this.activeExplosions,
    required this.speedMultiplier,
    required this.buildSlotGrid,
  });

  final double screenH;
  final double screenW;
  final double gridLeft;
  final double gridRight;
  final Listenable gridListenable;
  final Listenable floatingWinListenable;
  final List<ClusterWin> Function() activeExplosions;
  final int Function() speedMultiplier;
  final Widget Function() buildSlotGrid;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: screenH * 0.195,
      left: gridLeft,
      right: gridRight,
      height: screenH * 0.32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: gridListenable,
              builder: (context, _) => buildSlotGrid(),
            ),
          ),
          Positioned.fill(
            child: ListenableBuilder(
              listenable: floatingWinListenable,
              builder: (context, _) {
                return RepaintBoundary(
                  child: FloatingWinOverlay(
                    activeExplosions: activeExplosions(),
                    gridWidth: screenW * 0.87,
                    gridHeight: screenH * 0.32,
                    speedMultiplier: speedMultiplier(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
