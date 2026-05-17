import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AutoPlayStartButton extends StatelessWidget {
  const AutoPlayStartButton({
    super.key,
    required this.spinCount,
    required this.disabled,
    required this.onTap,
  });

  final int spinCount;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Container(
          width: double.infinity,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF00C76A),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'START AUTOPLAY ($spinCount)',
              style: GoogleFonts.barlowCondensed(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
