import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/spin_result.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_collect_animation.dart';
import 'win_presentation_controller.dart';
import 'win_sequence_bar.dart';

class WinPresentation extends StatefulWidget {
  final SpinResult? spinResult;

  final double gridLeft;
  final double gridTop;
  final double gridWidth;
  final double gridHeight;

  final TextStyle baseStyle;
  final TextStyle accentStyle;

  final int columns;
  final int rows;

  final void Function(int column, int row)? onMultiplierLifted;

  final WinPresentationController? controller;

  final bool formulaOnly;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int speedMultiplier;

  final GlobalKey? flightTargetKey;

  const WinPresentation({
    super.key,
    required this.spinResult,
    required this.gridLeft,
    required this.gridTop,
    required this.gridWidth,
    required this.gridHeight,
    required this.baseStyle,
    required this.accentStyle,
    this.columns = 6,
    this.rows = 5,
    this.onMultiplierLifted,
    this.controller,
    this.formulaOnly = false,
    this.soundEnabled = true,
    this.vibrationEnabled = false,
    this.speedMultiplier = 1,
    this.flightTargetKey,
  });

  @override
  State<WinPresentation> createState() => _WinPresentationState();
}

class _WinPresentationState extends State<WinPresentation> {
  late final WinPresentationController _controller =
      widget.controller ?? WinPresentationController();
  late final bool _ownsController = widget.controller == null;
  final GlobalKey _barKey = GlobalKey();
  final GlobalKey _sumAnchorKey = GlobalKey();

  Object? _presentedSpin;

  int _flyingForIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onPhaseChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeStart();
    });
  }

  @override
  void didUpdateWidget(covariant WinPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeStart();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onPhaseChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _maybeStart() {
    final result = widget.spinResult;
    if (result == null) {
      if (_presentedSpin != null) {
        _presentedSpin = null;
        _controller.reset();
      }
      return;
    }
    if (identical(result, _presentedSpin)) return;

    _presentedSpin = result;
    _flyingForIndex = -1;

    final hasBase = result.baseWin > 0;
    final hasMultipliers = result.finalMultipliers.isNotEmpty;

    if (!hasBase || !hasMultipliers) {
      _controller.reset();
      return;
    }

    _controller.start(
      baseWin: result.baseWin,
      multiplierValues: [for (final m in result.finalMultipliers) m.value],
      totalWin: result.totalWin,
    );
  }

  void _onPhaseChanged() {
    final phase = _controller.phase;
    if (phase == WinPresentationPhase.multiplierCollecting) {
      final idx = _controller.activeIndex;
      if (idx != _flyingForIndex) {
        _flyingForIndex = idx;
        _flyActiveMultiplier();
      }
    } else {
      _flyingForIndex = -1;
    }
  }

  Offset _cellCenter(int column, int row) {
    final cellW = widget.gridWidth / widget.columns;
    final cellH = widget.gridHeight / widget.rows;
    return Offset(
      widget.gridLeft + column * cellW + cellW / 2,
      widget.gridTop + row * cellH + cellH / 2,
    );
  }

  Offset _flightTargetCenter() {
    final anchorKey = widget.flightTargetKey ?? _sumAnchorKey;
    final anchorBox =
        anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (anchorBox != null) {
      final topLeft = anchorBox.localToGlobal(Offset.zero);
      return Offset(
        topLeft.dx + anchorBox.size.width / 2,
        topLeft.dy + anchorBox.size.height / 2,
      );
    }
    final barBox = _barKey.currentContext?.findRenderObject() as RenderBox?;
    if (barBox != null) {
      final topLeft = barBox.localToGlobal(Offset.zero);
      return Offset(
        topLeft.dx + barBox.size.width / 2,
        topLeft.dy + barBox.size.height / 2,
      );
    }
    return Offset(
      widget.gridLeft + widget.gridWidth / 2,
      widget.gridTop + widget.gridHeight + 40,
    );
  }

  Future<void> _flyActiveMultiplier() async {
    final result = widget.spinResult;
    final landedIdx = _controller.activeIndex;
    if (result == null) return;
    if (landedIdx < 0 || landedIdx >= result.finalMultipliers.length) return;

    final landing = result.finalMultipliers[landedIdx];
    final start = _cellCenter(landing.column, landing.row);
    final end = _flightTargetCenter();
    final cellW = widget.gridWidth / widget.columns;
    final cellH = widget.gridHeight / widget.rows;
    final cellSize = cellW < cellH ? cellW : cellH;

    widget.onMultiplierLifted?.call(landing.column, landing.row);

    final blastCompleter = Completer<void>();
    final bombFuture = MultiplierBombAnimation.play(
      context: context,
      cellCenter: start,
      cellSize: cellSize,
      multiplierValue: landing.value,
      soundEnabled: widget.soundEnabled,
      speedMultiplier: widget.speedMultiplier,
      onBlast: () {
        if (!blastCompleter.isCompleted) blastCompleter.complete();
      },
    );
    unawaited(
      bombFuture.then((_) async {
        await Future.delayed(WinPresentationController.interMultiplierGap);
        if (mounted) _controller.onBombBlastComplete();
      }),
    );

    await blastCompleter.future;
    if (!mounted) return;

    await MultiplierCollectAnimation.play(
      context: context,
      start: start,
      end: end,
      value: landing.value,
      cellSize: cellSize * 0.67,
      endSize: 30,
      settleDuration: WinPresentationController.multiplierSettleDuration,
      flightDuration: WinPresentationController.multiplierFlightDuration,
      onApproaching: () {
        if (!mounted) return;
        _controller.onMultiplierLanded(landedIdx);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _barKey,
      child: WinSequenceBar(
        controller: _controller,
        baseStyle: widget.baseStyle,
        accentStyle: widget.accentStyle,
        sumAnchorKey: _sumAnchorKey,
        formulaOnly: widget.formulaOnly,
        vibrationEnabled: widget.vibrationEnabled,
      ),
    );
  }
}
