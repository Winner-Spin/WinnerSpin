import 'package:flutter/material.dart';

import 'game_bottom_gradient_panel.dart';
import 'game_bottom_panel.dart';

class GameBottomInfoSlot extends StatelessWidget {
  const GameBottomInfoSlot({
    super.key,
    required this.balanceListenable,
    required this.balance,
    required this.betAmount,
    required this.labelStyle,
    required this.valueStyle,
    required this.clockStyle,
  });

  final Listenable balanceListenable;
  final double Function() balance;
  final double Function() betAmount;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle clockStyle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 12,
      left: 0,
      right: 0,
      child: GameBottomGradientPanel(
        child: GameBottomPanel(
          balanceListenable: balanceListenable,
          balance: balance,
          betAmount: betAmount,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
          clockStyle: clockStyle,
        ),
      ),
    );
  }
}
