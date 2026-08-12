import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../../../domain/enums/symbol_tier.dart';
import '../../../../../domain/models/symbol_registry.dart';
import '../../../../viewmodels/game_viewmodel.dart';
import 'hefty_bounce_curve.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_bomb_symbol.dart';
import 'scatter_pulse.dart';
import 'slot_reel_controller.dart';
import 'tumble_cell.dart';

class SlotReel extends StatefulWidget {
  final int columnIndex;

  final List<String> previousItems;

  final List<String> targetItems;

  final bool spinning;

  final int spinRevision;

  final int targetReadyRevision;

  final Set<String> fadingPaths;

  final Set<int> clearedPositions;
  final Set<int> multiplierResiduePositions;

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
    required this.spinRevision,
    required this.targetReadyRevision,
    this.fadingPaths = const {},
    this.clearedPositions = const {},
    this.multiplierResiduePositions = const {},
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
  static const Curve _heftyBounceCurve = HeftyBounceCurve();

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

  int _activeSpinRevision = 0;
  int _runToken = 0;
  int? _queuedQuickStopRevision;
  Completer<void>? _targetReady;
  List<String>? _targetSnapshot;
  int? _targetSnapshotRevision;

  @override
  void initState() {
    super.initState();
    _activeSpinRevision = widget.spinRevision;
    widget.controller?.attach(this, _quickStop);
  }

