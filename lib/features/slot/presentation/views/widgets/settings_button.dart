import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

class SettingsButton extends StatefulWidget {
  final VoidCallback? onTap;
  final double width;
  final double height;

  const SettingsButton({
    super.key,
    this.onTap,
    this.width = 70,
    this.height = 42,
  });

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width;
    final h = widget.height;
    final cornerRadius = Radius.circular(h / 2);
    final borderRadius = BorderRadius.only(
      topLeft: cornerRadius,
      bottomLeft: cornerRadius,
    );

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
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.8, sigmaY: 1.8),
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
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
                    painter: GearIconPainter(
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

class GearIconPainter extends CustomPainter {
  final Color color;

  const GearIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bodyR = w * 0.30;
    final tipR = w * 0.46;
    final toothW = w * 0.17;
    final toothH = tipR - bodyR + w * 0.05;
    final holeR = w * 0.13;

    canvas.saveLayer(Rect.fromLTWH(0, 0, w, h), Paint());

    canvas.drawCircle(Offset(cx, cy), bodyR, paint);

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, -tipR + toothH / 2),
            width: toothW,
            height: toothH,
          ),
          Radius.circular(toothW * 0.28),
        ),
        paint,
      );
      canvas.restore();
    }

    canvas.drawCircle(
      Offset(cx, cy),
      holeR,
      Paint()..blendMode = BlendMode.clear,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GearIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
