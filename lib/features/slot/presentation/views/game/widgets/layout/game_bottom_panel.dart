import 'package:flutter/material.dart';

import 'bottom_money_row.dart';
import 'footer_clock_text.dart';

class GameBottomPanel extends StatelessWidget {
  final Listenable balanceListenable;
  final double Function() balance;
  final double Function() betAmount;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final TextStyle clockStyle;

  const GameBottomPanel({
    super.key,
    required this.balanceListenable,
    required this.balance,
    required this.betAmount,
    required this.labelStyle,
    required this.valueStyle,
    required this.clockStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListenableBuilder(
          listenable: balanceListenable,
          builder: (context, _) => BottomMoneyRow(
            balance: balance(),
            betAmount: betAmount(),
            labelStyle: labelStyle,
            valueStyle: valueStyle,
          ),
        ),
        const SizedBox(height: 1),
        FooterClockText(style: clockStyle),
      ],
    );
  }
}
