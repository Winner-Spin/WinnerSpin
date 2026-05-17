import 'package:flutter/material.dart';

class SolidArrowPainter extends CustomPainter {
  const SolidArrowPainter({required this.color, this.reversed = false});

  final Color color;
  final bool reversed;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    final shaftEnd = w * 0.55;
    final shaftHalf = h * 0.18;
    final headHalf = h * 0.45;

    final path = Path()
      ..moveTo(0, cy - shaftHalf)
      ..lineTo(shaftEnd, cy - shaftHalf)
      ..lineTo(shaftEnd, cy - headHalf)
      ..lineTo(w, cy)
      ..lineTo(shaftEnd, cy + headHalf)
      ..lineTo(shaftEnd, cy + shaftHalf)
      ..lineTo(0, cy + shaftHalf)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (reversed) {
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SolidArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.reversed != reversed;
  }
}
