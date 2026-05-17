import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'custom_switch.dart';

class SystemSettingsRow extends StatelessWidget {
  const SystemSettingsRow({
    super.key,
    required this.title,
    required this.description,
    required this.value,
    required this.textColor,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final Color textColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor.withValues(alpha: 0.58),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
