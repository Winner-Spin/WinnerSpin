import 'package:flutter/widgets.dart';

class GameStageMetrics {
  const GameStageMetrics({
    required this.screenH,
    required this.screenW,
    required this.gridLeft,
    required this.gridRight,
  });

  final double screenH;
  final double screenW;
  final double gridLeft;
  final double gridRight;

  factory GameStageMetrics.fromConstraints(BoxConstraints constraints) {
    final screenH = constraints.maxHeight;
    final screenW = constraints.maxWidth;

    const bgAspect = 1408 / 3040;
    const bgInnerLeftRatio = 88 / 1408;
    const bgInnerRightRatio = 1319 / 1408;

    final screenAspect = screenW / screenH;
    final double bgDisplayW;
    final double bgLeftOnScreen;
    if (screenAspect >= bgAspect) {
      bgDisplayW = screenW;
      bgLeftOnScreen = 0;
    } else {
      bgDisplayW = screenH * bgAspect;
      bgLeftOnScreen = (screenW - bgDisplayW) / 2;
    }

    return GameStageMetrics(
      screenH: screenH,
      screenW: screenW,
      gridLeft: bgLeftOnScreen + bgDisplayW * bgInnerLeftRatio,
      gridRight: screenW - (bgLeftOnScreen + bgDisplayW * bgInnerRightRatio),
    );
  }
}
