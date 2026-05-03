import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/enums/symbol_tier.dart';
import '../../../domain/models/symbol_registry.dart';

/// A single grid cell that handles four cascade-tumble effects independently
/// of the column-wide spin in [SlotReel]:
///   • Winning glow when [isFading] flips to true (animated tier-coloured
///     halo + rotating border).
///   • Symbol scale pulse (impact bounce → settle → fade with size).
///   • Particle burst — gold sparks radiate outward as the symbol fades.
///   • Drop-in from above when [path] changes (new symbol falls into place).
///
/// Used by [SlotReel] only in the static (post-drop-in) state. During the
/// initial reel spin, the column-wide drop-out / drop-in animation runs
/// instead.
class TumbleCell extends StatefulWidget {
  final String path;
  final bool isFading;
  final double itemH;
  final int speedMultiplier;

  const TumbleCell({
    super.key,
    required this.path,
    required this.isFading,
    required this.itemH,
    this.speedMultiplier = 1,
  });

  @override
  State<TumbleCell> createState() => _TumbleCellState();
}

class _TumbleCellState extends State<TumbleCell> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _dropController;
  late final AnimationController _glowController;
  late final AnimationController _burstController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _dropAnimation;
  late final Animation<double> _glowIntensity;
  late final Animation<double> _scalePulse;

  // Regenerated on each fade event so consecutive wins on the same cell
  // get distinct burst patterns; palette refreshes when [path] changes.
  late List<_Particle> _particles;
  late _GlowPalette _palette;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // Opacity holds full through the first half — the player needs to see
    // the gold glow before the symbol fades.
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );
    _glowIntensity = CurvedAnimation(
      parent: _fadeController,
      curve: const _GlowCurve(),
    );
    _scalePulse = CurvedAnimation(
      parent: _fadeController,
      curve: const _ScalePulseCurve(),
    );
    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.easeOutCubic,
    );

    _particles = _generateParticles();
    _palette = _GlowPalette.forPath(widget.path);

    _dropController.value = 1.0;

    // Stop the rotating glow once the fade completes; otherwise the
    // controller keeps repeating at 60 Hz forever, ticking AnimatedBuilder
    // even though the cell is fully transparent and the painter early-exits.
    _fadeController.addStatusListener(_handleFadeStatus);

    // If the cell is created already in fading state (first tumble after spin),
    // animate the fade instead of snapping to fully transparent — the player
    // needs to see the symbol + glow before it disappears.
    if (widget.isFading) {
      _fadeController.forward(from: 0.0);
      _glowController.repeat();
      _burstController.forward(from: 0.0);
    } else {
      _fadeController.value = 0.0;
    }
  }

  void _handleFadeStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _glowController.isAnimating) {
      _glowController.stop();
      _glowController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(TumbleCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.path != oldWidget.path) {
      _fadeController.value = 0.0;
      _glowController.stop();
      _glowController.value = 0.0;
      _dropController.forward(from: 0.0);
      _palette = _GlowPalette.forPath(widget.path);
      return;
    }

    if (widget.isFading != oldWidget.isFading) {
      if (widget.isFading) {
        _particles = _generateParticles();
        _fadeController.forward(from: 0.0);
        _glowController.repeat();
        _burstController.forward(from: 0.0);
      } else {
        _fadeController.value = 0.0;
        _glowController.stop();
        _glowController.value = 0.0;
        _burstController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.removeStatusListener(_handleFadeStatus);
    _fadeController.dispose();
    _dropController.dispose();
    _glowController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final rng = math.Random();
    return List.generate(11, (_) => _Particle.random(rng));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _dropAnimation,
        _glowIntensity,
        _scalePulse,
        _glowController,
        _burstController,
      ]),
      builder: (context, child) {
        final dy = (1.0 - _dropAnimation.value) * -widget.itemH;
        final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);
        final glow = _glowIntensity.value;
        final scale = 1.0 + _scalePulse.value * 0.15;
        // Particles run in the second half (after the impact peak), in sync
        // with the symbol fade-out so the burst trails the celebration.
        final particleProgress = ((_fadeController.value - 0.4) / 0.6).clamp(
          0.0,
          1.0,
        );

        return Transform.translate(
          offset: Offset(0, dy),
          child: Stack(
            // Allow particles to fly past the cell bounds without being
            // clipped — the burst feels far more dramatic if sparks escape
            // the cell box and trail through the gap to the next column.
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Glow stays outside the Opacity wrapper so the halo remains
              // visible while the symbol underneath fades.
              if (glow > 0)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _WinningGlowPainter(
                      rotation: _glowController.value,
                      intensity: glow,
                      palette: _palette,
                    ),
                  ),
                ),
              if (particleProgress > 0)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _ParticleBurstPainter(
                      progress: particleProgress,
                      particles: _particles,
                      palette: _palette,
                    ),
                  ),
                ),
              Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              ),
            ],
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Image.asset(
          widget.path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          cacheWidth: 256,
        ),
      ),
    );
  }
}

