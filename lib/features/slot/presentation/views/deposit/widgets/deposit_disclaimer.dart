import 'package:flutter/material.dart';
import '../../../../../../core/typography/app_fonts.dart';

class DepositDisclaimer extends StatelessWidget {
  const DepositDisclaimer({super.key, required this.textColor});

  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      'This is not a real-money payment. It only tops up your virtual in-game CREDIT with free game money that has no real-world value.',
      textAlign: TextAlign.center,
      style: AppFonts.barlowCondensed(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textColor.withValues(alpha: 0.72),
        height: 1.08,
      ),
    );
  }
}
