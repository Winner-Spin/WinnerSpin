import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../audio/ui_click_sound.dart';

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
      onTap: widget.onTap == null
          ? null
          : () {
              UiClickSound.play();
              widget.onTap?.call();
            },
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        alignment: Alignment.centerRight,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: RepaintBoundary(
          child: ClipRRect(
            borderRadius: borderRadius,
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

    final gearPath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: bodyR));

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;

      final toothRect = Rect.fromCenter(
        center: Offset(0, -tipR + toothH / 2),
        width: toothW,
        height: toothH,
      );

      final toothPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(toothRect, Radius.circular(toothW * 0.28)),
        );

      final cosA = math.cos(angle);
      final sinA = math.sin(angle);
      final matrix = Float64List.fromList([
        cosA,
        sinA,
        0.0,
        0.0,
        -sinA,
        cosA,
        0.0,
        0.0,
        0.0,
        0.0,
        1.0,
        0.0,
        cx,
        cy,
        0.0,
        1.0,
      ]);

      gearPath.addPath(toothPath, Offset.zero, matrix4: matrix);
    }

    final holePath = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: holeR));
    final finalPath = Path.combine(
      PathOperation.difference,
      gearPath,
      holePath,
    );

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant GearIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
