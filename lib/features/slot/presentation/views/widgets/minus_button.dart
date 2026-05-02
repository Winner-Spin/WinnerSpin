import 'package:flutter/material.dart';

import 'translucent_circle_button.dart';

class MinusButton extends StatelessWidget {
  final double size;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double opacity;

  const MinusButton({
    super.key,
    this.size = 60,
    this.onTap,
    this.iconColor,
    this.opacity = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    final iconClr = iconColor ?? const Color(0xFFFAF6EE);
    final iconSize = size * 0.70;
    return TranslucentCircleButton(
      size: size,
      onTap: onTap,
      opacity: opacity,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: const Offset(0, 1.2),
            child: CustomPaint(
              size: Size(iconSize, iconSize),
              painter: _MinusPainter(
                color: Colors.black.withValues(alpha: 0.36),
              ),
            ),
          ),
          CustomPaint(
            size: Size(iconSize, iconSize),
            painter: _MinusPainter(color: iconClr),
          ),
        ],
      ),
    );
  }
}

class _MinusPainter extends CustomPainter {
  final Color color;

  const _MinusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.11;
    final inset = w * 0.22;
    final cy = w / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(inset, cy), Offset(w - inset, cy), paint);
  }

  @override
  bool shouldRepaint(_MinusPainter old) => old.color != color;
}
