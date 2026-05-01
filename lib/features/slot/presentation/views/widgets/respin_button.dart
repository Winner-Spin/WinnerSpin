import 'dart:math' as math;

import 'package:flutter/material.dart';

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
    this.opacity = 0.5,
  });

  @override
  State<RespinButton> createState() => _RespinButtonState();
}

class _RespinButtonState extends State<RespinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _active = !_active);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final iconClr = widget.iconColor ?? const Color(0xFFFAF6EE);
    final op = widget.opacity.clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scale,
        // Layer-cache the heavy decoration (shadow blur + 3 radial gradients
        // + custom-paint icons) so neighbor repaints in the parent Stack
        // — slot-grid cascades, reel drop-ins — don't re-rasterize this tree.
        child: RepaintBoundary(
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x661A1310),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                ),
                // Outer and inner share a warm taupe hue; lower alpha on
                // the outer layer lets the background bleed through to read
                // as a halo ring.
                Container(
                  width: s,
                  height: s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      radius: 1.0,
                      colors: [
                        Color(0x737A6450),
                        Color(0x805C4A3D),
                        Color(0x8C42342A),
                      ],
                      stops: [0.0, 0.65, 1.0],
                    ),
                  ),
                ),
                Container(
                  width: s * 0.87,
                  height: s * 0.87,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.15, -0.25),
                      radius: 1.0,
                      colors: [
                        const Color(0xFF5A4A3F).withValues(alpha: op - 0.05),
                        const Color(0xFF3D2F26).withValues(alpha: op + 0.06),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: s * 0.20,
                  top: s * 0.16,
                  child: IgnorePointer(
                    child: Container(
                      width: s * 0.38,
                      height: s * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: s * 0.74,
                  height: s * 0.74,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: _active
                        ? _StopIcon(
                            key: const ValueKey('stop'),
                            size: s * 0.74,
                            color: const Color(0xFFDC3D3D),
                          )
                        : _ArrowsIcon(
                            key: const ValueKey('arrows'),
                            size: s * 0.74,
                            color: iconClr,
                          ),
                  ),
                ),
              ],
            ),
          ),
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
