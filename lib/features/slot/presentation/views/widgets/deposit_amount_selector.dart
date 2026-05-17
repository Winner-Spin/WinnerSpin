import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';

class DepositAmountSelector extends StatelessWidget {
  const DepositAmountSelector({
    super.key,
    required this.amount,
    required this.canDecrease,
    required this.canIncrease,
    required this.textColor,
    required this.onDecrease,
    required this.onIncrease,
  });

  final double amount;
  final bool canDecrease;
  final bool canIncrease;
  final Color textColor;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'GAME MONEY AMOUNT',
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            DepositAmountButton(
              icon: Icons.remove,
              onTap: onDecrease,
              enabled: canDecrease,
            ),
            const SizedBox(width: 16),
            Container(
              width: 150,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF6D7EB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: textColor.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: MoneyText(
                text: formatMoney(amount),
                symbolOffset: const Offset(0, 2.0),
                lineYOffset: 2.35,
                symbolTextYOffset: 2.3,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            DepositAmountButton(
              icon: Icons.add,
              onTap: onIncrease,
              enabled: canIncrease,
            ),
          ],
        ),
      ],
    );
  }
}

class DepositAmountButton extends StatelessWidget {
  const DepositAmountButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.enabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black, size: 28),
        ),
      ),
    );
  }
}
