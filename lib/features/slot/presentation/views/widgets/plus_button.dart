import 'package:flutter/material.dart';

class PlusButton extends StatefulWidget {
  final double size;
  final VoidCallback? onTap;
  final Color? iconColor;
  final double opacity;

  const PlusButton({
    super.key,
    this.size = 60,
    this.onTap,
    this.iconColor,
    this.opacity = 0.5,
  });

  @override
  State<PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<PlusButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
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
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
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
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Transform.translate(
                      offset: const Offset(0, 1.2),
                      child: CustomPaint(
                        size: Size(s * 0.74, s * 0.74),
                        painter: _PlusPainter(
                          color: Colors.black.withValues(alpha: 0.36),
                        ),
                      ),
                    ),
                    CustomPaint(
                      size: Size(s * 0.74, s * 0.74),
                      painter: _PlusPainter(color: iconClr),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  final Color color;

  const _PlusPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.11;
    final inset = w * 0.22;
    final c = w / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(inset, c), Offset(w - inset, c), paint);
    canvas.drawLine(Offset(c, inset), Offset(c, w - inset), paint);
  }

  @override
  bool shouldRepaint(_PlusPainter old) => old.color != color;
}
