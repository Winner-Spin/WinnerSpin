import 'dart:math';
import 'package:flutter/material.dart';

class _Particle {
  double x, y, vx, vy, life;
  final Color color;
  final double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.color,
    required this.size,
  });
}

class SymbolExplosionEffect extends StatefulWidget {
  final bool active;
  final double size;
  final int speedMultiplier;

  const SymbolExplosionEffect({
    super.key,
    required this.active,
    required this.size,
    this.speedMultiplier = 1,
  });

  @override
  State<SymbolExplosionEffect> createState() => _SymbolExplosionEffectState();
}

class _SymbolExplosionEffectState extends State<SymbolExplosionEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    final int durationMs = (800 ~/ widget.speedMultiplier).clamp(250, 800);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    if (widget.active) {
      _spawnParticles();
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(SymbolExplosionEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _spawnParticles();
      _controller.forward(from: 0.0);
    }
  }

  void _spawnParticles() {
    _particles.clear();
    for (int i = 0; i < 40; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final speed = (_random.nextDouble() * 3.0 + 1.0) * widget.speedMultiplier;

      final pColor = _random.nextBool()
          ? const Color(0xFFFFFF00)
          : const Color(0xFFFFAB40);

      _particles.add(
        _Particle(
          x: 0.5,
          y: 0.5,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          life: 1.0,
          color: pColor.withValues(alpha: _random.nextDouble() * 0.5 + 0.5),
          size: _random.nextDouble() * 6 + 2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _ExplosionPainter(
              particles: _particles,
              progress: _controller.value,
              speedMultiplier: widget.speedMultiplier,
            ),
          );
        },
      ),
    );
  }
}

class _ExplosionPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final int speedMultiplier;

  _ExplosionPainter({
    required this.particles,
    required this.progress,
    required this.speedMultiplier,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress >= 1.0 || particles.isEmpty) return;

    for (final p in particles) {
      final life = (1.0 - progress).clamp(0.0, 1.0);
      if (life <= 0) continue;

      final t = Curves.easeOutCubic.transform(progress);
      final px = (p.x + p.vx * t * 0.12) * size.width;
      final py = (p.y + p.vy * t * 0.12 + t * t * 0.8) * size.height;

      final alpha = (p.color.a * life).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), p.size * life, paint);

      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(px, py), p.size * 2.5 * life, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter old) =>
      old.progress != progress;
}
