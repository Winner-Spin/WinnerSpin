import 'package:flutter/material.dart';

/// Overlay shown while the player is inside a Free Spins round.
/// Displays the remaining FS counter with an elastic scale-in animation.
class FreeSpinsBanner extends StatelessWidget {
  final int remaining;

  const FreeSpinsBanner({super.key, required this.remaining});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.pinkAccent, Colors.purpleAccent],
            ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.6),
                blurRadius: 15,
                spreadRadius: 3,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: Colors.yellow, size: 28),
                const SizedBox(width: 8),
                Text(
                  'BEDAVA DÖNÜŞ: $remaining',
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.star, color: Colors.yellow, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
