import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../widgets/particle_effect.dart';

/// Pill that toggles Ante Bet ("Çifte Şans"). When ON, the player pays
/// 1.25× per base spin and the FS trigger rate doubles. Disabled while
/// busy or inside an FS round (toggle would be ignored anyway).
class AnteToggle extends StatelessWidget {
  final bool active;
  final bool disabled;
  final VoidCallback onTap;

  const AnteToggle({
    super.key,
    required this.active,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient;
    final Color borderColor;
    final Color textColor;
    final Color glow;

    if (disabled) {
      gradient = [Colors.grey.shade700, Colors.grey.shade800];
      borderColor = Colors.grey.shade500;
      textColor = Colors.grey.shade400;
      glow = Colors.transparent;
    } else if (active) {
      gradient = [
        Colors.pink.shade300,
        Colors.pink.shade400,
        Colors.pink.shade500,
      ];
      borderColor = Colors.white;
      textColor = Colors.white;
      glow = Colors.pink.shade300.withValues(alpha: 0.6);
    } else {
      gradient = [
        Colors.pink.shade300,
        Colors.pink.shade400,
        Colors.pink.shade500,
      ];
      borderColor = Colors.white.withValues(alpha: 0.4);
      textColor = Colors.white.withValues(alpha: 0.9);
      glow = Colors.transparent;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: ParticleEffect(
        active: active,
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: glow == Colors.transparent
              ? null
              : [
                  BoxShadow(
                    color: glow,
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.bolt : Icons.bolt_outlined,
              size: 16,
              color: textColor,
            ),
            const SizedBox(width: 6),
            Text(
              'ÇİFTE ŞANS',
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              decoration: BoxDecoration(
                color: active
                    ? Colors.black.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '2',
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(
                      text: '×',
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontSize: 14,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
