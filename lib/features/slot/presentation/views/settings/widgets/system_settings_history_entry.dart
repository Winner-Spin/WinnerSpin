import 'package:flutter/material.dart';
import '../../../../../../core/typography/app_fonts.dart';

class SystemSettingsHistoryEntry extends StatelessWidget {
  const SystemSettingsHistoryEntry({
    super.key,
    required this.textColor,
    required this.onTap,
  });

  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'GAME HISTORY',
            style: AppFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor.withValues(alpha: 0.70),
            ),
          ),
          Icon(
            Icons.open_in_new,
            color: textColor.withValues(alpha: 0.70),
            size: 24,
          ),
        ],
      ),
    );
  }
}
