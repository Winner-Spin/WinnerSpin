import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Celebratory overlay shown after a winning spin. Pops in with an elastic
/// scale curve and reads its amount from [winAmount] (TL).
class WinBanner extends StatelessWidget {
  final double winAmount;

  const WinBanner({super.key, required this.winAmount});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700.withValues(alpha: 0.95),
              Colors.orange.shade600.withValues(alpha: 0.95),
              Colors.amber.shade700.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.yellow.shade300, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '🎉 KAZANDIN! 🎉',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₺${winAmount.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                color: Colors.yellow.shade100,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
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