  @override
  void didUpdateWidget(SlotReel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this, _quickStop);
    }
    if (!widget.spinning &&
        _hasCompleted &&
        !identical(oldWidget.targetItems, widget.targetItems)) {
      _targetSnapshot = null;
      _targetSnapshotRevision = null;
    }
    final spinStarted =
        widget.spinning &&
        (!oldWidget.spinning || widget.spinRevision != oldWidget.spinRevision);
    if (spinStarted) {
      _beginSpin();
      return;
    }
    _captureTargetIfReady(widget.spinRevision);
    _flushQueuedQuickStop();
  }

  void _beginSpin() {
    final revision = widget.spinRevision;
    _runToken++;
    _disposeCurrentController();
    final previousTargetReady = _targetReady;
    if (previousTargetReady != null && !previousTargetReady.isCompleted) {
      previousTargetReady.complete();
    }

    _activeSpinRevision = revision;
    _quickStopped = false;
    _quickStopDropIn = false;
    _completeNotified = false;
    _hasCompleted = false;
    _targetSnapshot = null;
    _targetSnapshotRevision = null;
    _targetReady = Completer<void>();
    if (_queuedQuickStopRevision != revision) {
      _queuedQuickStopRevision = null;
    }

    _captureTargetIfReady(revision);
    final token = _runToken;
    unawaited(_startSpin(revision: revision, token: token));
    _flushQueuedQuickStop();
  }

  bool _captureTargetIfReady(int revision) {
    if (widget.spinRevision != revision ||
        widget.targetReadyRevision != revision) {
      return false;
    }
    if (_targetSnapshotRevision != revision) {
      _targetSnapshot = List<String>.unmodifiable(widget.targetItems);
      _targetSnapshotRevision = revision;
    }
    final targetReady = _targetReady;
    if (targetReady != null && !targetReady.isCompleted) {
      targetReady.complete();
    }
    return true;
  }

  bool _isActiveRun({required int revision, required int token}) {
    return mounted &&
        revision == _activeSpinRevision &&
        token == _runToken &&
        !_completeNotified;
  }

  void _replaceController(AnimationController controller) {
    final previous = _controller;
    _controller = controller;
    if (previous == null) return;
    previous.stop();
    previous.dispose();
  }

  void _disposeCurrentController() {
    final current = _controller;
    _controller = null;
    if (current == null) return;
    current.stop();
    current.dispose();
  }

  Future<bool> _forwardController(
    AnimationController controller, {
    required int revision,
    required int token,
  }) async {
    try {
      await controller.forward().orCancel;
    } on TickerCanceled {
      return false;
    }
    return _isActiveRun(revision: revision, token: token);
  }

  Future<void> _startSpin({required int revision, required int token}) async {
    if (!_isActiveRun(revision: revision, token: token)) return;

    int speedMult = widget.speedMultiplier;
    final speedFactor = _effectiveSpeedFactor(speedMult);
    int dropOutDurationMs = (500 / speedFactor).round();
    int columnDelayMs = speedMult > 1 ? 0 : 100;
    int dropOutDelayMs = widget.columnIndex * columnDelayMs;

    if (dropOutDelayMs > 0) {
      await Future.delayed(Duration(milliseconds: dropOutDelayMs));
      if (!_isActiveRun(revision: revision, token: token)) return;
    }

    final dropOutController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropOutDurationMs),
    );
    _replaceController(dropOutController);
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(dropOutController);

    setState(() => _state = ReelState.droppingOut);

    if (!await _forwardController(
      dropOutController,
      revision: revision,
      token: token,
    )) {
      return;
    }

    setState(() => _state = ReelState.empty);

    final int globalEmptyTimeMs =
        (GameViewModel.columns - 1) * columnDelayMs + dropOutDurationMs;
    final int myDropOutEndTimeMs = dropOutDelayMs + dropOutDurationMs;

    final int waitToGlobalEmptyMs = globalEmptyTimeMs - myDropOutEndTimeMs;
    final int dropInStaggerMs = widget.columnIndex * columnDelayMs;

    final int totalEmptyWaitMs = waitToGlobalEmptyMs + 300 + dropInStaggerMs;

    await Future.delayed(Duration(milliseconds: totalEmptyWaitMs));
    if (!_isActiveRun(revision: revision, token: token)) return;

    final targetReady = _targetReady;
    if (targetReady == null) return;
    await targetReady.future;
    if (!_isActiveRun(revision: revision, token: token)) return;
    if (!_captureTargetIfReady(revision)) return;

    int dropInDurationMs = (900 / speedFactor).round();

    final dropInController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: dropInDurationMs),
    );
    _replaceController(dropInController);

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(dropInController);

    widget.onDropInStart?.call();
    setState(() => _state = ReelState.droppingIn);

    if (!await _forwardController(
      dropInController,
      revision: revision,
      token: token,
    )) {
      return;
    }
    if (widget.pulseScattersOnLanding && !_quickStopped) {
      await Future.delayed(_scatterPulseSettleDuration);
      if (!_isActiveRun(revision: revision, token: token)) return;
    }
    _completeSpin(revision: revision, token: token);
  }

  void _quickStop(int spinRevision) {
    if (spinRevision < _activeSpinRevision) return;
    if (spinRevision != _activeSpinRevision ||
        widget.spinRevision != spinRevision) {
      _queuedQuickStopRevision = spinRevision;
      return;
    }
    if (_completeNotified || (_state == ReelState.static && _hasCompleted)) {
      return;
    }
    if (_quickStopped) return;
    _queuedQuickStopRevision = spinRevision;
    _flushQueuedQuickStop();
  }

  void _flushQueuedQuickStop() {
    final revision = _queuedQuickStopRevision;
    if (revision == null ||
        revision != _activeSpinRevision ||
        widget.spinRevision != revision ||
        _quickStopped ||
        _completeNotified ||
        !_captureTargetIfReady(revision)) {
      return;
    }
    _queuedQuickStopRevision = null;
    unawaited(_startQuickStop(revision));
  }

  Future<void> _startQuickStop(int revision) async {
    if (!mounted ||
        revision != _activeSpinRevision ||
        _quickStopped ||
        _completeNotified ||
        !_captureTargetIfReady(revision)) {
      return;
    }
    _quickStopped = true;
    final token = ++_runToken;

    final quickStopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _replaceController(quickStopController);
    _animation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(quickStopController);

    _quickStopDropIn = true;
    setState(() => _state = ReelState.droppingIn);

    if (!await _forwardController(
      quickStopController,
      revision: revision,
      token: token,
    )) {
      return;
    }
    _quickStopDropIn = false;
    _completeSpin(revision: revision, token: token);
  }

  void _completeSpin({required int revision, required int token}) {
    if (!_isActiveRun(revision: revision, token: token)) return;
    _completeNotified = true;
    setState(() {
      _state = ReelState.static;
      _hasCompleted = true;
      _quickStopDropIn = false;
    });
    widget.onComplete?.call();
  }

  Widget _buildMultiplierResidue(double itemH) {
    return SizedBox(
      width: itemH * 1.1,
      height: itemH * 1.1,
      child: const MultiplierBlastResidue(),
    );
  }

  Widget _buildReelSymbol({
    required String assetPath,
    required int rowIndex,
    required double itemH,
    required bool isDropOut,
    required bool cleared,
    required bool showMultiplierResidue,
    required bool isScatter,
    required bool isMultiplier,
    required int multiplierValue,
    required double landThreshold,
    required Animation<double> animation,
  }) {
    if (isDropOut && cleared) {
      return showMultiplierResidue
          ? _buildMultiplierResidue(itemH)
          : const SizedBox.shrink();
    }

    final Widget symbolChild;
    if (!isDropOut && isScatter && widget.pulseScattersOnLanding) {
      symbolChild = ScatterPulse(
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
      symbolChild = MultiplierBombSymbol(
        itemH: itemH,
        multiplierValue: multiplierValue,
        labelAlignmentY: 0.15,
      );
    } else {
      symbolChild = Image.asset(
        key: ValueKey(
          'reel-symbol-${widget.columnIndex}-$rowIndex-'
          '$_activeSpinRevision-$assetPath-$isDropOut',
        ),
        assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.low,
        gaplessPlayback: false,
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
    final bool showMultiplierResidue = widget.multiplierResiduePositions
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
            rowIndex: index,
            itemH: itemH,
            isDropOut: isDropOut,
            cleared: cleared,
            showMultiplierResidue: showMultiplierResidue,
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
              ? (_targetSnapshot ?? widget.targetItems)
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
                  final showMultiplierResidue = widget
                      .multiplierResiduePositions
                      .contains(widget.columnIndex * 100 + i);
                  return Positioned(
                    top: i * itemH,
                    left: 0,
                    right: 0,
                    height: itemH,
                    child: Center(
                      child: showMultiplierResidue
                          ? _buildMultiplierResidue(itemH)
                          : const SizedBox.shrink(),
                    ),
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
            : (_targetSnapshot ?? widget.targetItems);
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

    return ScatterPulse(
      key: ValueKey(
        'manual-scatter-pulse-${widget.columnIndex}-$row-${widget.scatterPulseTrigger}',
      ),
      autoStart: true,
      child: cell,
    );
  }

  @override
  void dispose() {
    _runToken++;
    final targetReady = _targetReady;
    if (targetReady != null && !targetReady.isCompleted) {
      targetReady.complete();
    }
    widget.controller?.detach(this);
    _disposeCurrentController();
    super.dispose();
  }
}
