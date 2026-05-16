import 'package:flutter/material.dart';

import '../../../domain/models/spin_result.dart';
import 'tumble_win_line.dart';
import 'win_presentation.dart';
import 'win_presentation_controller.dart';

class GameTumbleWinSlot extends StatelessWidget {
  const GameTumbleWinSlot({
    super.key,
    required this.listenable,
    required this.isFlyingTumble,
    required this.isBusy,
    required this.liveTumbleWin,
    required this.lastWin,
    required this.result,
    required this.controller,
    required this.anchorKey,
    required this.labelStyle,
    required this.valueStyle,
    required this.vibrationEnabled,
    required this.soundEnabled,
    required this.speedMultiplier,
    required this.screenH,
    required this.screenW,
    required this.gridLeft,
    required this.gridRight,
    required this.onMultiplierLifted,
  });

  final Listenable listenable;
  final bool Function() isFlyingTumble;
  final bool Function() isBusy;
  final double Function() liveTumbleWin;
  final double Function() lastWin;
  final SpinResult? Function() result;
  final WinPresentationController controller;
  final GlobalKey? anchorKey;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool Function() vibrationEnabled;
  final bool Function() soundEnabled;
  final int Function() speedMultiplier;
  final double screenH;
  final double screenW;
  final double gridLeft;
  final double gridRight;
  final void Function(int column, int row) onMultiplierLifted;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final spinResult = result();
        final hasMultiplierSequence =
            spinResult != null &&
            spinResult.baseWin > 0 &&
            spinResult.finalMultipliers.isNotEmpty;
        final showOrchestrator =
            hasMultiplierSequence &&
            !isBusy() &&
            controller.phase != WinPresentationPhase.done;

        return Stack(
          children: [
            Center(
              child: TumbleWinLine(
                isFlyingTumble: isFlyingTumble(),
                isBusy: isBusy(),
                liveTumbleWin: liveTumbleWin(),
                lastWin: lastWin(),
                result: spinResult,
                controller: controller,
                anchorKey: anchorKey,
                labelStyle: labelStyle,
                valueStyle: valueStyle,
                vibrationEnabled: vibrationEnabled(),
              ),
            ),
            if (showOrchestrator)
              WinPresentation(
                key: ValueKey<Object?>(spinResult),
                controller: controller,
                formulaOnly: true,
                flightTargetKey: anchorKey,
                spinResult: spinResult,
                gridLeft: gridLeft,
                gridTop: screenH * 0.195,
                gridWidth: screenW - gridLeft - gridRight,
                gridHeight: screenH * 0.32,
                baseStyle: valueStyle,
                accentStyle: labelStyle,
                soundEnabled: soundEnabled(),
                speedMultiplier: speedMultiplier(),
                onMultiplierLifted: onMultiplierLifted,
              ),
          ],
        );
      },
    );
  }
}
