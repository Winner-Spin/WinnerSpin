import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../core/format/money_format.dart';
import '../../../../../../core/widgets/money_text.dart';

class DepositCreditLine extends StatelessWidget {
  const DepositCreditLine({
    super.key,
    required this.balance,
    required this.textColor,
  });

  final double balance;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'CURRENT CREDIT',
          style: GoogleFonts.barlowCondensed(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textColor.withValues(alpha: 0.70),
          ),
        ),
        const SizedBox(height: 5),
        MoneyText(
          text: formatMoney(balance),
          symbolOffset: const Offset(0, 2.0),
          lineYOffset: 2.35,
          symbolTextYOffset: 2.3,
          style: GoogleFonts.barlowCondensed(
            fontSize: 25,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
      ],
    );
  }
}
