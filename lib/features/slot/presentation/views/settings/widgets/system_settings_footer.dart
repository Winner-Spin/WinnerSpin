import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemSettingsFooter extends StatelessWidget {
  const SystemSettingsFooter({super.key});

  static const _creditText =
      'Made with \u2615\uFE0F & \u{1F4BB} by Hakan G\u00FCne\u015F & Enes Eken';
  static const _disclaimerText =
      'This project is created solely for entertainment and portfolio purposes. It does not offer real-money gambling, betting, cash prizes, or withdrawal services. All coins, spins, bonuses, and rewards included in this project are entirely virtual; they have no real-world monetary value and cannot be purchased, sold, or converted into money in any way. This project does not promote or encourage gambling or betting activities.';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _creditText,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _disclaimerText,
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
            color: Colors.black.withValues(alpha: 0.74),
            height: 1.08,
          ),
        ),
      ],
    );
  }
}
