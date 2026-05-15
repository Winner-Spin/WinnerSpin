import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../domain/enums/symbol_tier.dart';
import '../../../domain/models/symbol_registry.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_label.dart';
import 'tumble_cell.dart';

class SlotReelController {
  _SlotReelState? _state;

  void quickStop() => _state?._quickStop();

  void _attach(_SlotReelState state) {
    _state = state;
  }

  void _detach(_SlotReelState state) {
    if (_state == state) {
      _state = null;
    }
  }
}

class SlotReel extends StatefulWidget {
  final int columnIndex;
  final List<String> previousItems;
  final List<String> targetItems;
  final bool spinning;
  final Set<String> fadingPaths;

  final Set<int> clearedPositions;
  final Duration delay;
  final Duration duration;
  final VoidCallback? onComplete;
  final VoidCallback? onDropInStart;

  final bool pulseScattersOnLanding;
  final int scatterPulseTrigger;
  final bool soundEffectsEnabled;

  final SlotReelController? controller;

  final int speedMultiplier;

  const SlotReel({
    super.key,
    required this.columnIndex,
    required this.previousItems,
    required this.targetItems,
    required this.spinning,
    this.fadingPaths = const {},
    this.clearedPositions = const {},
    this.controller,
    this.speedMultiplier = 1,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1200),
    this.onComplete,
    this.onDropInStart,
    this.pulseScattersOnLanding = false,
    this.scatterPulseTrigger = 0,
    this.soundEffectsEnabled = true,
  });

  @override
  State<SlotReel> createState() => _SlotReelState();
}

enum ReelState { static, droppingOut, empty, droppingIn }

class _SlotReelState extends State<SlotReel> with TickerProviderStateMixin {
  static const Curve _heftyBounceCurve = _HeftyBounceCurve();

  static const Duration _scatterPulseSettleDuration = Duration(
    milliseconds: 1050,
  );
  static const double _scatterPulseTriggerProgress = 0.985;

  AnimationController? _controller;
  Animation<double>? _animation;

