import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'tumble_cell.dart';

/// A single slot-machine reel column that animates symbols
/// through drop-out, empty, and drop-in phases.
class SlotReel extends StatefulWidget {
  final int columnIndex;

  /// Items currently displayed (before spin).
  final List<String> previousItems;

  /// Items to land on (after spin).
  final List<String> targetItems;

  /// Set to true to trigger spin animation.
  final bool spinning;

  /// Asset paths whose cells should fade out (during a cascade tumble).
  /// Empty when no tumble is in progress.
  final Set<String> fadingPaths;

  /// Stagger delay before this reel starts moving.
  final Duration delay;

  /// How long the reel animates (after delay).
  final Duration duration;

  /// Called when this reel's animation completes.
  final VoidCallback? onComplete;

  final int speedMultiplier;

  const SlotReel({
    super.key,
    required this.columnIndex,
    required this.previousItems,
    required this.targetItems,
    required this.spinning,
    this.fadingPaths = const {},
    this.speedMultiplier = 1,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1200),
    this.onComplete,
  });

  @override
  State<SlotReel> createState() => _SlotReelState();
}

enum ReelState { static, droppingOut, empty, droppingIn }

class _SlotReelState extends State<SlotReel> with TickerProviderStateMixin {
  /// Custom curve that provides a subtle recoil (bounce) effect.
  /// Prevents the extreme overshoot caused by standard [Curves.easeOutBack].
  static const Curve _heftyBounceCurve = _HeftyBounceCurve();

  AnimationController? _controller;
  Animation<double>? _animation;

  ReelState _state = ReelState.static;

  /// Whether at least one spin has completed (to know which items to show).
  bool _hasCompleted = false;

