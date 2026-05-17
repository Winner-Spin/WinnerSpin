import 'package:flutter/material.dart';

import 'spin_controls_row.dart';

class GameSpinControlsSlot extends StatelessWidget {
  const GameSpinControlsSlot({
    super.key,
    required this.screenH,
    required this.listenable,
    required this.autoSpinActive,
    required this.bigWinShowing,
    required this.spinning,
    required this.canDecreaseBet,
    required this.canIncreaseBet,
    required this.isInFreeSpins,
    required this.autoSpinsRemaining,
    required this.onDecreaseBet,
    required this.onIncreaseBet,
    required this.onSpin,
    required this.onStopAutoSpin,
  });

  final double screenH;
  final Listenable listenable;
  final bool Function() autoSpinActive;
  final bool Function() bigWinShowing;
  final bool Function() spinning;
  final bool Function() canDecreaseBet;
  final bool Function() canIncreaseBet;
  final bool Function() isInFreeSpins;
  final int? Function() autoSpinsRemaining;
  final VoidCallback onDecreaseBet;
  final VoidCallback onIncreaseBet;
  final VoidCallback onSpin;
  final VoidCallback onStopAutoSpin;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: screenH * 0.72,
      left: 0,
      right: 0,
      child: ListenableBuilder(
        listenable: listenable,
        builder: (context, _) => SpinControlsRow(
          autoSpinActive: autoSpinActive(),
          bigWinShowing: bigWinShowing(),
          spinning: spinning(),
          canDecreaseBet: canDecreaseBet(),
          canIncreaseBet: canIncreaseBet(),
          isInFreeSpins: isInFreeSpins(),
          autoSpinsRemaining: autoSpinsRemaining(),
          onDecreaseBet: onDecreaseBet,
          onIncreaseBet: onIncreaseBet,
          onSpin: onSpin,
          onStopAutoSpin: onStopAutoSpin,
        ),
      ),
    );
  }
}
