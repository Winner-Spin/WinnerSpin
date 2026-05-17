import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuyFreeSpinsPackageInfo extends StatelessWidget {
  const BuyFreeSpinsPackageInfo({
    super.key,
    required this.spinCount,
    required this.textColor,
  });

  final int spinCount;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'FREE SPINS PACKAGE',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$spinCount FREE SPINS',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: textColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}
