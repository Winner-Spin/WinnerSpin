import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../../../../core/widgets/money_text.dart';

const double bigWinCoinRainCycleProgress = 0.78;

class BigWinCoin {
  const BigWinCoin({
    required this.x,
    required this.startProgress,
    required this.fallDuration,
    required this.size,
    required this.sway,
  });

  final double x;
  final double startProgress;
  final double fallDuration;
  final double size;
  final double sway;
}

class BigWinCoinsPainter extends CustomPainter {
  BigWinCoinsPainter({required this.coins, required this.progress});

  final List<BigWinCoin> coins;
  final double progress;

  static const _rimDark = Color(0xFF8B5A00);
  static const _faceTop = Color(0xFFFFEB99);
  static const _faceBottom = Color(0xFFFFB627);
  static const _innerRing = Color(0xFFC8902B);
  static const _shineColor = Color(0xFFFFFDF0);
  static const _stampColor = Color(0xFFC8902B);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final cycleT = (progress + c.startProgress) % bigWinCoinRainCycleProgress;
      final localT = cycleT / c.fallDuration;
      if (localT > 1) continue;

      final cx = c.x * size.width + sin(localT * pi * 2) * c.sway;
      final cy = (-0.08 + 1.2 * localT) * size.height;

      final fadeIn = (localT * 6).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - localT) * 5).clamp(0.0, 1.0);
      final alpha = (fadeIn * fadeOut).clamp(0.0, 1.0);

      final r = c.size;
      final centre = Offset(cx, cy);

      canvas.drawCircle(
        centre,
        r,
        Paint()..color = _rimDark.withValues(alpha: alpha),
      );

      canvas.drawCircle(
        centre,
        r * 0.86,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _faceTop.withValues(alpha: alpha),
              _faceBottom.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: r * 0.86)),
      );

      canvas.drawCircle(
        centre,
        r * 0.74,
        Paint()
          ..color = _innerRing.withValues(alpha: alpha * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06,
      );

      final stampStyle = TextStyle(
        color: _stampColor.withValues(alpha: alpha * 0.9),
        fontSize: r * 1.25,
        fontWeight: FontWeight.w900,
        height: 1.0,
      );
      final stampSize = Size(r * 0.92, r * 1.30);
      canvas.save();
      canvas.translate(
        cx - stampSize.width / 2,
        cy - stampSize.height / 2 + 1.1,
      );
      MoneySymbolPainter(
        style: stampStyle,
        lineYOffset: 1.45,
        lineTopExtend: 0.9,
      ).paint(canvas, stampSize);
      canvas.restore();

      canvas.drawCircle(
        Offset(cx - r * 0.32, cy - r * 0.32),
        r * 0.22,
        Paint()..color = _shineColor.withValues(alpha: alpha * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BigWinCoinsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
