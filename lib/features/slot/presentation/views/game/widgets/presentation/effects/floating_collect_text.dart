import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../playfield/multiplier_label.dart';

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
  final Future<void>? burstStartSignal;

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
    this.burstStartSignal,
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
  late final ValueNotifier<double> _burstPaintProgress;
  late final Animation<double> _settleT;
  late final Animation<double> _flightT;
  late final Offset _control;
  late final List<_Spark> _sparks;
  late final Listenable _animationListenable;
  late final _SettleEffectPainter _effectPainter;
  bool _burstVisible = false;
  bool _burstCompleted = false;
  bool _flightCompleted = false;
  int _lastBurstPaintFrame = -1;

  // Matches source cadence without duplicate 120 Hz paints.
  static const int _burstPaintFramesPerSecond = 60;

  @override
  void initState() {
    super.initState();

    _settle = AnimationController(vsync: this, duration: widget.settleDuration);
    _flight = AnimationController(vsync: this, duration: widget.flightDuration);
    _burst = AnimationController(vsync: this, duration: widget.burstDuration);
    _burstPaintProgress = ValueNotifier<double>(0);
    _burst.addListener(_updateBurstPaintProgress);
    _settleT = CurvedAnimation(parent: _settle, curve: Curves.easeOutBack);
    _flightT = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    _animationListenable = Listenable.merge([_settleT, _flightT]);

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
    _sparks = List.generate(20, (i) {
      final angle = rng.nextDouble() * 2 * math.pi;
      final speed = i.isEven
          ? 0.55 + rng.nextDouble() * 0.30
          : 0.85 + rng.nextDouble() * 0.45;
      return _Spark(
        directionX: math.cos(angle),
        directionY: math.sin(angle),
        speed: speed,
        size: 2.0 + rng.nextDouble() * 2.4,
        color: colors[rng.nextInt(colors.length)],
      );
    });
    _effectPainter = _SettleEffectPainter(
      progress: _burstPaintProgress,
      sparks: _sparks,
    );

    final burstStartSignal = widget.burstStartSignal;
    if (burstStartSignal == null) {
      _burstVisible = true;
      _runBurst();
    } else {
      unawaited(_startBurstAfter(burstStartSignal));
    }

    _settle.forward().then((_) {
      if (!mounted) return;
      widget.onSettleComplete?.call();
      _flight.addListener(_emitApproachingOnce);
      _flight.forward().then((_) {
        if (!mounted) return;
        _flightCompleted = true;
        _completeIfReady();
      });
    });
  }

  bool _approachFired = false;

  Future<void> _startBurstAfter(Future<void> signal) async {
    try {
      await signal;
    } catch (_) {
      // The collect label must remain usable if the source animation aborts.
    }
    if (!mounted || _burstVisible) return;
    setState(() => _burstVisible = true);
    _runBurst();
  }

  void _runBurst() {
    _burst.forward().then((_) {
      if (!mounted) return;
      _burstCompleted = true;
      _completeIfReady();
    });
  }

  void _updateBurstPaintProgress() {
    final frame =
        (_burst.value *
                widget.burstDuration.inMicroseconds *
                _burstPaintFramesPerSecond /
                Duration.microsecondsPerSecond)
            .floor();
    if (frame == _lastBurstPaintFrame) return;
    _lastBurstPaintFrame = frame;
    _burstPaintProgress.value = _burst.value;
  }

  void _completeIfReady() {
    if (_flightCompleted && _burstCompleted) {
      widget.onArrived?.call();
    }
  }

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
    _burst.removeListener(_updateBurstPaintProgress);
    _burst.dispose();
    _burstPaintProgress.dispose();
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
    final effectSize = widget.startSize * 2.4;
    return Stack(
      children: [
        if (_burstVisible)
          Positioned(
            left: widget.start.dx - effectSize / 2,
            top: widget.start.dy - effectSize / 2,
            width: effectSize,
            height: effectSize,
            child: RepaintBoundary(
              child: IgnorePointer(child: CustomPaint(painter: _effectPainter)),
            ),
          ),
        AnimatedBuilder(
          animation: _animationListenable,
          child: _ValueImage(value: widget.value),
          builder: (context, valueImage) {
            final flightT = _flightT.value;

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
                  widget.startSize +
                  (widget.endSize - widget.startSize) * flightT;
            }

            final opacity = !_settle.isCompleted
                ? 1.0
                : (flightT < 0.7 ? 1.0 : 1.0 - (flightT - 0.7) / 0.3);

            return Positioned(
              left: pos.dx - size / 2,
              top: pos.dy - size / 2,
              width: size,
              height: size,
              child: IgnorePointer(
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: valueImage,
                ),
              ),
            );
          },
        ),
      ],
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
  final double directionX;
  final double directionY;
  final double speed;
  final double size;
  final Color color;
  const _Spark({
    required this.directionX,
    required this.directionY,
    required this.speed,
    required this.size,
    required this.color,
  });
}

