import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/widgets/money_text.dart';

class EmbossedButtonText extends StatelessWidget {
  const EmbossedButtonText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
    required this.letterSpacing,
    required this.fillColor,
    required this.strokeColor,
    required this.shadowColor,
    this.highlightColor = const Color(0x55FFC089),
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final double letterSpacing;
  final Color fillColor;
  final Color strokeColor;
  final Color shadowColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: _baseStyle(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: _baseStyle(
            color: fillColor,
            shadows: [
              Shadow(
                color: shadowColor,
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
              Shadow(
                color: highlightColor,
                offset: const Offset(0, -1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _baseStyle({
    Paint? foreground,
    Color? color,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1.0,
      foreground: foreground,
      color: color,
      shadows: shadows,
    );
  }
}

class EmbossedButtonMoneyText extends StatelessWidget {
  const EmbossedButtonMoneyText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
    required this.letterSpacing,
    required this.fillColor,
    required this.strokeColor,
    required this.shadowColor,
    this.highlightColor = const Color(0x55FFC089),
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final double letterSpacing;
  final Color fillColor;
  final Color strokeColor;
  final Color shadowColor;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MoneyText(
          text: text,
          style: _baseStyle(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        MoneyText(
          text: text,
          style: _baseStyle(
            color: fillColor,
            shadows: [
              Shadow(
                color: shadowColor,
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
              Shadow(
                color: highlightColor,
                offset: const Offset(0, -1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _baseStyle({
    Paint? foreground,
    Color? color,
    List<Shadow>? shadows,
  }) {
    return GoogleFonts.outfit(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: letterSpacing,
      height: 1.0,
      foreground: foreground,
      color: color,
      shadows: shadows,
    );
  }
}
