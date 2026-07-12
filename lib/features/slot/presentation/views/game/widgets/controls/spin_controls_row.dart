import 'package:flutter/material.dart';

import 'minus_button.dart';
import 'plus_button.dart';
import 'respin_button.dart';

class SpinControlsRow extends StatelessWidget {
  final bool autoSpinActive;
  final bool bigWinShowing;
  final bool spinning;
  final bool canDecreaseBet;
  final bool canIncreaseBet;
  final bool isInFreeSpins;
  final int? autoSpinsRemaining;
  final int freeSpinsRemaining;
  final VoidCallback onDecreaseBet;
  final VoidCallback onIncreaseBet;
  final VoidCallback onSpin;
  final VoidCallback onStopAutoSpin;

  const SpinControlsRow({
    super.key,
    required this.autoSpinActive,
    required this.bigWinShowing,
    required this.spinning,
    required this.canDecreaseBet,
    required this.canIncreaseBet,
    required this.isInFreeSpins,
    required this.autoSpinsRemaining,
    required this.freeSpinsRemaining,
    required this.onDecreaseBet,
    required this.onIncreaseBet,
    required this.onSpin,
    required this.onStopAutoSpin,
  });

  @override
  Widget build(BuildContext context) {
    final displayedSpinsRemaining = isInFreeSpins
        ? freeSpinsRemaining
        : autoSpinActive
        ? autoSpinsRemaining
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!autoSpinActive && !isInFreeSpins) ...[
          RepaintBoundary(
            child: MinusButton(
              size: 42,
              onTap: onDecreaseBet,
              disabled: bigWinShowing || !canDecreaseBet || isInFreeSpins,
            ),
          ),
          const SizedBox(width: 16),
        ],
        RepaintBoundary(
          child: RespinButton(
            size: 84,
            onTap: isInFreeSpins
                ? null
                : autoSpinActive
                ? onStopAutoSpin
                : onSpin,
            spinning: spinning,
            disabled: bigWinShowing || isInFreeSpins,
            dimWhenDisabled: !isInFreeSpins,
            autoSpinsRemaining: displayedSpinsRemaining,
          ),
        ),
        if (!autoSpinActive && !isInFreeSpins) ...[
          const SizedBox(width: 16),
          RepaintBoundary(
            child: PlusButton(
              size: 42,
              onTap: onIncreaseBet,
              disabled: bigWinShowing || !canIncreaseBet || isInFreeSpins,
            ),
          ),
        ],
      ],
    );
  }
}
