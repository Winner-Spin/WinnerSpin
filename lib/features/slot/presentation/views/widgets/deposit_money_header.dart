import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DepositMoneyHeader extends StatelessWidget {
  const DepositMoneyHeader({
    super.key,
    required this.textColor,
    required this.panelAccent,
    required this.onClose,
  });

  final Color textColor;
  final Color panelAccent;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'DEPOSIT MONEY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onClose,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, size: 30, color: textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
