import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';

class BuyFreeSpinsPriceBox extends StatelessWidget {
  const BuyFreeSpinsPriceBox({
    super.key,
    required this.price,
    required this.textColor,
  });

  final double price;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: textColor.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'COST',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 10),
          MoneyText(
            text: formatMoney(price),
            symbolOffset: const Offset(0, 2.0),
            lineYOffset: 2.35,
            symbolTextYOffset: 2.3,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
