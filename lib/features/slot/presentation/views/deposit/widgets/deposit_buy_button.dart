import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DepositBuyButton extends StatelessWidget {
  const DepositBuyButton({
    super.key,
    required this.isBuying,
    required this.onTap,
  });

  final bool isBuying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isBuying ? null : onTap,
      child: AnimatedOpacity(
        opacity: isBuying ? 0.65 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 48,
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
          child: Text(
            isBuying ? 'ADDING...' : 'BUY GAME MONEY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }
}
