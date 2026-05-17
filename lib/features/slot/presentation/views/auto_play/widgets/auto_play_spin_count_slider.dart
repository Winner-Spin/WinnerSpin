import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'auto_play_slider_thumb_shape.dart';

class AutoPlaySpinCountSlider extends StatelessWidget {
  const AutoPlaySpinCountSlider({
    super.key,
    required this.spinCount,
    required this.spinCountIndex,
    required this.maxIndex,
    required this.textColor,
    required this.onChanged,
  });

  final int spinCount;
  final int spinCountIndex;
  final int maxIndex;
  final Color textColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00C76A),
              inactiveTrackColor: textColor.withValues(alpha: 0.18),
              trackHeight: 3,
              thumbColor: const Color(0xFF00C76A),
              overlayColor: const Color(0xFF00C76A).withValues(alpha: 0.18),
              thumbShape: const AutoPlaySliderThumbShape(),
            ),
            child: Slider(
              min: 0,
              max: maxIndex.toDouble(),
              divisions: maxIndex,
              value: spinCountIndex.toDouble(),
              onChanged: (value) => onChanged(value.round()),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '$spinCount',
            textAlign: TextAlign.right,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
