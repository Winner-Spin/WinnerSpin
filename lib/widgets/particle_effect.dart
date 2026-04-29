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

class ParticleEffect extends StatefulWidget {
  final Widget child;
  final bool active;

  const ParticleEffect({super.key, required this.child, required this.active});

  @override
  State<ParticleEffect> createState() => _ParticleEffectState();
}

class _ParticleEffectState extends State<ParticleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<Particle> particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16), // ~60fps ticker
    )..addListener(_updateParticles);
  }

  @override
  void didUpdateWidget(ParticleEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sadece butonu aktif edince (false'dan true'ya geçerken) 1 saniyelik patlama oluştur.
    if (widget.active && !oldWidget.active) {
      _triggerBurst();
    }
  }

  void _triggerBurst() {
    // 50 adet parçacık oluştur. (Yaklaşık 1 saniye içinde sönüp kaybolacaklar)
    for (int i = 0; i < 50; i++) {
      double x, y;
      
      // Kenarlardan (Edge) çıkacak şekilde başlangıç pozisyonu ayarla
      if (_random.nextBool()) {
        x = _random.nextDouble();
        y = _random.nextBool() ? 0.0 : 1.0;
      } else {
        x = _random.nextBool() ? 0.0 : 1.0;
        y = _random.nextDouble();
      }

      // Dışarıya doğru saçılma hızı (Outward velocity)
      double vx = (x - 0.5) * (_random.nextDouble() * 0.12 + 0.02);
      double vy = (y - 0.5) * (_random.nextDouble() * 0.12 + 0.02);

      particles.add(Particle(
        x: x,
        y: y,
        vx: vx,
        vy: vy,
        life: 1.0,
        color: Colors.lightGreenAccent.shade400.withValues(alpha: _random.nextDouble() * 0.5 + 0.5),
        size: _random.nextDouble() * 4 + 2,
      ));
    }
    
    // Ticker çalışmıyorsa başlat
    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _updateParticles() {
    if (!mounted) return;
    
    // Var olan parçacıkları güncelle
    for (int i = particles.length - 1; i >= 0; i--) {
      final p = particles[i];
      p.x += p.vx;
      p.y += p.vy;
      p.life -= 0.015; // Her karede ömrü azalır, ortalama ~1 saniyede biter (60 fps * 0.015 = 0.9 sn)
      if (p.life <= 0) {
        particles.removeAt(i);
      }
    }

    // Tüm parçacıklar kaybolduysa animasyonu durdur (1 saniye doldu demektir)
    if (particles.isEmpty && _controller.isAnimating) {
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
    return CustomPaint(
      foregroundPainter: _ParticlePainter(particles),
      child: widget.child,
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  _ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      if (p.life <= 0) continue;
      
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size,
        paint,
      );
      
      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: p.life * 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
        ..style = PaintingStyle.fill;
        
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
        p.size * 1.5,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}