class _SettleEffectPainter extends CustomPainter {
  final ValueListenable<double> progress;
  final List<_Spark> sparks;

  _SettleEffectPainter({required this.progress, required this.sparks})
    : super(repaint: progress);

  final Paint _haloPaint = Paint();
  final Paint _flashPaint = Paint();
  final Paint _sparkGlowPaint = Paint();
  final Paint _sparkCorePaint = Paint();
  Size? _shaderSize;

  void _prepareShaders(Size size) {
    if (_shaderSize == size) return;
    _shaderSize = size;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.5;
    _haloPaint.shader = const RadialGradient(
      colors: [Color(0xA6FFE082), Color(0x66FF80AB), Color(0x00FF80AB)],
      stops: [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.95));
    _flashPaint.shader = const RadialGradient(
      colors: [Color(0xF2FFFFFF), Color(0x8CFFFFFF), Color(0x00FFFFFF)],
      stops: [0.0, 0.35, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.7));
  }

  ColorFilter _alphaFilter(double opacity) {
    final alpha = (opacity.clamp(0.0, 1.0) * 255).round();
    return ColorFilter.mode(
      Color.fromARGB(alpha, 255, 255, 255),
      BlendMode.modulate,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    _prepareShaders(size);
    final progressValue = progress.value;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final maxRadius = size.width * 0.5;

    double haloAlpha;
    if (progressValue < 0.2) {
      haloAlpha = progressValue / 0.2;
    } else if (progressValue < 0.6) {
      haloAlpha = 1.0;
    } else {
      haloAlpha = 1.0 - (progressValue - 0.6) / 0.4;
    }
    haloAlpha = haloAlpha.clamp(0.0, 1.0);

    if (haloAlpha > 0) {
      _haloPaint.colorFilter = _alphaFilter(haloAlpha);
      canvas.drawCircle(Offset(cx, cy), maxRadius * 0.95, _haloPaint);
    }

    final flashAlpha = (1.0 - progressValue * 1.6).clamp(0.0, 1.0);
    if (flashAlpha > 0) {
      _flashPaint.colorFilter = _alphaFilter(flashAlpha);
      canvas.drawCircle(Offset(cx, cy), maxRadius * 0.7, _flashPaint);
    }

    for (final s in sparks) {
      final dist = maxRadius * progressValue * s.speed;
      final px = cx + s.directionX * dist;
      final py = cy + s.directionY * dist;
      final fade = (1.0 - progressValue).clamp(0.0, 1.0);
      final radius = s.size * (1.0 - progressValue * 0.4);
      final point = Offset(px, py);

      _sparkGlowPaint.color = s.color.withValues(alpha: fade * 0.65);
      canvas.drawCircle(point, radius * 1.6, _sparkGlowPaint);

      _sparkCorePaint.color = Colors.white.withValues(alpha: fade * 0.95);
      canvas.drawCircle(point, radius * 0.55, _sparkCorePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SettleEffectPainter old) => false;
}