  ReelState _state = ReelState.static;
  bool _quickStopped = false;
  bool _completeNotified = false;
  bool _quickStopDropIn = false;

  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._attach(this);
  }

  @override
  void didUpdateWidget(SlotReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._detach(this);
      widget.controller?._attach(this);
    }
    if (widget.spinning && !oldWidget.spinning) {
      _quickStopped = false;
      _quickStopDropIn = false;
      _completeNotified = false;
      _hasCompleted = false;
      _startSpin();
    }
  }

  Future<void> _startSpin() async {
    if (!mounted) return;

    int speedMult = widget.speedMultiplier;
    final speedFactor = _effectiveSpeedFactor(speedMult);
    int dropOutDurationMs = (500 / speedFactor).round();
    int columnDelayMs = speedMult > 1 ? 0 : 100;
    int dropOutDelayMs = widget.columnIndex * columnDelayMs;

    if (dropOutDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: dropOutDelayMs));
      if (!mounted || _quickStopped) return;
    }

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropOutDurationMs),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    setState(() => _state = ReelState.droppingOut);

    await _controller!.forward();
    if (!mounted || _quickStopped) return;

    setState(() => _state = ReelState.empty);

    final int globalEmptyTimeMs =
        (GameViewModel.columns - 1) * columnDelayMs + dropOutDurationMs;
    final int myDropOutEndTimeMs = dropOutDelayMs + dropOutDurationMs;

    final int waitToGlobalEmptyMs = globalEmptyTimeMs - myDropOutEndTimeMs;
    final int dropInStaggerMs = widget.columnIndex * columnDelayMs;

    final int totalEmptyWaitMs = waitToGlobalEmptyMs + 300 + dropInStaggerMs;

    await Future.delayed(Duration(milliseconds: totalEmptyWaitMs));
    if (!mounted || _quickStopped) return;

    int dropInDurationMs = (900 / speedFactor).round();

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropInDurationMs),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    widget.onDropInStart?.call();
    setState(() => _state = ReelState.droppingIn);

    await _controller!.forward();
    if (widget.pulseScattersOnLanding && !_quickStopped) {
      await Future.delayed(_scatterPulseSettleDuration);
    }
    _completeSpin();
  }

  Future<void> _quickStop() async {
    if (_state == ReelState.static && _hasCompleted) return;
    if (_quickStopped) return;
    _quickStopped = true;

    _controller?.stop();
    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    if (!mounted) return;
    _quickStopDropIn = true;
    setState(() => _state = ReelState.droppingIn);

    await _controller!.forward();
    _quickStopDropIn = false;
    _completeSpin();
  }

  void _completeSpin() {
    if (!mounted || _completeNotified) return;
    _completeNotified = true;
    setState(() {
      _state = ReelState.static;
      _hasCompleted = true;
    });
    widget.onComplete?.call();
  }

  Widget _buildDustResidue(double itemH) {
    return SizedBox(
      width: itemH * 1.1,
      height: itemH * 1.1,
      child: const MultiplierDustResidue(),
    );
  }

  Widget _buildReelSymbol({
    required String assetPath,
    required double itemH,
    required bool isDropOut,
    required bool cleared,
    required bool isScatter,
    required bool isMultiplier,
    required int multiplierValue,
    required double landThreshold,
    required Animation<double> animation,
  }) {
    if (isDropOut && cleared) {
      return _buildDustResidue(itemH);
    }

    final Widget symbolChild;
    if (!isDropOut && isScatter && widget.pulseScattersOnLanding) {
      symbolChild = _ScatterPulse(
        animation: animation,
        landThreshold: math.max(landThreshold, _scatterPulseTriggerProgress),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          cacheWidth: 256,
        ),
      );
    } else if (isMultiplier) {
      symbolChild = Center(
        child: SizedBox(
          width: itemH * 1.3,
          height: itemH * 1.3,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: MultiplierLabel.bombScaleFor(multiplierValue),
                  child: Lottie.asset(
                    MultiplierBombAnimation.assetPath,
                    fit: BoxFit.contain,
                    animate: false,
                  ),
                ),
                Align(
                  alignment: Alignment(
                    MultiplierLabel.labelXOffsetFor(multiplierValue),
                    0.15,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: 0.43,
                    child: MultiplierLabel(
                      value: multiplierValue,
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      symbolChild = Image.asset(
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        cacheWidth: 256,
      );
    }

    return Transform.scale(
      scale: SymbolRegistry.byPath(assetPath)?.displayScale ?? 1.0,
      child: symbolChild,
    );
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
    final speedFactor = _effectiveSpeedFactor(speedMult);

    int reverseIndex = (rowCount - 1) - index;

    double totalDuration = isDropOut
        ? (500.0 / speedFactor)
        : (900.0 / speedFactor);
    double staggerMs = speedMult > 1 ? 0.0 : (isDropOut ? 28.0 : 30.0);
    double durationVal = totalDuration - (reverseIndex * staggerMs);

    double itemDurationFraction = (durationVal / totalDuration).clamp(0.3, 1.0);

    double startDelayFraction = (reverseIndex * staggerMs) / totalDuration;
    double endFraction = (startDelayFraction + itemDurationFraction).clamp(
      0.0,
      1.0,
    );

    final bool useQuickStopDropIn = _quickStopDropIn && !isDropOut;
    if (useQuickStopDropIn) {
      final rowProgress = index / (rowCount - 1);
      startDelayFraction = rowProgress * 0.12;
      endFraction = (0.58 + rowProgress * 0.42).clamp(0.0, 1.0);
    }

    final Curve curveType = isDropOut ? Curves.easeInCubic : _heftyBounceCurve;

    final Curve itemCurve = Interval(
      startDelayFraction,
      endFraction,
      curve: curveType,
    );

    final symbolDef = SymbolRegistry.byPath(assetPath);
    final bool isScatter = symbolDef?.tier == SymbolTier.scatter;
    final bool isMultiplier = symbolDef?.tier == SymbolTier.multiplier;
    final bool cleared = widget.clearedPositions.contains(
      widget.columnIndex * 100 + index,
    );
    final int multiplierValue = symbolDef?.multiplierValue ?? 5;

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
        child: Center(
          child: _buildReelSymbol(
            assetPath: assetPath,
            itemH: itemH,
            isDropOut: isDropOut,
            cleared: cleared,
            isScatter: isScatter,
            isMultiplier: isMultiplier,
            multiplierValue: multiplierValue,
            landThreshold: endFraction,
            animation: _animation!,
          ),
        ),
      ),
    );
  }

  double _effectiveSpeedFactor(int speedMultiplier) {
    switch (speedMultiplier) {
      case 2:
        return 1.75;
      case 3:
        return 2.55;
      default:
        return 1.0;
    }
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
            width: viewportW,
            height: viewportH,
            child: Stack(
              clipBehavior: Clip.none,
              children: List.generate(items.length, (i) {
                final cleared = widget.clearedPositions.contains(
                  widget.columnIndex * 100 + i,
                );
                if (cleared) {
                  return Positioned(
                    top: i * itemH,
                    left: 0,
                    right: 0,
                    height: itemH,
                    child: Center(child: _buildDustResidue(itemH)),
                  );
                }
                return Positioned(
                  top: i * itemH,
                  left: 0,
                  right: 0,
                  height: itemH,
                  child: _buildStaticCell(row: i, path: items[i], itemH: itemH),
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
          width: viewportW,
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

  Widget _buildStaticCell({
    required int row,
    required String path,
    required double itemH,
  }) {
    final cell = TumbleCell(
      key: ValueKey('cell-${widget.columnIndex}-$row'),
      path: path,
      isFading: widget.fadingPaths.contains(path),
      itemH: itemH,
      speedMultiplier: widget.speedMultiplier,
      soundEnabled: widget.soundEffectsEnabled,
    );

    final symbol = SymbolRegistry.byPath(path);
    if (symbol?.tier != SymbolTier.scatter || widget.scatterPulseTrigger <= 0) {
      return cell;
    }

    return _ScatterPulse(
      key: ValueKey(
        'manual-scatter-pulse-${widget.columnIndex}-$row-${widget.scatterPulseTrigger}',
      ),
      autoStart: true,
      child: cell,
    );
  }

  @override
  void dispose() {
    widget.controller?._detach(this);
    _controller?.dispose();
    super.dispose();
  }
}

class _HeftyBounceCurve extends Curve {
  const _HeftyBounceCurve();
  @override
  double transformInternal(double t) {
    final double t1 = t - 1.0;
    const double s = 1.35;
    return (t1 * t1 * ((s + 1.0) * t1 + s) + 1.0);
  }
}

class _ScatterPulse extends StatefulWidget {
  final Widget child;
  final Animation<double>? animation;
  final double landThreshold;
  final bool autoStart;

  const _ScatterPulse({
    super.key,
    required this.child,
    this.animation,
    this.landThreshold = 1.0,
    this.autoStart = false,
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

              if (sparkle > 0 && sparkle < 1)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ScatterSparklePainter(progress: sparkle),
                  ),
                ),

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

              Transform.scale(scale: scale, child: child),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _ScatterSparklePainter extends CustomPainter {
  final double progress;
  _ScatterSparklePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.55;
    const rng = 42.0;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30.0 + rng) * (math.pi / 180.0);
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
  bool shouldRepaint(_ScatterSparklePainter old) => old.progress != progress;
}
