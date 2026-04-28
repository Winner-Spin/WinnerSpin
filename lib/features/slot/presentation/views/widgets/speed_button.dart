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
          color: Colors.grey.shade800,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey.shade400.withValues(alpha: 0.8),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${multiplier}x',
              style: GoogleFonts.outfit(
                color: Colors.amber.shade300,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _arrows,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
