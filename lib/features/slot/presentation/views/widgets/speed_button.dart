import 'dart:ui';
import 'package:flutter/material.dart';

class SpeedButton extends StatefulWidget {
  final int level;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const SpeedButton({
    super.key,
    required this.level,
    this.onTap,
    this.width = 46,
    this.height = 28,
  });

  @override
  State<SpeedButton> createState() => _SpeedButtonState();
}

class _SpeedButtonState extends State<SpeedButton> {
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
                    size: const Size(24, 13),
                    painter: SpeedIconPainter(level: widget.level),
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

class SpeedIconPainter extends CustomPainter {
  final int level;

  const SpeedIconPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final activeColor = Colors.white.withValues(alpha: 0.92);
    final inactiveColor = Colors.white.withValues(alpha: 0.45);

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.45
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    void drawChevron(double x, int chevIndex) {
      const double topY = 2.5;
      const double centerY = 6.5;
      const double bottomY = 10.5;

      final Offset topStart = Offset(x, topY);
      final Offset tip = Offset(x + 4.7, centerY);
      final Offset bottomStart = Offset(x, bottomY);

      final paint = Paint()
        ..color = chevIndex <= level ? activeColor : inactiveColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.35
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      canvas.save();
      canvas.translate(0.45, 0.55);
      canvas.drawLine(topStart, tip, shadowPaint);
      canvas.drawLine(bottomStart, tip, shadowPaint);
      canvas.restore();

      canvas.drawLine(topStart, tip, paint);
      canvas.drawLine(bottomStart, tip, paint);
    }

    drawChevron(2.5, 1);
    drawChevron(8.5, 2);
    drawChevron(14.5, 3);
  }

  @override
  bool shouldRepaint(covariant SpeedIconPainter oldDelegate) {
    return oldDelegate.level != level;
  }
}
