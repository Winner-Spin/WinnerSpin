import 'package:flutter/material.dart';

import 'multiplier_bomb_symbol.dart';

class TumbleFrozenMultiplierBomb extends StatelessWidget {
  const TumbleFrozenMultiplierBomb({
    super.key,
    required this.opacity,
    required this.itemH,
    required this.multiplierValue,
  });

  final Animation<double> opacity;
  final double itemH;
  final int multiplierValue;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: opacity,
      builder: (context, child) =>
          Opacity(opacity: opacity.value, child: child),
      child: MultiplierBombSymbol(
        itemH: itemH,
        multiplierValue: multiplierValue,
        labelAlignmentY: 0.22,
      ),
    );
  }
}
