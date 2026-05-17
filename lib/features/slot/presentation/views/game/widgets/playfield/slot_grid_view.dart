import 'package:flutter/material.dart';

import 'slot_reel.dart';
import 'slot_reel_controller.dart';

class SlotGridView extends StatelessWidget {
  final int columns;
  final List<SlotReelController> reelControllers;
  final List<List<String>> previousGrid;
  final List<List<String>> grid;
  final bool isSpinning;
  final Set<String> fadingPaths;
  final Set<int> clearedPositions;
  final int speedMultiplier;
  final bool soundEffectsEnabled;
  final bool pulseScattersOnLanding;
  final int scatterPulseTrigger;
  final VoidCallback onSpinComplete;
  final VoidCallback onFirstDropInStart;

  const SlotGridView({
    super.key,
    required this.columns,
    required this.reelControllers,
    required this.previousGrid,
    required this.grid,
    required this.isSpinning,
    required this.fadingPaths,
    required this.clearedPositions,
    required this.speedMultiplier,
    required this.soundEffectsEnabled,
    required this.pulseScattersOnLanding,
    required this.scatterPulseTrigger,
    required this.onSpinComplete,
    required this.onFirstDropInStart,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: List.generate(columns, (col) {
          return Expanded(
            child: RepaintBoundary(
              child: SlotReel(
                columnIndex: col,
                controller: reelControllers[col],
                previousItems: previousGrid[col],
                targetItems: grid[col],
                spinning: isSpinning,
                fadingPaths: fadingPaths,
                clearedPositions: clearedPositions,
                speedMultiplier: speedMultiplier,
                soundEffectsEnabled: soundEffectsEnabled,
                pulseScattersOnLanding: pulseScattersOnLanding,
                scatterPulseTrigger: scatterPulseTrigger,
                onComplete: col == columns - 1 ? onSpinComplete : null,
                onDropInStart: col == 0 ? onFirstDropInStart : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}
