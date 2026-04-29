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
    final Color textShadow;
    final Color glow;

    if (disabled) {
      gradient = [Colors.grey.shade700, Colors.grey.shade700, Colors.grey.shade800];
      borderColor = Colors.grey.shade500;
      textColor = Colors.grey.shade400;
      textShadow = Colors.transparent;
      glow = Colors.transparent;
    } else if (active) {
      // Glossy bright green gradient matching the "Double Chance" image
      gradient = [
        const Color(0xFFB2FF59), // Bright lime top highlight
        const Color(0xFF76FF03), // Main lime green
        const Color(0xFF388E3C), // Darker green bottom
      ];
      borderColor = const Color(0xFF1B5E20); // Deep green border
      textColor = const Color(0xFFFFF8E1); // Creamy yellow
      textShadow = const Color(0xFF003300); // Dark green shadow
      glow = const Color(0xFF76FF03).withValues(alpha: 0.6);
    } else {
      // Inactive but not disabled (still shiny green, just slightly less bright)
      gradient = [
        const Color(0xFF9CCC65), // Muted lime
        const Color(0xFF66BB6A), // Muted green
        const Color(0xFF2E7D32), // Dark green
      ];
      borderColor = const Color(0xFF1B5E20);
      textColor = const Color(0xFFF1F8E9);
      textShadow = const Color(0xFF003300);
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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: gradient,
              stops: const [0.0, 0.4, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: disabled ? borderColor : const Color(0xFFE8F5E9).withValues(alpha: 0.6), // Inner top reflection effect
              width: 1.5,
            ),
            boxShadow: glow == Colors.transparent
                ? null
                : [
                    BoxShadow(
                      color: glow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: borderColor, // Outer darker rim shadow
                      blurRadius: 0,
                      spreadRadius: 2,
                      offset: const Offset(0, 1),
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
                shadows: [
                  Shadow(color: textShadow, offset: const Offset(0, 1), blurRadius: 1)
                ],
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DOUBLE CHANCE',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      shadows: disabled ? [] : [
                        Shadow(color: textShadow, offset: const Offset(0, 1.5), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(0, -1), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(1, 0), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(-1, 0), blurRadius: 1),
                      ],
                    ),
                  ),
                  Text(
                    'TO WIN FEATURE',
                    style: GoogleFonts.outfit(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      shadows: disabled ? [] : [
                        Shadow(color: textShadow, offset: const Offset(0, 1.5), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(0, -1), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(1, 0), blurRadius: 1),
                        Shadow(color: textShadow, offset: const Offset(-1, 0), blurRadius: 1),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '2',
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontSize: 14,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: textShadow, offset: const Offset(0, 1), blurRadius: 1)],
                            ),
                          ),
                          TextSpan(
                            text: '×',
                            style: GoogleFonts.outfit(
                              color: textColor,
                              fontSize: 14,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: textShadow, offset: const Offset(0, 1), blurRadius: 1)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      active ? 'ON' : 'OFF',
                      style: GoogleFonts.outfit(
                        color: active ? Colors.greenAccent : Colors.grey.shade300,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