/// Glow intensity curve: ramps up over first 25%, holds full through 75%,
/// then matches the symbol fade-out (linear taper to 0).
class _GlowCurve extends Curve {
  const _GlowCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.25) return t / 0.25;
    if (t < 0.75) return 1.0;
    return 1.0 - ((t - 0.75) / 0.25);
  }
}

/// Scale pulse: bounces from 0 → 1 (overshoot) over the first 30%, settles
/// back to 0 by 50%, then stays at 0 for the fade-out half.
class _ScalePulseCurve extends Curve {
  const _ScalePulseCurve();

  @override
  double transformInternal(double t) {
    if (t < 0.3) return t / 0.3;
    if (t < 0.5) return 1.0 - ((t - 0.3) / 0.2);
    return 0.0;
  }
}

/// Per-tier colour palette. Picked so each tier reads instantly on the
/// grid — low symbols stay yellow-gold, high symbols push toward amber-red
/// for a premium feel, multipliers go purple, scatters go cyan.
class _GlowPalette {
  final Color halo;
  final List<Color> sweep;
  final Color sparkle;
  final Color particle;

  const _GlowPalette({
    required this.halo,
    required this.sweep,
    required this.sparkle,
    required this.particle,
  });

  static _GlowPalette forPath(String path) {
    final tier = SymbolRegistry.byPath(path)?.tier;
    switch (tier) {
      case SymbolTier.low:
        return const _GlowPalette(
          halo: Color(0xFFFFC107),
          sweep: [
            Color(0xFFFFB300),
            Color(0xFFFFE082),
            Color(0xFFFFFFFF),
            Color(0xFFFFE082),
            Color(0xFFFFB300),
          ],
          sparkle: Color(0xFFFFF8E1),
          particle: Color(0xFFFFD54F),
        );
      case SymbolTier.mid:
        return const _GlowPalette(
          halo: Color(0xFFFF9800),
          sweep: [
            Color(0xFFEF6C00),
            Color(0xFFFFB74D),
            Color(0xFFFFFFFF),
            Color(0xFFFFB74D),
            Color(0xFFEF6C00),
          ],
          sparkle: Color(0xFFFFE0B2),
          particle: Color(0xFFFFA726),
        );
      case SymbolTier.high:
        return const _GlowPalette(
          halo: Color(0xFFFF5722),
          sweep: [
            Color(0xFFD84315),
            Color(0xFFFF8A65),
            Color(0xFFFFFFFF),
            Color(0xFFFF8A65),
            Color(0xFFD84315),
          ],
          sparkle: Color(0xFFFFCCBC),
          particle: Color(0xFFFF7043),
        );
      case SymbolTier.multiplier:
        return const _GlowPalette(
          halo: Color(0xFFAB47BC),
          sweep: [
            Color(0xFF6A1B9A),
            Color(0xFFCE93D8),
            Color(0xFFFFFFFF),
            Color(0xFFCE93D8),
            Color(0xFF6A1B9A),
          ],
          sparkle: Color(0xFFE1BEE7),
          particle: Color(0xFFBA68C8),
        );
      case SymbolTier.scatter:
        return const _GlowPalette(
          halo: Color(0xFF00BCD4),
          sweep: [
            Color(0xFF006064),
            Color(0xFF80DEEA),
            Color(0xFFFFFFFF),
            Color(0xFF80DEEA),
            Color(0xFF006064),
          ],
          sparkle: Color(0xFFB2EBF2),
          particle: Color(0xFF4DD0E1),
        );
      case null:
        return const _GlowPalette(
          halo: Color(0xFFFFB300),
          sweep: [
            Color(0xFFFFC107),
            Color(0xFFFFE082),
            Color(0xFFFFFFFF),
            Color(0xFFFFE082),
            Color(0xFFFFC107),
          ],
          sparkle: Color(0xFFFFF8E1),
          particle: Color(0xFFFFD54F),
        );
    }
  }
}

