import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DepositDisclaimer extends StatelessWidget {
  const DepositDisclaimer({super.key, required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      'This deposit action is not a real-money deposit. It only increases virtual in-game CREDIT with virtual game money that has no real-world value.',
      textAlign: TextAlign.center,
      style: GoogleFonts.barlowCondensed(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor.withValues(alpha: 0.72),
        height: 1.08,
      ),
    );
  }
}
