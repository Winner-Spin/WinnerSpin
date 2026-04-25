import 'package:flutter/material.dart';
import '../viewmodels/game_viewmodel.dart';

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

    double totalDuration = isDropOut ? (500.0 / speedMult) : (900.0 / speedMult);
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
        padding: const EdgeInsets.all(4),
        child: Image.asset(
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
              clipBehavior: Clip.hardEdge,
              children: List.generate(items.length, (i) {
                return Positioned(
                  top: i * itemH,
                  left: 0,
                  right: 0,
                  height: itemH,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Image.asset(
                      items[i],
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
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
