import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Small pill that toggles the spin speed multiplier (1× → 2× → 3× → 1×).
/// Shows the current multiplier and a chevron count that mirrors the level.
class SpeedButton extends StatelessWidget {
  final int multiplier;
  final VoidCallback onTap;

  const SpeedButton({
    super.key,
    required this.multiplier,
    required this.onTap,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFA1887F), // Light brown highlight
              Color(0xFF795548), // Main brown
              Color(0xFF4E342E), // Dark brown
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFD7CCC8).withValues(alpha: 0.6), // Inner reflection
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF795548).withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            const BoxShadow(
              color: Color(0xFF3E2723), // Outer darker rim shadow
              blurRadius: 0,
              spreadRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fast_forward_rounded,
              color: const Color(0xFFFFE082), // Amber
              size: multiplier == 1 ? 16 : (multiplier == 2 ? 18 : 20),
              shadows: const [
                Shadow(color: Color(0xFF3E2723), offset: Offset(0, 1), blurRadius: 1),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              '${multiplier}x',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFFF8E1), // Creamy yellow
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: const [
                  Shadow(color: Color(0xFF3E2723), offset: Offset(0, 1.5), blurRadius: 1),
                  Shadow(color: Color(0xFF3E2723), offset: Offset(0, -1), blurRadius: 1),
                  Shadow(color: Color(0xFF3E2723), offset: Offset(1, 0), blurRadius: 1),
                  Shadow(color: Color(0xFF3E2723), offset: Offset(-1, 0), blurRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
