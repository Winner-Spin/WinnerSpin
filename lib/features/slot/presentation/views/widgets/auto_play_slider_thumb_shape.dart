import 'package:flutter/material.dart';

class AutoPlaySliderThumbShape extends SliderComponentShape {
  const AutoPlaySliderThumbShape();

  static const Size _thumbSize = Size(36, 30);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _thumbSize;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: _thumbSize.width,
      height: _thumbSize.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF13DF70));

    final linePaint = Paint()
      ..color = const Color(0xFF008A3D)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const spacing = 7.0;
    for (var i = -1; i <= 1; i++) {
      final x = center.dx + i * spacing;
      canvas.drawLine(
        Offset(x, center.dy - 6),
        Offset(x, center.dy + 6),
        linePaint,
      );
    }
  }
}
