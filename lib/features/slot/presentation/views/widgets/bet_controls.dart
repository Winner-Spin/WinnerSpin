import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Row of [+ / current bet / -] controls.
class BetControls extends StatelessWidget {
  final double betAmount;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const BetControls({
    super.key,
    required this.betAmount,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BetCircleButton(icon: Icons.remove, onTap: onDecrease),
        const SizedBox(width: 12),
        _BetDisplay(amount: betAmount),
        const SizedBox(width: 12),
        _BetCircleButton(icon: Icons.add, onTap: onIncrease),
      ],
    );
  }
}

class _BetCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BetCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.amber.shade600, Colors.orange.shade700],
          ),
          border: Border.all(
            color: Colors.amber.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _BetDisplay extends StatelessWidget {
  final double amount;

  const _BetDisplay({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade900.withValues(alpha: 0.85),
            Colors.deepPurple.shade800.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.amber.shade300.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'BAHİS',
            style: GoogleFonts.outfit(
              color: Colors.amber.shade200.withValues(alpha: 0.8),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.amber.shade300,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
