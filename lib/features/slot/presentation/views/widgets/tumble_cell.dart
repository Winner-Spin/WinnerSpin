import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A single grid cell that handles three cascade-tumble effects independently
/// of the column-wide spin in [SlotReel]:
///   • Winning glow when [isFading] flips to true (animated gold halo + border).
///   • Fade-out following the glow window (matched symbol disappears).
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

class _TumbleCellState extends State<TumbleCell>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _dropController;
  late final AnimationController _glowController;
  late final AnimationController _burstController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _dropAnimation;
  late final Animation<double> _glowIntensity;
  late final Animation<double> _burstScale;
  late final Animation<double> _burstRotation;

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
    _dropAnimation =
        CurvedAnimation(parent: _dropController, curve: Curves.easeOutCubic);

    // Scale: 1.0 → 1.35 → 1.0 (grow then shrink back)
    _burstScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _burstController,
      curve: Curves.easeInOut,
    ));

    // Rotation: slight wobble, -15° → +15° → 0°
    _burstRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -0.26), // ~-15°
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: -0.26, end: 0.26), // ~+15°
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.26, end: 0.0), // back to 0
        weight: 25,
      ),
    ]).animate(CurvedAnimation(
      parent: _burstController,
      curve: Curves.easeInOut,
    ));

    _dropController.value = 1.0;
    _fadeController.value = widget.isFading ? 1.0 : 0.0;
    if (widget.isFading) _glowController.repeat();
  }

  @override
  void didUpdateWidget(TumbleCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.path != oldWidget.path) {
      _fadeController.value = 0.0;
      _glowController.stop();
      _glowController.value = 0.0;
      _dropController.forward(from: 0.0);
      return;
    }

    if (widget.isFading != oldWidget.isFading) {
      if (widget.isFading) {
        _fadeController.forward(from: 0.0);
        _glowController.repeat();
        // Trigger burst effect only at 1x speed
        if (widget.speedMultiplier == 1) {
          _burstController.forward(from: 0.0);
        }
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
    _fadeController.dispose();
    _dropController.dispose();
    _glowController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _fadeAnimation,
        _dropAnimation,
        _glowIntensity,
        _glowController,
        _burstController,
      ]),
      builder: (context, child) {
        final dy = (1.0 - _dropAnimation.value) * -widget.itemH;
        final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);
        final glow = _glowIntensity.value;
        final scale = _burstScale.value;
        final rotation = _burstRotation.value;

        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.scale(
            scale: scale,
            child: Transform.rotate(
              angle: rotation,
              child: Stack(
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
                        ),
                      ),
                    ),
                  Opacity(opacity: opacity, child: child),
                ],
              ),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          widget.path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
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

/// Paints the winning-cell highlight: an outer amber halo, a rotating
/// gold-gradient border, and an inner sparkle accent. Driven by
/// [rotation] (loops 0→1) and [intensity] (0→1 fade-in/out).
class _WinningGlowPainter extends CustomPainter {
  final double rotation;
  final double intensity;

  _WinningGlowPainter({
    required this.rotation,
    required this.intensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final cellRect = Rect.fromLTWH(0, 0, size.width, size.height).deflate(2);
    const radius = Radius.circular(8);
    final cellRRect = RRect.fromRectAndRadius(cellRect, radius);

    final haloPaint = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.55 * intensity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 * intensity);
    canvas.drawRRect(cellRRect, haloPaint);

    final sweep = SweepGradient(
      center: Alignment.center,
      colors: const [
        Color(0xFFFFC107), // amber 700
        Color(0xFFFFE082), // amber 200
        Color(0xFFFFFFFF), // white sparkle
        Color(0xFFFFE082),
        Color(0xFFFFC107),
      ],
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
      ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.45 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(innerRRect, innerPaint);
  }

  @override
  bool shouldRepaint(_WinningGlowPainter old) =>
      old.rotation != rotation || old.intensity != intensity;
}
