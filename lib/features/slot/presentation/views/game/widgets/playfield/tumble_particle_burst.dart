import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tumble_glow_palette.dart';

class TumbleParticle {
  const TumbleParticle({
    required this.originX,
    required this.originY,
    required this.angle,
    required this.speed,
    required this.size,
    required this.startProgress,
    required this.spin,
    required this.colorIndex,
  });

  final double originX;
  final double originY;
  final double angle;
  final double speed;
  final double size;
  final double startProgress;
  final double spin;
  final int colorIndex;

  factory TumbleParticle.random(math.Random rng) {
    final originAngle = rng.nextDouble() * 2 * math.pi;
    final originRadius = math.sqrt(rng.nextDouble());
    final originX = math.cos(originAngle) * originRadius;
    final originY = math.sin(originAngle) * originRadius;
    final outwardAngle = math.atan2(originY, originX);

    return TumbleParticle(
      originX: originX,
      originY: originY,
      angle: outwardAngle + (rng.nextDouble() - 0.5) * 1.25,
      speed: 0.20 + rng.nextDouble() * 0.34,
      size: 1.1 + rng.nextDouble() * 2.2,
      startProgress: rng.nextDouble() * 0.18,
      spin: (rng.nextDouble() * 2 - 1) * math.pi * 1.7,
      colorIndex: rng.nextInt(5),
    );
  }
}

class TumbleParticleBurstPainter extends CustomPainter {
  TumbleParticleBurstPainter({
    required this.progress,
    required this.particles,
    required this.palette,
  });

  final double progress;
  final List<TumbleParticle> particles;
  final TumbleGlowPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.max(size.width, size.height);
    final originRadius = math.min(size.width, size.height) * 0.24;

    for (final p in particles) {
      final localT = ((progress - p.startProgress) / (1.0 - p.startProgress))
          .clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localT);
      final origin = Offset(
        center.dx + p.originX * originRadius,
        center.dy + p.originY * originRadius,
      );
      final distance = eased * p.speed * maxDistance * 0.58;
      final pos = Offset(
        origin.dx + math.cos(p.angle) * distance,
        origin.dy +
            math.sin(p.angle) * distance +
            eased * eased * size.height * 0.18,
      );
      final alpha = (1.0 - localT).clamp(0.0, 1.0);
      final radius = p.size * (1.0 - localT * 0.35);
      final color = _particleColor(p.colorIndex).withValues(alpha: alpha);

      final dustPaint = Paint()..color = color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(pos, radius * 0.55, dustPaint);

      if (p.colorIndex == 1 || p.colorIndex == 3) {
        final fleckPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.55);
        final offset = Offset(
          math.cos(p.angle + p.spin) * radius * 0.65,
          math.sin(p.angle + p.spin) * radius * 0.65,
        );
        canvas.drawCircle(pos + offset, radius * 0.28, fleckPaint);
      }
    }
  }

  Color _particleColor(int index) {
    if (index == 0) return palette.particle;
    if (index == 1) return palette.sparkle;
    return palette.sweep[index % palette.sweep.length];
  }

  @override
  bool shouldRepaint(covariant TumbleParticleBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.palette != palette;
  }
}
