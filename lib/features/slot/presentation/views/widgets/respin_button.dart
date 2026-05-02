import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'translucent_circle_button.dart';

class RespinButton extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double opacity;

  const RespinButton({
    super.key,
    this.size = 92,
    this.onTap,
    this.iconColor,
    this.opacity = 0.75,
  });

  @override
  State<RespinButton> createState() => _RespinButtonState();
}

class _RespinButtonState extends State<RespinButton> {
  bool _active = false;

  void _handleTap() {
    setState(() => _active = !_active);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final iconClr = widget.iconColor ?? const Color(0xFFFAF6EE);
    final iconSize = s * 0.74;

    return TranslucentCircleButton(
      size: s,
      onTap: _handleTap,
      opacity: widget.opacity,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 160),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _active
            ? _StopIcon(
                key: const ValueKey('stop'),
                size: iconSize,
                color: const Color(0xFFDC3D3D),
              )
            : _ArrowsIcon(
                key: const ValueKey('arrows'),
                size: iconSize,
                color: iconClr,
              ),
      ),
    );
  }
}

class _ArrowsIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _ArrowsIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 1.5),
          child: CustomPaint(
            size: Size(size, size),
            painter: _RespinArrowsPainter(
              color: Colors.black.withValues(alpha: 0.36),
            ),
          ),
        ),
        CustomPaint(
          size: Size(size, size),
          painter: _RespinArrowsPainter(color: color),
        ),
      ],
    );
  }
}

class _StopIcon extends StatelessWidget {
  final double size;
  final Color color;

  const _StopIcon({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.translate(
          offset: const Offset(0, 1.5),
          child: CustomPaint(
            size: Size(size, size),
            painter: _StopSquarePainter(
              color: Colors.black.withValues(alpha: 0.32),
            ),
          ),
        ),
        CustomPaint(
          size: Size(size, size),
          painter: _StopSquarePainter(color: color),
        ),
      ],
    );
  }
}

class _RespinArrowsPainter extends CustomPainter {
  final Color color;

  const _RespinArrowsPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final center = Offset(w / 2, w / 2);
    final radius = w * 0.34;
    final stroke = w * 0.13;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Two 130° arcs with 50° gaps on each side so the icon reads as two
    // distinct refresh arrows, not a closed spinner ring.
    const sweep = math.pi * 13 / 18;
    const topStart = math.pi * 41 / 36;
    const botStart = math.pi * 77 / 36;

    _drawArrow(
      canvas,
      strokePaint,
      fillPaint,
      rect,
      center,
      radius,
      stroke,
      topStart,
      sweep,
    );
    _drawArrow(
      canvas,
      strokePaint,
      fillPaint,
      rect,
      center,
      radius,
      stroke,
      botStart,
      sweep,
    );
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
  bool shouldRepaint(_RespinArrowsPainter old) => old.color != color;
}

class _StopSquarePainter extends CustomPainter {
  final Color color;

  const _StopSquarePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.05;
    final inset = w * 0.27;

    final rect = Rect.fromLTRB(inset, inset, w - inset, w - inset);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.05));

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_StopSquarePainter old) => old.color != color;
}