/// One radiating gold spark. Direction + speed picked at construction time
/// so every cell burst has a distinct fan pattern.
class _Particle {
  final double angle;
  final double speed;
  final double size;
  final double startProgress;

  const _Particle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.startProgress,
  });

  factory _Particle.random(math.Random rng) {
    return _Particle(
      angle: rng.nextDouble() * 2 * math.pi,
      speed: 0.7 + rng.nextDouble() * 0.5,
      size: 5.0 + rng.nextDouble() * 4.0,
      // Stagger starts so the burst feels organic, not a single ring.
      startProgress: rng.nextDouble() * 0.2,
    );
  }
}

/// Paints the winning-cell highlight: an outer halo, a rotating
/// gradient border, and an inner sparkle accent. Driven by [rotation]
/// (loops 0→1), [intensity] (0→1 fade-in/out), and a [palette] picked
/// from the symbol's tier.
class _WinningGlowPainter extends CustomPainter {
  final double rotation;
  final double intensity;
  final _GlowPalette palette;

  _WinningGlowPainter({
    required this.rotation,
    required this.intensity,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final cellRect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(2);
    const radius = Radius.circular(8);
    final cellRRect = RRect.fromRectAndRadius(cellRect, radius);

    // Halo blur radius is the dominant per-cell GPU cost — saveLayer +
    // Gaussian. Capped at 4 so a cluster-win cascade stays within the
    // frame budget; visual difference vs. 10 is a slightly tighter halo.
    final haloPaint = Paint()
      ..color = palette.halo.withValues(alpha: 0.55 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * intensity);
    canvas.drawRRect(cellRRect, haloPaint);

    final sweep = SweepGradient(
      center: Alignment.center,
      colors: palette.sweep,
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
      transform: GradientRotation(rotation * 2 * math.pi),
    );
    final borderPaint = Paint()
      ..shader = sweep.createShader(cellRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5 * intensity
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(cellRRect, borderPaint);

    final innerRRect = RRect.fromRectAndRadius(cellRect.deflate(2), radius);
    final innerPaint = Paint()
      ..color = palette.sparkle.withValues(alpha: 0.45 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(innerRRect, innerPaint);
  }

  @override
  bool shouldRepaint(_WinningGlowPainter old) =>
      old.rotation != rotation ||
      old.intensity != intensity ||
      old.palette != palette;
}

/// Paints the radiating spark burst. Each particle starts near the cell
/// centre, accelerates outward along its [angle], shrinks, and fades.
class _ParticleBurstPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final _GlowPalette palette;

  _ParticleBurstPainter({
    required this.progress,
    required this.particles,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.max(size.width, size.height);

    for (final p in particles) {
      final localT = ((progress - p.startProgress) / (1.0 - p.startProgress))
          .clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final distance = localT * p.speed * maxDistance;
      final pos = Offset(
        center.dx + math.cos(p.angle) * distance,
        center.dy + math.sin(p.angle) * distance,
      );
      // Fade + shrink in the back half of the particle's life.
      final alpha = (1.0 - localT).clamp(0.0, 1.0);
      final radius = p.size * (1.0 - localT * 0.5);

      // Soft falloff via a radial gradient shader instead of MaskFilter.blur:
      // shaders run at fragment level (no saveLayer), whereas a per-particle
      // Gaussian blur on 11 particles × multiple fading cells dominated the
      // GPU budget during a cluster-win cascade.
      final haloPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.particle.withValues(alpha: alpha),
            palette.particle.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: pos, radius: radius * 1.6));
      canvas.drawCircle(pos, radius * 1.6, haloPaint);

      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha * 0.95);
      canvas.drawCircle(pos, radius * 0.55, corePaint);
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) =>
      old.progress != progress || old.palette != palette;
}