  @override
  void didUpdateWidget(SlotReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spinning && !oldWidget.spinning) {
      _hasCompleted = false;
      _startSpin();
    }
  }

  Future<void> _startSpin() async {
    if (!mounted) return;

    int speedMult = widget.speedMultiplier;
    int dropOutDurationMs = 500 ~/ speedMult;
    int columnDelayMs = speedMult > 1 ? 0 : 100;
    int dropOutDelayMs = widget.columnIndex * columnDelayMs;

    if (dropOutDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: dropOutDelayMs));
      if (!mounted) return;
    }

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropOutDurationMs),
    );
    // Main sequence is linear; specific curves are applied per-item via Intervals.
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    setState(() => _state = ReelState.droppingOut);

    await _controller!.forward();
    if (!mounted) return;

    setState(() => _state = ReelState.empty);

    // Synchronize global idle timing so all reels transition to drop-in seamlessly.
    final int globalEmptyTimeMs =
        (GameViewModel.columns - 1) * columnDelayMs + dropOutDurationMs;
    final int myDropOutEndTimeMs = dropOutDelayMs + dropOutDurationMs;

    final int waitToGlobalEmptyMs = globalEmptyTimeMs - myDropOutEndTimeMs;
    final int dropInStaggerMs = widget.columnIndex * columnDelayMs;

    final int totalEmptyWaitMs = waitToGlobalEmptyMs + 300 + dropInStaggerMs;

    await Future.delayed(Duration(milliseconds: totalEmptyWaitMs));
    if (!mounted) return;

    int dropInDurationMs = 900 ~/ speedMult;

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropInDurationMs),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    setState(() => _state = ReelState.droppingIn);

    await _controller!.forward();

    if (mounted) {
      setState(() {
        _state = ReelState.static;
        _hasCompleted = true;
      });
      widget.onComplete?.call();
    }
  }

  Widget _buildIndependentItem(
    int index,
    String assetPath,
    double itemH,
    double viewportW,
    double viewportH,
    bool isDropOut,
  ) {
    int rowCount = GameViewModel.rows;
    int speedMult = widget.speedMultiplier;

    int reverseIndex = (rowCount - 1) - index;

    double totalDuration = isDropOut
        ? (500.0 / speedMult)
        : (900.0 / speedMult);
    double staggerMs = speedMult > 1 ? 0.0 : (isDropOut ? 28.0 : 30.0);
    double durationVal = totalDuration - (reverseIndex * staggerMs);

    double itemDurationFraction = (durationVal / totalDuration).clamp(0.3, 1.0);

    double startDelayFraction = (reverseIndex * staggerMs) / totalDuration;
    double endFraction = (startDelayFraction + itemDurationFraction).clamp(
      0.0,
      1.0,
    );

    final Curve curveType = isDropOut
        ? Curves.easeInCubic
        : (speedMult > 1 ? _heftyBounceCurve : Curves.easeOutQuad);

    final Curve itemCurve = Interval(
      startDelayFraction,
      endFraction,
      curve: curveType,
    );

    final bool isScatter = assetPath.contains('cupCake');

    return AnimatedBuilder(
      animation: _animation!,
      builder: (context, child) {
        final progress = itemCurve.transform(_animation!.value);

        final baseTop = index * itemH;
        double topPos = 0.0;

        if (isDropOut) {
          topPos = baseTop + (progress * viewportH);
        } else {
          topPos = (baseTop - viewportH) + (progress * viewportH);
        }

        return Positioned(
          top: topPos,
          left: 0,
          right: 0,
          height: itemH,
          child: child!,
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: !isDropOut && isScatter
            ? _ScatterPulse(
                assetPath: assetPath,
                animation: _animation!,
                landThreshold: endFraction,
              )
            : Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportH = constraints.maxHeight;
        final viewportW = constraints.maxWidth;
        final itemH = viewportH / GameViewModel.rows;

        if (_state == ReelState.empty) {
          return const SizedBox.shrink();
        }

        if (_state == ReelState.static) {
          final items = _hasCompleted
              ? widget.targetItems
              : widget.previousItems;
          return SizedBox(
            height: viewportH,
            child: Stack(
              // Clip.none lets winning-cell particle bursts spill past the
              // column border into the gutter between reels — without this,
              // sparks vanish at the column edge and the burst feels truncated.
              clipBehavior: Clip.none,
              children: List.generate(items.length, (i) {
                return Positioned(
                  top: i * itemH,
                  left: 0,
                  right: 0,
                  height: itemH,
                  child: TumbleCell(
                    // Stable key per (column, row) so the cell state
                    // (current path + animation controllers) survives across
                    // tumble grid swaps and animates the path change.
                    key: ValueKey('cell-${widget.columnIndex}-$i'),
                    path: items[i],
                    isFading: widget.fadingPaths.contains(items[i]),
                    itemH: itemH,
                    speedMultiplier: widget.speedMultiplier,
                  ),
                );
              }),
            ),
          );
        }

        final List<String> currentList = (_state == ReelState.droppingOut)
            ? widget.previousItems
            : widget.targetItems;
        final bool isOut = (_state == ReelState.droppingOut);

        return SizedBox(
          height: viewportH,
          child: Stack(
            clipBehavior: Clip.none,
            children: List.generate(currentList.length, (i) {
              return _buildIndependentItem(
                i,
                currentList[i],
                itemH,
                viewportW,
                viewportH,
                isOut,
              );
            }),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// A custom curve creating a subtle recoil (bounce) effect.
/// Derives from BackOut curve logic but uses a strictly limited
/// amplitude (s=0.15) to prevent extreme positional overshoot.
class _HeftyBounceCurve extends Curve {
  const _HeftyBounceCurve();
  @override
  double transformInternal(double t) {
    final double t1 = t - 1.0;
    const double s = 1.0;
    return (t1 * t1 * ((s + 1.0) * t1 + s) + 1.0);
  }
}

/// Wraps a scatter symbol image and plays a scale-up pulse with
/// golden glow, radial light burst, and sparkle effects once the
/// drop-in animation crosses [landThreshold].
class _ScatterPulse extends StatefulWidget {
  final String assetPath;
  final Animation<double> animation;
  final double landThreshold;

  const _ScatterPulse({
    required this.assetPath,
    required this.animation,
    required this.landThreshold,
  });

  @override
  State<_ScatterPulse> createState() => _ScatterPulseState();
}

class _ScatterPulseState extends State<_ScatterPulse>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _effectController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _burstExpand;
  late final Animation<double> _burstOpacity;
  late final Animation<double> _sparkleProgress;
  bool _hasTriggered = false;

  @override
  void initState() {
    super.initState();

    // Scale pulse: 1.0 → 1.5 → 1.0 (very noticeable)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseScale = TweenSequence<double>(
      [
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.5), weight: 35),
        TweenSequenceItem(tween: Tween(begin: 1.5, end: 1.0), weight: 65),
      ],
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    // Visual effects: glow + burst + sparkles
    _effectController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Golden glow: fade in fast, hold, fade out
    _glowOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.8), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 50),
    ]).animate(_effectController);

    // Radial light burst: expand outward
    _burstExpand = Tween<double>(begin: 0.3, end: 1.5).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeOut),
    );
    _burstOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.8), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.8, end: 0.0), weight: 85),
    ]).animate(_effectController);

    // Sparkle particles progress
    _sparkleProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _effectController, curve: Curves.easeOut),
    );

    widget.animation.addListener(_checkLanding);
  }

  void _checkLanding() {
    if (!_hasTriggered && widget.animation.value >= widget.landThreshold) {
      _hasTriggered = true;
      _pulseController.forward();
      _effectController.forward();
    }
  }

  @override
  void dispose() {
    widget.animation.removeListener(_checkLanding);
    _pulseController.dispose();
    _effectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Multiple scatters can land in one spin; isolating each pulse as its
    // own layer keeps the burst+glow+sparkle stack from re-rasterizing the
    // surrounding reel cells when only this scatter is animating.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pulseController, _effectController]),
        builder: (context, child) {
          final scale = _pulseScale.value;
          final glow = _glowOpacity.value;
          final burst = _burstExpand.value;
          final burstAlpha = _burstOpacity.value;
          final sparkle = _sparkleProgress.value;

          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Layer 1: Radial light burst
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
                              const Color(0xFFFFD700).withValues(alpha: 0.7),
                              const Color(0xFFFFD700).withValues(alpha: 0.2),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // Layer 2: Sparkle particles
              if (sparkle > 0 && sparkle < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScatterSparklePainter(progress: sparkle),
                  ),
                ),

              // Layer 3: Golden glow halo behind the symbol. Blur radius
              // capped at 8 (was 20) — the BoxShadow blur is GPU-expensive
              // and multiple scatter pulses overlap during FS triggers.
              if (glow > 0)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFFD700,
                          ).withValues(alpha: glow * 0.6),
                          blurRadius: 8,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),

              // Layer 4: The scatter image itself (with scale)
              Transform.scale(scale: scale, child: child),
            ],
          );
        },
        child: Image.asset(
          widget.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// Paints small sparkle particles radiating outward from the center.
class _ScatterSparklePainter extends CustomPainter {
  final double progress;
  _ScatterSparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.55;
    final rng = 42; // fixed seed for consistent pattern

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30.0 + rng) * (3.14159 / 180.0);
      final dist = maxRadius * progress * (0.6 + (i % 3) * 0.2);
      final pos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );

      // Sparkle fades out as it travels
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
  bool shouldRepaint(_ScatterSparklePainter old) => old.progress != progress;
}
