import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameHistoryEmptyState extends StatelessWidget {
  const GameHistoryEmptyState({
    super.key,
    required this.textColor,
    required this.headerColor,
  });

  final Color textColor;
  final Color headerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: textColor.withValues(alpha: 0.10)),
      ),
      child: Text(
        'NO GAME HISTORY YET',
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: textColor.withValues(alpha: 0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
