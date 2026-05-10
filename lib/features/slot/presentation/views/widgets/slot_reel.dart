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

  /// Positions (encoded as `column * 100 + row`) the reel should render
  /// as empty even though the grid still holds a symbol there. The win
  /// presentation layer fills this when a multiplier asset has lifted
  /// off its cell — the cell reads as consumed for the rest of the spin.
  final Set<int> clearedPositions;

  /// Stagger delay before this reel starts moving.
  final Duration delay;

  /// How long the reel animates (after delay).
  final Duration duration;

  /// Called when this reel's animation completes.
  final VoidCallback? onComplete;

  /// Called the instant this reel starts the drop-in phase, so the
  /// view-model can wipe last round's residue dust just before the
  /// new symbols land — keeps the drop-out's residue visible while
  /// stopping the static state from flashing dust before the new
  /// symbol appears.
  final VoidCallback? onDropInStart;

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
  bool _quickStopped = false;
  bool _completeNotified = false;
  bool _quickStopDropIn = false;

  /// Whether at least one spin has completed (to know which items to show).
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
    int dropOutDurationMs = 500 ~/ speedMult;
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
    // Main sequence is linear; specific curves are applied per-item via Intervals.
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    setState(() => _state = ReelState.droppingOut);

    await _controller!.forward();
    if (!mounted || _quickStopped) return;

    setState(() => _state = ReelState.empty);

    // Synchronize global idle timing so all reels transition to drop-in seamlessly.
    final int globalEmptyTimeMs =
        (GameViewModel.columns - 1) * columnDelayMs + dropOutDurationMs;
    final int myDropOutEndTimeMs = dropOutDelayMs + dropOutDurationMs;

    final int waitToGlobalEmptyMs = globalEmptyTimeMs - myDropOutEndTimeMs;
    final int dropInStaggerMs = widget.columnIndex * columnDelayMs;

    final int totalEmptyWaitMs = waitToGlobalEmptyMs + 300 + dropInStaggerMs;

    await Future.delayed(Duration(milliseconds: totalEmptyWaitMs));
    if (!mounted || _quickStopped) return;

    int dropInDurationMs = 900 ~/ speedMult;

    _controller?.dispose();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropInDurationMs),
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller!);

    widget.onDropInStart?.call();
    setState(() => _state = ReelState.droppingIn);

    await _controller!.forward();
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
    required bool isMultiplier,
    required int multiplierValue,
  }) {
    if (isDropOut && cleared) {
      return _buildDustResidue(itemH);
    }

    final Widget symbolChild;
    if (isMultiplier) {
      // Multiplier cells render the bomb (frozen on frame 0) already during
      // the column-wide drop-in / drop-out so the player never sees a flash
      // of the legacy multiplier sprite morph into a bomb in the static phase.
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

    final bool useQuickStopDropIn = _quickStopDropIn && !isDropOut;
    if (useQuickStopDropIn) {
      final rowProgress = index / (rowCount - 1);
      startDelayFraction = rowProgress * 0.12;
      endFraction = (0.58 + rowProgress * 0.42).clamp(0.0, 1.0);
    }

    final Curve curveType = isDropOut
        ? Curves.easeInCubic
        : _heftyBounceCurve;

    final Curve itemCurve = Interval(
      startDelayFraction,
      endFraction,
      curve: curveType,
    );

    final symbolDef = SymbolRegistry.byPath(assetPath);
    final bool isMultiplier = symbolDef?.tier == SymbolTier.multiplier;
    final bool cleared = widget.clearedPositions
        .contains(widget.columnIndex * 100 + index);
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
            isMultiplier: isMultiplier,
            multiplierValue: multiplierValue,
          ),
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
            width: viewportW,
            height: viewportH,
            child: Stack(
              // Clip.none lets winning-cell particle bursts spill past the
              // column border into the gutter between reels — without this,
              // sparks vanish at the column edge and the burst feels truncated.
              clipBehavior: Clip.none,
              children: List.generate(items.length, (i) {
                final cleared = widget.clearedPositions
                    .contains(widget.columnIndex * 100 + i);
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

  @override
  void dispose() {
    widget.controller?._detach(this);
    _controller?.dispose();
    super.dispose();
  }
}

/// A custom curve creating a candy-machine spring landing effect.
class _HeftyBounceCurve extends Curve {
  const _HeftyBounceCurve();
  @override
  double transformInternal(double t) {
    final double t1 = t - 1.0;
    const double s = 1.35;
    return (t1 * t1 * ((s + 1.0) * t1 + s) + 1.0);
  }
}

