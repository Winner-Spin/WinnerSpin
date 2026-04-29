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

  String get _arrows {
    if (multiplier == 2) return '>>';
    if (multiplier == 3) return '>>>';
    return '>';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.brown.shade400,
              Colors.brown.shade700,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.amber.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.withValues(alpha: 0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fast_forward_rounded,
              color: Colors.amber.shade300,
              size: multiplier == 1 ? 16 : (multiplier == 2 ? 18 : 20),
            ),
            const SizedBox(width: 6),
            Text(
              '${multiplier}x',
              style: GoogleFonts.outfit(
                color: Colors.amber.shade300,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
