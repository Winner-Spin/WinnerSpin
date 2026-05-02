import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class AutoSpinButton extends StatefulWidget {
  final VoidCallback? onTap;
  final double width;
  final double height;

  const AutoSpinButton({
    super.key,
    this.onTap,
    this.width = 75,
    this.height = 42,
  });

  @override
  State<AutoSpinButton> createState() => _AutoSpinButtonState();
}

class _AutoSpinButtonState extends State<AutoSpinButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.height / 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF2B211B).withValues(alpha: 0.58),
                      const Color(0xFF120C09).withValues(alpha: 0.62),
                      Colors.black.withValues(alpha: 0.46),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: CustomPaint(
                    size: const Size(22, 22),
                    painter: AutoSpinIconPainter(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AutoSpinIconPainter extends CustomPainter {
  final Color color;

  const AutoSpinIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final ringRadius = w * 0.40;
    final stroke = w * 0.12;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final ringRect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: ringRadius,
    );

    const sweep = math.pi * 13 / 18;
    const topStart = math.pi * 41 / 36;
    const botStart = math.pi * 77 / 36;

    _drawArrow(canvas, strokePaint, fillPaint, ringRect,
        Offset(cx, cy), ringRadius, stroke, topStart, sweep);
    _drawArrow(canvas, strokePaint, fillPaint, ringRect,
        Offset(cx, cy), ringRadius, stroke, botStart, sweep);

    final triangleW = w * 0.27;
    final triangleH = w * 0.30;
    final tLeftX = cx - triangleW / 3;
    final tRightX = cx + 2 * triangleW / 3;
    final tTopY = cy - triangleH / 2;
    final tBotY = cy + triangleH / 2;

    final triangle = Path()
      ..moveTo(tLeftX, tTopY)
      ..lineTo(tRightX, cy)
      ..lineTo(tLeftX, tBotY)
      ..close();

    canvas.drawPath(triangle, fillPaint);
  }

  void _drawArrow(
    Canvas canvas,
    Paint stroke,
    Paint fill,
    Rect rect,
    Offset center,
    double radius,
    double strokeW,
    double startAngle,
    double sweepAngle,
  ) {
    canvas.drawArc(rect, startAngle, sweepAngle, false, stroke);

    final tail = Offset(
      center.dx + math.cos(startAngle) * radius,
      center.dy + math.sin(startAngle) * radius,
    );
    canvas.drawCircle(tail, strokeW / 2, fill);

    final endAngle = startAngle + sweepAngle;
    final arcEnd = Offset(
      center.dx + math.cos(endAngle) * radius,
      center.dy + math.sin(endAngle) * radius,
    );
    final dir = Offset(-math.sin(endAngle), math.cos(endAngle));
    final perp = Offset(-dir.dy, dir.dx);

    final tipPt = arcEnd + dir * strokeW * 1.4;
    final baseL = arcEnd - perp * strokeW * 0.95;
    final baseR = arcEnd + perp * strokeW * 0.95;

    canvas.drawPath(
      Path()
        ..moveTo(tipPt.dx, tipPt.dy)
        ..lineTo(baseL.dx, baseL.dy)
        ..lineTo(baseR.dx, baseR.dy)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant AutoSpinIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
