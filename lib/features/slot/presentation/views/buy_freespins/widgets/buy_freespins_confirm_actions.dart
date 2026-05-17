import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BuyFreeSpinsConfirmActions extends StatelessWidget {
  const BuyFreeSpinsConfirmActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BuyFreeSpinsConfirmActionButton(
            label: 'NO',
            color: const Color(0xFFE5485B),
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _BuyFreeSpinsConfirmActionButton(
            label: 'YES',
            color: const Color(0xFF00C76A),
            onTap: onConfirm,
          ),
        ),
      ],
    );
  }
}

class _BuyFreeSpinsConfirmActionButton extends StatelessWidget {
  const _BuyFreeSpinsConfirmActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
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
          label,
          style: GoogleFonts.barlowCondensed(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
