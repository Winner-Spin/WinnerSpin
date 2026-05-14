import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'multiplier_bomb_animation.dart';
import 'multiplier_label.dart';

/// Static multiplier bomb used in reel/drop and resting grid states.
///
/// The detonation itself is still handled by [MultiplierBombAnimation]; this
/// widget only composes the frozen bomb body with the multiplier face label.
class MultiplierBombSymbol extends StatelessWidget {
  final double itemH;
  final int multiplierValue;
  final double labelAlignmentY;

  const MultiplierBombSymbol({
    super.key,
    required this.itemH,
    required this.multiplierValue,
    required this.labelAlignmentY,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: itemH * 1.3,
        height: itemH * 1.3,
        child: RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Transform.scale(
                scale: MultiplierLabel.bombScaleFor(multiplierValue),
                child: Lottie.asset(
                  MultiplierBombAnimation.assetPath,
                  fit: BoxFit.contain,
                  animate: false,
                  renderCache: RenderCache.drawingCommands,
                ),
              ),
              Align(
                alignment: Alignment(
                  MultiplierLabel.labelXOffsetFor(multiplierValue),
                  labelAlignmentY,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1.0,
                  heightFactor: 0.43,
                  child: MultiplierLabel(
                    value: multiplierValue,
                    fit: BoxFit.fitHeight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
