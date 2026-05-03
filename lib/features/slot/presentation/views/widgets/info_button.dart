import 'dart:ui';

import 'package:flutter/material.dart';

class InfoButton extends StatefulWidget {
  final VoidCallback? onTap;
  final double width;
  final double height;

  const InfoButton({
    super.key,
    this.onTap,
    this.width = 70,
    this.height = 42,
  });

  @override
  State<InfoButton> createState() => _InfoButtonState();
}

class _InfoButtonState extends State<InfoButton> {
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
      topRight: cornerRadius,
      bottomRight: cornerRadius,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        alignment: Alignment.centerLeft,
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
                    size: const Size(17, 22),
                    painter: InfoIconPainter(
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

class InfoIconPainter extends CustomPainter {
  final Color color;

  const InfoIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final dotRadius = w * 0.18;
    final dotCY = h * 0.13;
    canvas.drawCircle(Offset(cx, dotCY), dotRadius, paint);

    final stemTop = h * 0.34;
    final stemBot = h * 0.92;
    final stemWidth = w * 0.30;
    final stemRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        cx - stemWidth / 2,
        stemTop,
        cx + stemWidth / 2,
        stemBot,
      ),
      Radius.circular(stemWidth / 2),
    );
    canvas.drawRRect(stemRect, paint);
  }

  @override
  bool shouldRepaint(covariant InfoIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
