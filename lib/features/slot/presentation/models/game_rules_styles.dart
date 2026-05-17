import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameRulesStyles {
  const GameRulesStyles._();

  static const Color panelColor = Color(0xFFF0CDE6);
  static const Color panelAccent = Color(0xFFE2BED8);
  static const Color textColor = Color(0xFF2C2530);

  static TextStyle headerTitle() {
    return GoogleFonts.barlowCondensed(
      fontSize: 27,
      fontWeight: FontWeight.w900,
      color: textColor,
      letterSpacing: 1.2,
    );
  }

  static TextStyle sectionTitle() {
    return GoogleFonts.barlowCondensed(
      fontSize: 17,
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: 1.0,
    );
  }

  static TextStyle bodyText() {
    return GoogleFonts.nunito(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: textColor.withValues(alpha: 0.88),
      height: 1.3,
    );
  }

  static TextStyle varianceLabel() {
    return GoogleFonts.barlowCondensed(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      color: textColor,
      letterSpacing: 1.0,
    );
  }

  static TextStyle payoutText() {
    return GoogleFonts.barlowCondensed(
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      color: textColor.withValues(alpha: 0.90),
      height: 1.2,
    );
  }
}
