import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'multiplier_label.dart';

class FloatingCollectText extends StatefulWidget {
  final Offset start;
  final Offset end;
  final int value;

  final double startSize;

  final double endSize;

  final double punchScale;

  final Duration settleDuration;
  final Duration flightDuration;

  final Duration burstDuration;

  final double approachThreshold;
  final VoidCallback? onApproaching;
  final VoidCallback? onArrived;

  final VoidCallback? onSettleComplete;

  const FloatingCollectText({
    super.key,
    required this.start,
    required this.end,
    required this.value,
    required this.startSize,
    this.endSize = 32,
    this.punchScale = 1.30,
    this.settleDuration = const Duration(milliseconds: 250),
    this.flightDuration = const Duration(milliseconds: 700),
    this.burstDuration = const Duration(milliseconds: 850),
    this.approachThreshold = 0.70,
    this.onApproaching,
    this.onArrived,
    this.onSettleComplete,
  });

  @override
  State<FloatingCollectText> createState() => _FloatingCollectTextState();
}

class _FloatingCollectTextState extends State<FloatingCollectText>
    with TickerProviderStateMixin {
  late final AnimationController _settle;
  late final AnimationController _flight;
  late final AnimationController _burst;
  late final Animation<double> _settleT;
  late final Animation<double> _flightT;
  late final Offset _control;
  late final List<_Spark> _sparks;
  late final Listenable _animationListenable;

  @override
  void initState() {
    super.initState();

    _settle = AnimationController(vsync: this, duration: widget.settleDuration);
    _flight = AnimationController(vsync: this, duration: widget.flightDuration);
    _burst = AnimationController(vsync: this, duration: widget.burstDuration);
    _settleT = CurvedAnimation(parent: _settle, curve: Curves.easeOutBack);
    _flightT = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    _animationListenable = Listenable.merge([_settleT, _flightT, _burst]);

    final mid = Offset(
      (widget.start.dx + widget.end.dx) / 2,
      (widget.start.dy + widget.end.dy) / 2,
    );
    _control = Offset(mid.dx, mid.dy - 60);

    final rng = math.Random();
    const colors = [
      Color(0xFFFFFFFF),
      Color(0xFFFFE082),
      Color(0xFFFFD54F),
      Color(0xFFFFC107),
      Color(0xFFFF80AB),
      Color(0xFFFF4081),
      Color(0xFFFFAB91),
    ];
    _sparks = List.generate(36, (i) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = i.isEven
          ? 0.55 + rng.nextDouble() * 0.30
          : 0.85 + rng.nextDouble() * 0.45;
      return _Spark(
        angle: angle,
        speed: speed,
        size: 2.0 + rng.nextDouble() * 2.4,
        color: colors[rng.nextInt(colors.length)],
      );
    });

    _burst.forward();

    _settle.forward().then((_) {
      if (!mounted) return;
      widget.onSettleComplete?.call();
      _flight.addListener(_emitApproachingOnce);
      _flight.forward().then((_) {
        if (!mounted) return;
        widget.onArrived?.call();
      });
    });
  }

  bool _approachFired = false;
  void _emitApproachingOnce() {
    if (_approachFired) return;
    if (_flight.value >= widget.approachThreshold) {
      _approachFired = true;
      _flight.removeListener(_emitApproachingOnce);
      widget.onApproaching?.call();
    }
  }

  @override
  void dispose() {
    _settle.dispose();
    _flight.dispose();
    _burst.dispose();
    super.dispose();
  }

  Offset _bezierAt(double t) {
    final inv = 1 - t;
    return Offset(
      inv * inv * widget.start.dx +
          2 * inv * t * _control.dx +
          t * t * widget.end.dx,
      inv * inv * widget.start.dy +
          2 * inv * t * _control.dy +
          t * t * widget.end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationListenable,
      builder: (context, _) {
        final flightT = _flightT.value;
        final burstRaw = _burst.value;

        final pos = _flight.isAnimating || _flight.isCompleted
            ? _bezierAt(flightT)
            : widget.start;

        final double size;
        if (!_settle.isCompleted) {
          final s = _settleT.value;
          size =
              widget.startSize *
              (widget.punchScale + (1.0 - widget.punchScale) * s);
        } else {
          size =
              widget.startSize + (widget.endSize - widget.startSize) * flightT;
        }

        final opacity = !_settle.isCompleted
            ? 1.0
            : (flightT < 0.7 ? 1.0 : 1.0 - (flightT - 0.7) / 0.3);

        final showEffect = !_burst.isCompleted;
        final effectSize = widget.startSize * 2.4;

        return Stack(
          children: [
            if (showEffect)
              Positioned(
                left: widget.start.dx - effectSize / 2,
                top: widget.start.dy - effectSize / 2,
                width: effectSize,
                height: effectSize,
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SettleEffectPainter(
                      progress: burstRaw,
                      sparks: _sparks,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: pos.dx - size / 2,
              top: pos.dy - size / 2,
              width: size,
              height: size,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: _ValueImage(value: widget.value),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ValueImage extends StatelessWidget {
  final int value;
  const _ValueImage({required this.value});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      MultiplierLabel.assetPathFor(value),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => _FallbackPill(value: value),
    );
  }
}

class _FallbackPill extends StatelessWidget {
  final int value;
  const _FallbackPill({required this.value});

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE082), Color(0xFFFFB300), Color(0xFFFF6F00)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Text(
          '${value}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            shadows: [
              Shadow(
                color: Color(0xFF8E2A00),
                offset: Offset(0, 2),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Spark {
  final double angle;
  final double speed;
  final double size;
  final Color color;
  const _Spark({
    required this.angle,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _SettleEffectPainter extends CustomPainter {
  final double progress;
  final List<_Spark> sparks;

  _SettleEffectPainter({required this.progress, required this.sparks});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.5;

    double haloAlpha;
    if (progress < 0.2) {
      haloAlpha = progress / 0.2;
    } else if (progress < 0.6) {
      haloAlpha = 1.0;
    } else {
      haloAlpha = 1.0 - (progress - 0.6) / 0.4;
    }
    haloAlpha = haloAlpha.clamp(0.0, 1.0);

    final haloPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFFE082).withValues(alpha: 0.65 * haloAlpha),
              const Color(0xFFFF80AB).withValues(alpha: 0.40 * haloAlpha),
              const Color(0x00FF80AB),
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: maxRadius * 0.95),
          );
    canvas.drawCircle(Offset(cx, cy), maxRadius * 0.95, haloPaint);

    final flashAlpha = (1.0 - progress * 1.6).clamp(0.0, 1.0);
    if (flashAlpha > 0) {
      final flashPaint = Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95 * flashAlpha),
                Colors.white.withValues(alpha: 0.55 * flashAlpha),
                const Color(0x00FFFFFF),
              ],
              stops: const [0.0, 0.35, 1.0],
            ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: maxRadius * 0.7),
            );
      canvas.drawCircle(Offset(cx, cy), maxRadius * 0.7, flashPaint);
    }

    for (final s in sparks) {
      final dist = maxRadius * progress * s.speed;
      final px = cx + math.cos(s.angle) * dist;
      final py = cy + math.sin(s.angle) * dist;
      final fade = (1.0 - progress).clamp(0.0, 1.0);
      final radius = s.size * (1.0 - progress * 0.4);

      final glow = Paint()
        ..shader =
            RadialGradient(
              colors: [
                s.color.withValues(alpha: fade * 0.85),
                s.color.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: Offset(px, py), radius: radius * 2.2),
            );
      canvas.drawCircle(Offset(px, py), radius * 2.2, glow);

      final core = Paint()..color = Colors.white.withValues(alpha: fade * 0.95);
      canvas.drawCircle(Offset(px, py), radius * 0.55, core);
    }
  }

  @override
  bool shouldRepaint(covariant _SettleEffectPainter old) =>
      old.progress != progress;
}
