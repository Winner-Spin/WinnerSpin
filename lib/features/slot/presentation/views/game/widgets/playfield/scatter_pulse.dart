import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScatterPulse extends StatefulWidget {
  const ScatterPulse({
    super.key,
    required this.child,
    this.animation,
    this.landThreshold = 1.0,
    this.autoStart = false,
  });

  final Widget child;
  final Animation<double>? animation;
  final double landThreshold;
  final bool autoStart;

  @override
  State<ScatterPulse> createState() => _ScatterPulseState();
}

class _ScatterPulseState extends State<ScatterPulse>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _effectController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _burstExpand;
  late final Animation<double> _burstOpacity;
  late final Animation<double> _sparkleProgress;
  late final Listenable _pulseListenable;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _pulseScale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 65),
      ],
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    );
    _pulseListenable = Listenable.merge([_pulseController, _effectController]);

    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 50),
    ]).animate(_effectController);

    _burstExpand = Tween<double>(begin: 0.3, end: 1.5).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeOut),
    );
    _burstOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 85),
    ]).animate(_effectController);

    _sparkleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeOut),
    );

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasTriggered) return;
        _hasTriggered = true;
        _pulseController.forward();
        _effectController.forward();
      });
    } else {
      widget.animation?.addListener(_checkLanding);
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkLanding());
    }
  }

  void _checkLanding() {
    if (!mounted) return;
    final animation = widget.animation;
    if (animation == null) return;
    if (!_hasTriggered && animation.value >= widget.landThreshold) {
      _hasTriggered = true;
      _pulseController.forward();
      _effectController.forward();
    }
  }

  @override
  void dispose() {
    widget.animation?.removeListener(_checkLanding);
    _pulseController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _pulseListenable,
        builder: (context, child) {
          final scale = _pulseScale.value;
          final glow = _glowOpacity.value;
          final burst = _burstExpand.value;
          final burstAlpha = _burstOpacity.value;
          final sparkle = _sparkleProgress.value;
          final haloOpacity = math.max(glow, burstAlpha * 0.65);

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (burstAlpha > 0)
                Positioned.fill(
                  child: Transform.scale(
                    scale: burst,
                    child: Opacity(
                      opacity: burstAlpha,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              const Color(
                                0xFFFFFFFF,
                              ).withValues(alpha: burstAlpha * 0.85),
                              const Color(
                                0xFFFFD700,
                              ).withValues(alpha: burstAlpha * 0.85),
                              const Color(
                                0xFFFFA000,
                              ).withValues(alpha: burstAlpha * 0.28),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.28, 0.62, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (sparkle > 0 && sparkle < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScatterSparklePainter(progress: sparkle),
                  ),
                ),
              if (glow > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ScatterGlowPainter(opacity: glow),
                    ),
                  ),
                ),
              Transform.scale(scale: scale, child: child),

            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _ScatterGlowPainter extends CustomPainter {
  _ScatterGlowPainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.5;

    final paint1 = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: opacity * 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 1.5, paint1);

    final paint2 = Paint()
      ..color = const Color(0xFFFFD700).withValues(alpha: opacity * 0.30)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 1.2, paint2);

    final paint3 = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: opacity * 0.50)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, baseRadius * 1.0, paint3);
  }

  @override
  bool shouldRepaint(covariant _ScatterGlowPainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

class _ScatterSparklePainter extends CustomPainter {
  _ScatterSparklePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.55;
    const seedAngleOffset = 42;

    for (var i = 0; i < 12; i++) {
      final angle = (i * 30.0 + seedAngleOffset) * (math.pi / 180.0);
      final dist = maxRadius * progress * (0.6 + (i % 3) * 0.2);
      final pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );

      final alpha = ((1.0 - progress) * 0.9).clamp(0.0, 1.0);
      final sparkleSize = 2.5 * (1.0 - progress * 0.5);

      final paint = Paint()
        ..color = Color.lerp(
          const Color(0xFFFFD700),
          const Color(0xFFFFFFFF),
          (i % 2 == 0) ? 0.0 : 0.5,
        )!.withValues(alpha: alpha);

      canvas.drawCircle(pos, sparkleSize, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ScatterSparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
