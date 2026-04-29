import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  Color color;
  double size;

  Particle({
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
  final double size; // Bounding box size (e.g. 200x200)
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
  late AnimationController _controller;
  List<Particle> particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..addListener(_updateParticles);

    if (widget.active) {
      _triggerBurst();
    }
  }

  @override
  void didUpdateWidget(SymbolExplosionEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _triggerBurst();
    }
  }

  void _triggerBurst() {
    particles.clear();
    // Generate 40 golden/magical particles
    for (int i = 0; i < 40; i++) {
      // Start near center (0.5, 0.5)
      double angle = _random.nextDouble() * 2 * pi;
      double speed = (_random.nextDouble() * 0.08 + 0.02) * widget.speedMultiplier; // outward velocity

      double vx = cos(angle) * speed;
      double vy = sin(angle) * speed;

      // Golden palette
      Color pColor = _random.nextBool()
          ? Colors.yellowAccent.shade400
          : Colors.orangeAccent.shade200;

      particles.add(Particle(
        x: 0.5, // Center of the 200x200 box
        y: 0.5,
        vx: vx,
        vy: vy,
        life: 1.0,
        color: pColor.withValues(alpha: _random.nextDouble() * 0.5 + 0.5),
        size: _random.nextDouble() * 6 + 2, // 2 to 8 px
      ));
    }

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _updateParticles() {
    if (!mounted) return;

    bool alive = false;
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      
      // Gravity / Drag
      p.vy += 0.002 * widget.speedMultiplier; // slight downward gravity
      p.vx *= 0.95; // drag
      p.vy *= 0.95; // drag
      
      p.life -= 0.02 * widget.speedMultiplier; // 50 frames life (~800ms)
      
      if (p.life <= 0) {
        particles.removeAt(i);
      } else {
        alive = true;
      }
    }

    if (!alive && _controller.isAnimating) {
      _controller.stop();
    }

    setState(() {});
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
      child: CustomPaint(
        painter: _ExplosionPainter(particles),
      ),
    );
  }
}

class _ExplosionPainter extends CustomPainter {
  final List<Particle> particles;

  _ExplosionPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.life <= 0) continue;

      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * p.life, // shrink as they die
        paint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.life * 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * 2.5 * p.life,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExplosionPainter oldDelegate) => true;
}
