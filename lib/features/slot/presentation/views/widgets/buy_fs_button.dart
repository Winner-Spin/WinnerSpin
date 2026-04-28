import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CTA that purchases a Free Spins round at 100× the base bet. Disabled
/// while busy, in an existing FS round, balance is short, or the pool
/// guard refuses (see GameViewModel.canBuyFreeSpins).
class BuyFsButton extends StatelessWidget {
  final double price;
  final bool disabled;
  final VoidCallback onTap;

  const BuyFsButton({
    super.key,
    required this.price,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient;
    final Color borderColor;
    final Color glow;

    if (disabled) {
      gradient = [Colors.grey.shade600, Colors.grey.shade700];
      borderColor = Colors.grey.shade400;
      glow = Colors.transparent;
    } else {
      gradient = [Colors.amber.shade500, Colors.orange.shade700];
      borderColor = Colors.yellow.shade300;
      glow = Colors.orange.withValues(alpha: 0.4);
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: glow == Colors.transparent
              ? null
              : [
                  BoxShadow(
                    color: glow,
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FS SATIN AL',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₺${price.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 1),
                    blurRadius: 3,
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
