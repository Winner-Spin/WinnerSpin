import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One stylised multiplier face value flying out of its grid cell into
/// the win bar. Three phases:
///   1. **Settle** ([settleDuration]): the asset appears centred on the
///      cell with a punch-in pop — overshoots to [punchScale] then
///      eases back to 1.0. A radial glow halo + sparkle burst spawn
///      around it for the same window so the symbol "comes alive"
///      before lifting off.
///   2. **Flight** ([flightDuration]): the asset travels along a soft
///      quadratic Bezier curve from the cell centre to the bar centre,
///      shrinking to [endSize] and fading out near the end.
///   3. **Approach signal**: when flight crosses [approachThreshold]
///      the [onApproaching] callback fires once — used by the bar to
///      start its pulse before the asset has finished fading.
///
/// Visual: prefers `5x_yazi_transparan.png` from the symbol set; if that
/// asset can't be loaded the widget falls back to a stylised pill so
/// the sequence still reads correctly.
class FloatingCollectText extends StatefulWidget {
  final Offset start;
  final Offset end;
  final int value;

  /// Display side length of the asset when it's sitting on the cell.
  final double startSize;

  /// Display side length when it arrives at the win bar.
  final double endSize;

  /// Initial overshoot multiplier on top of [startSize] during settle.
  final double punchScale;

  final Duration settleDuration;
  final Duration flightDuration;

  /// Burst effect window — independent of [settleDuration] so the
  /// halo + particles linger past the asset's punch-in pop. Keeps the
  /// candy explosion visually alive while the asset already lifts off
  /// for the bar.
  final Duration burstDuration;

  final double approachThreshold;
  final VoidCallback? onApproaching;
  final VoidCallback? onArrived;

  /// Fires once the settle pop completes — used by the host to clear
  /// the multiplier symbol from the grid as the asset lifts off.
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

  @override
  void initState() {
    super.initState();

    _settle = AnimationController(vsync: this, duration: widget.settleDuration);
    _flight = AnimationController(vsync: this, duration: widget.flightDuration);
    _burst = AnimationController(vsync: this, duration: widget.burstDuration);
    _settleT = CurvedAnimation(parent: _settle, curve: Curves.easeOutBack);
    _flightT = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);

    final mid = Offset(
      (widget.start.dx + widget.end.dx) / 2,
      (widget.start.dy + widget.end.dy) / 2,
    );
    _control = Offset(mid.dx, mid.dy - 60);

    // Dense candy-slot burst: 36 dot-only sparkles in mixed
    // pink/amber/white. Two rings (inner short-throw + outer
    // long-throw) layered so the burst reads as a fan of dots rather
    // than a single thin line at one radius.
    final rng = math.Random();
    const colors = [
      Color(0xFFFFFFFF), // white
      Color(0xFFFFE082), // light amber
      Color(0xFFFFD54F), // amber
      Color(0xFFFFC107), // deep amber
      Color(0xFFFF80AB), // light pink
      Color(0xFFFF4081), // pink
      Color(0xFFFFAB91), // peach
    ];
    _sparks = List.generate(36, (i) {
      final angle = rng.nextDouble() * 2 * math.pi;
      // Half the sparks throw further, half stay closer — gives the
      // burst depth instead of a single ring.
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

    // Burst plays in parallel with settle and continues past it so
    // the candy explosion lingers on the cell after the asset has
    // already left for the bar.
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
      animation: Listenable.merge([_settleT, _flightT, _burst]),
      builder: (context, _) {
        final flightT = _flightT.value;
        final burstRaw = _burst.value;

        final pos = _flight.isAnimating || _flight.isCompleted
            ? _bezierAt(flightT)
            : widget.start;

        final double size;
        if (!_settle.isCompleted) {
          final s = _settleT.value;
          size = widget.startSize *
              (widget.punchScale + (1.0 - widget.punchScale) * s);
        } else {
          size = widget.startSize +
              (widget.endSize - widget.startSize) * flightT;
        }

        final opacity = !_settle.isCompleted
            ? 1.0
            : (flightT < 0.7 ? 1.0 : 1.0 - (flightT - 0.7) / 0.3);

        // Burst is anchored to the original cell centre and runs on
        // its own controller — outlives the settle pop, so the candy
        // explosion lingers after the asset has already lifted off.
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
      'lib/images/slot_main_screen/Items/5x_yazi_transparan.png',
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

/// Paints the on-cell candy burst behind the multiplier asset. Layers,
/// from back to front:
///   1. **Pink-amber glow halo** — fades in, holds, fades out across
///      the settle window.
///   2. **Central white flash** — bright pop in the first ~30%, decays
///      fast.
///   3. **Sparkle burst** — 36 mixed-colour dot particles (pink /
///      amber / white / peach) radiating outward at two layered
///      throw distances, each with a coloured glow halo and a white
///      core. No line/ray geometry — keeps the effect reading as a
///      cloud of dots rather than a thin starburst.
class _SettleEffectPainter extends CustomPainter {
  final double progress;
  final List<_Spark> sparks;

  _SettleEffectPainter({required this.progress, required this.sparks});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.5;

    // Halo — pink-amber, fade in / hold / fade out.
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
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFE082).withValues(alpha: 0.65 * haloAlpha),
          const Color(0xFFFF80AB).withValues(alpha: 0.40 * haloAlpha),
          const Color(0x00FF80AB),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(
        center: Offset(cx, cy),
        radius: maxRadius * 0.95,
      ));
    canvas.drawCircle(Offset(cx, cy), maxRadius * 0.95, haloPaint);

    // Central white flash — punchy, decays fast.
    final flashAlpha = (1.0 - progress * 1.6).clamp(0.0, 1.0);
    if (flashAlpha > 0) {
      final flashPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95 * flashAlpha),
            Colors.white.withValues(alpha: 0.55 * flashAlpha),
            const Color(0x00FFFFFF),
          ],
          stops: const [0.0, 0.35, 1.0],
        ).createShader(Rect.fromCircle(
          center: Offset(cx, cy),
          radius: maxRadius * 0.7,
        ));
      canvas.drawCircle(Offset(cx, cy), maxRadius * 0.7, flashPaint);
    }

    // Sparkle particles — coloured glow + white core, radiating outward.
    for (final s in sparks) {
      final dist = maxRadius * progress * s.speed;
      final px = cx + math.cos(s.angle) * dist;
      final py = cy + math.sin(s.angle) * dist;
      final fade = (1.0 - progress).clamp(0.0, 1.0);
      final radius = s.size * (1.0 - progress * 0.4);

      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            s.color.withValues(alpha: fade * 0.85),
            s.color.withValues(alpha: 0),
          ],
        ).createShader(
          Rect.fromCircle(center: Offset(px, py), radius: radius * 2.2),
        );
      canvas.drawCircle(Offset(px, py), radius * 2.2, glow);

      final core = Paint()
        ..color = Colors.white.withValues(alpha: fade * 0.95);
      canvas.drawCircle(Offset(px, py), radius * 0.55, core);
    }
  }

  @override
  bool shouldRepaint(covariant _SettleEffectPainter old) =>
      old.progress != progress;
}
