import 'package:flutter/material.dart';

/// The Instagram glyph, drawn as a vector.
///
/// Same approach as [GitHubMark]: a painted outline rather than a bundled
/// image, so it stays crisp at any size and takes the surrounding link colour
/// without pulling in an SVG dependency.
class InstagramMark extends StatelessWidget {
  const InstagramMark({super.key, this.size = 16, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _InstagramMarkPainter(color ?? const Color(0xFF2C2530)),
      ),
    );
  }
}

class _InstagramMarkPainter extends CustomPainter {
  const _InstagramMarkPainter(this.color);

  final Color color;

  /// Glyph geometry, authored against a 16x16 box and scaled to fit.
  static const _designSize = 16.0;
  static const _strokeWidth = 1.6;

  /// The rounded camera body and the lens ring, built once for the whole app:
  /// only the colour and the scale ever change.
  static final Path _outlinePath = _buildOutlinePath();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _designSize;
    final paint = Paint()..color = color;

    canvas
      ..save()
      ..translate(
        (size.width - _designSize * scale) / 2,
        (size.height - _designSize * scale) / 2,
      )
      ..scale(scale)
      // Body and lens are strokes; the flash is a solid dot, so it needs its
      // own paint style rather than joining the shared path.
      ..drawPath(
        _outlinePath,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawCircle(const Offset(11.55, 4.45), 1.05, paint)
      ..restore();
  }

  static Path _buildOutlinePath() {
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTRB(0.8, 0.8, 15.2, 15.2),
          const Radius.circular(4.4),
        ),
      )
      ..addOval(Rect.fromCircle(center: const Offset(8, 8), radius: 3.5));
  }

  @override
  bool shouldRepaint(_InstagramMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
