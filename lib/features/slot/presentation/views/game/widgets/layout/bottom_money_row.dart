import 'package:flutter/material.dart';

import '../../../../../../../core/format/money_format.dart';
import '../../../../../../../core/widgets/money_text.dart';

class BottomMoneyRow extends StatelessWidget {
  final double balance;
  final double betAmount;
  final TextStyle labelStyle;
  final TextStyle valueStyle;

  const BottomMoneyRow({
    super.key,
    required this.balance,
    required this.betAmount,
    required this.labelStyle,
    required this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('CREDIT', style: labelStyle),
          const SizedBox(width: 4),
          MoneyText(
            text: formatMoney(balance),
            style: valueStyle,
            symbolOffset: const Offset(0, 1.1),
            lineYOffset: 1.05,
            symbolTextYOffset: 0.45,
          ),
          const SizedBox(width: 16),
          Text('BET', style: labelStyle),
          const SizedBox(width: 4),
          MoneyText(
            text: formatMoney(betAmount),
            style: valueStyle,
            symbolOffset: const Offset(0, 1.1),
            lineYOffset: 1.05,
            symbolTextYOffset: 0.45,
          ),
        ],
      ),
    );
  }
}
