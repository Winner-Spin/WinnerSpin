import 'package:flutter/material.dart';

import 'status_band.dart';

class GameStatusBands extends StatelessWidget {
  const GameStatusBands({
    super.key,
    required this.screenH,
    required this.freeSpinVisualListenable,
    required this.balanceStatusListenable,
    required this.isFreeSpinVisualMode,
    required this.buildStatusText,
    required this.buildTumbleWinSlot,
    required this.freeSpinInfoLine,
  });

  final double screenH;
  final Listenable freeSpinVisualListenable;
  final Listenable balanceStatusListenable;
  final bool Function() isFreeSpinVisualMode;
  final Widget Function() buildStatusText;
  final Widget Function() buildTumbleWinSlot;
  final Widget freeSpinInfoLine;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: freeSpinVisualListenable,
      builder: (context, _) {
        final isFs = isFreeSpinVisualMode();
        const bandHeight = 31.0;
        const wideGap = 31.0;
        const infoTop = bandHeight;
        const kazancTop = infoTop + bandHeight + wideGap;
        const fsTotalHeight = kazancTop + bandHeight;
        final totalHeight = isFs ? fsTotalHeight : bandHeight;
        final kazancBand = StatusBand(
          child: ListenableBuilder(
            listenable: balanceStatusListenable,
            builder: (context, _) => buildStatusText(),
          ),
        );

        return Positioned(
          top: screenH * 0.5185,
          left: 0,
          right: 0,
          height: totalHeight,
          child: Stack(
            children: [
              if (isFs) ...[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bandHeight,
                  child: StatusBand(child: buildTumbleWinSlot()),
                ),
                Positioned(
                  top: infoTop,
                  left: 0,
                  right: 0,
                  height: bandHeight,
                  child: StatusBand(child: freeSpinInfoLine),
                ),
                Positioned(
                  top: kazancTop,
                  left: 0,
                  right: 0,
                  height: bandHeight,
                  child: kazancBand,
                ),
              ] else
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: bandHeight,
                  child: kazancBand,
                ),
            ],
          ),
        );
      },
    );
  }
}
