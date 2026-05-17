import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameScreenTextStyles {
  final TextStyle statusBase;
  final TextStyle statusAccent;
  final TextStyle statusInsufficient;
  final TextStyle bottomLabel;
  final TextStyle bottomValue;
  final TextStyle bottomClock;

  const GameScreenTextStyles({
    required this.statusBase,
    required this.statusAccent,
    required this.statusInsufficient,
    required this.bottomLabel,
    required this.bottomValue,
    required this.bottomClock,
  });

  factory GameScreenTextStyles.create() {
    final softShadow = [
      Shadow(
        color: Colors.black.withValues(alpha: 0.60),
        offset: const Offset(0, 1),
        blurRadius: 1.2,
      ),
    ];

    final statusBase = GoogleFonts.anton(
      color: Colors.white.withValues(alpha: 0.97),
      fontSize: 20,
      letterSpacing: 0.8,
      height: 1.0,
      decoration: TextDecoration.none,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.70),
          offset: const Offset(0, 1),
          blurRadius: 1.6,
        ),
      ],
    );

    return GameScreenTextStyles(
      statusBase: statusBase,
      statusAccent: statusBase.copyWith(color: const Color(0xFFFFD13B)),
      statusInsufficient: statusBase.copyWith(color: const Color(0xFFFF6A6A)),
      bottomLabel: GoogleFonts.barlowCondensed(
        color: const Color(0xFFFFD13B),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        height: 1.0,
        shadows: softShadow,
      ),
      bottomValue: GoogleFonts.barlowCondensed(
        color: Colors.white.withValues(alpha: 0.98),
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
        height: 1.0,
        shadows: softShadow,
      ),
      bottomClock: GoogleFonts.barlowCondensed(
        color: Colors.white.withValues(alpha: 0.62),
        fontSize: 9.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
        height: 1.0,
      ),
    );
  }
}
