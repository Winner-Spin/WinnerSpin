import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../../../core/widgets/money_text.dart';
import '../../../../audio/ui_click_sound.dart';

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
      gradient = [
        Colors.grey.shade600,
        Colors.grey.shade600,
        Colors.grey.shade700,
      ];
      borderColor = Colors.grey.shade400;
      glow = Colors.transparent;
    } else {
      gradient = [
        const Color(0xFFFF66B2),
        const Color(0xFFFF1A8C),
        const Color(0xFFE60073),
      ];
      borderColor = const Color(0xFF99004D);
      glow = const Color(0xFFFF1A8C).withValues(alpha: 0.5);
    }

    final textColor = disabled ? Colors.grey.shade300 : const Color(0xFFFFF8E1);
    final textShadow = disabled ? Colors.transparent : const Color(0xFF660033);

    return GestureDetector(
      onTap: disabled
          ? null
          : () {
              UiClickSound.play();
              onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: gradient,
            stops: const [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: disabled
                ? borderColor
                : const Color(0xFFFFB3D9).withValues(alpha: 0.6),
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
                    color: borderColor,
                    blurRadius: 0,
                    spreadRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BUY FEATURE',
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                shadows: [
                  Shadow(
                    color: textShadow,
                    offset: const Offset(0, 1.5),
                    blurRadius: 1,
                  ),
                  Shadow(
                    color: textShadow,
                    offset: const Offset(0, -1),
                    blurRadius: 1,
                  ),
                  Shadow(
                    color: textShadow,
                    offset: const Offset(1, 0),
                    blurRadius: 1,
                  ),
                  Shadow(
                    color: textShadow,
                    offset: const Offset(-1, 0),
                    blurRadius: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            MoneyText(
              text: price.toStringAsFixed(0),
              style: GoogleFonts.outfit(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: textShadow,
                    offset: const Offset(0, 2),
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
