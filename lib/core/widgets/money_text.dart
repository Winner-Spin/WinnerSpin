import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MoneySymbol extends StatelessWidget {
  final TextStyle style;
  final double scale;
  final double lineYOffset;
  final double lineLengthScale;
  final double lineTopExtend;
  final double textYOffset;

  const MoneySymbol({
    super.key,
    required this.style,
    this.scale = 1.0,
    this.lineYOffset = 0,
    this.lineLengthScale = 1,
    this.lineTopExtend = 0,
    this.textYOffset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = (style.fontSize ?? 18) * scale;
    return SizedBox(
      width: fontSize * 0.74,
      height: fontSize * 1.04,
      child: CustomPaint(
        painter: MoneySymbolPainter(
          style: style,
          lineYOffset: lineYOffset,
          lineLengthScale: lineLengthScale,
          lineTopExtend: lineTopExtend,
          textYOffset: textYOffset,
        ),
      ),
    );
  }
}

class MoneyText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double spacing;
  final double symbolScale;
  final Offset symbolOffset;
  final double lineYOffset;
  final double lineLengthScale;
  final double lineTopExtend;
  final double symbolTextYOffset;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const MoneyText({
    super.key,
    required this.text,
    required this.style,
    this.spacing = 1,
    this.symbolScale = 1.0,
    this.symbolOffset = const Offset(0, 0.7),
    this.lineYOffset = 0,
    this.lineLengthScale = 1,
    this.lineTopExtend = 0,
    this.symbolTextYOffset = 0,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: EdgeInsets.only(right: spacing),
              child: Transform.translate(
                offset: symbolOffset,
                child: MoneySymbol(
                  style: style,
                  scale: symbolScale,
                  lineYOffset: lineYOffset,
                  lineLengthScale: lineLengthScale,
                  lineTopExtend: lineTopExtend,
                  textYOffset: symbolTextYOffset,
                ),
              ),
            ),
          ),
          TextSpan(text: text),
        ],
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

class MoneySymbolPainter extends CustomPainter {
  final TextStyle style;
  final double lineYOffset;
  final double lineLengthScale;
  final double lineTopExtend;
  final double textYOffset;

  const MoneySymbolPainter({
    required this.style,
    this.lineYOffset = 0,
    this.lineLengthScale = 1,
    this.lineTopExtend = 0,
    this.textYOffset = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fontSize = style.fontSize ?? size.height;
    final symbolStyle = GoogleFonts.outfit(
      textStyle: style,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0,
      height: 1.0,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: 'S', style: symbolStyle),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2 + textYOffset,
      ),
    );

    final lineColor = style.foreground?.color ?? style.color ?? Colors.white;
    final shadowColor = style.shadows?.isNotEmpty == true
        ? style.shadows!.first.color.withValues(alpha: 0.48)
        : Colors.black.withValues(alpha: lineColor.a * 0.32);
    final baseStart = Offset(size.width * 0.62, size.height * 0.04);
    final baseEnd = Offset(size.width * 0.39, size.height * 0.86);
    final center = Offset.lerp(baseStart, baseEnd, 0.5)!;
    final lengthScale = lineLengthScale.clamp(0.1, 1.4);
    final start =
        center +
        (baseStart - center) * lengthScale +
        Offset(0, lineYOffset - lineTopExtend);
    final end =
        center + (baseEnd - center) * lengthScale + Offset(0, lineYOffset);
    final strokeWidth = (fontSize * 0.058).clamp(0.8, 2.1);

    canvas.drawLine(
      start.translate(0, strokeWidth * 0.65),
      end.translate(0, strokeWidth * 0.65),
      Paint()
        ..color = shadowColor
        ..strokeWidth = strokeWidth * 1.25
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = lineColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant MoneySymbolPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.lineYOffset != lineYOffset ||
      oldDelegate.lineLengthScale != lineLengthScale ||
      oldDelegate.lineTopExtend != lineTopExtend ||
      oldDelegate.textYOffset != textYOffset;
}
