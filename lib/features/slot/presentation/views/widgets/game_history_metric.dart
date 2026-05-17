import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameHistoryMetric extends StatelessWidget {
  const GameHistoryMetric({
    super.key,
    required this.label,
    required this.textColor,
    this.value,
    this.valueWidget,
    this.valueColor,
  }) : assert(value != null || valueWidget != null);

  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color textColor;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: textColor.withValues(alpha: 0.48),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child:
                valueWidget ??
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? textColor,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}
