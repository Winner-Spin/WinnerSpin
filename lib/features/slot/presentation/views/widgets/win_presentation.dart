import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/models/spin_result.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_collect_animation.dart';
import 'win_presentation_controller.dart';
import 'win_sequence_bar.dart';

/// Wires the [WinPresentationController] to the [WinSequenceBar] and
/// the multiplier collect overlay flights. Owns a [GlobalKey] on the
/// bar so the bar's true on-screen rect feeds the flight target.
///
/// The grid frame in screen coordinates is supplied by the caller —
/// [gridLeft], [gridTop], [gridWidth], [gridHeight] — so multiplier
/// origins can be computed from `MultiplierLanding`'s (column, row).
class WinPresentation extends StatefulWidget {
  /// Latest completed spin. Drives a fresh presentation when its
  /// identity changes.
  final SpinResult? spinResult;

  final double gridLeft;
  final double gridTop;
  final double gridWidth;
  final double gridHeight;

  final TextStyle baseStyle;
  final TextStyle accentStyle;

  /// Number of grid columns (6) and rows (5). Hardcoded fallbacks are
  /// fine but keeping these as inputs avoids a domain-import here.
  final int columns;
  final int rows;

  /// Fires the moment a multiplier asset finishes its on-cell pop and
  /// lifts off for the bar — host wires this to clear the grid symbol
  /// so the cell reads as consumed.
  final void Function(int column, int row)? onMultiplierLifted;

  /// Optional externally-owned controller. When provided, the host can
  /// observe phase / running-sum changes alongside this widget — used
  /// by the free-spin layout where the strip's top half mirrors the
  /// live total while the formula renders below.
  final WinPresentationController? controller;

  /// Forwards to [WinSequenceBar.formulaOnly] — see there.
  final bool formulaOnly;

  /// Optional externally-supplied flight target. If provided, the
  /// multiplier collect flights aim at this key's render rect instead
  /// of the bar's internal anchor — used when the host renders its own
  /// running-total widget elsewhere on the screen.
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
  // Anchored to the running-sum slot inside the bar — flights aim
  // here so the asset lands on top of the value the player is reading.
  final GlobalKey _sumAnchorKey = GlobalKey();

  // Identity of the spin currently being presented, so an unchanged
  // rebuild doesn't re-trigger the sequence.
  Object? _presentedSpin;

  // Sentinel — the activeIndex we've already started a flight for.
  // Stops the listener from re-launching a flight on every controller
  // notify (each post-land sum update would otherwise re-trigger the
  // same multiplier into an infinite loop).
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

    // No win OR no multipliers → don't run the sequence; leave the
    // status bar to its plain "PLACE YOUR BETS!" / count-up flow.
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
      // Only launch a flight when the active index has actually
      // advanced. Without this guard the post-land sum-update notify
      // would re-trigger the same multiplier endlessly.
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
    // Prefer the sum anchor so the asset lands directly on the running
    // sum text. Fall back to the bar's overall centre if the anchor
    // hasn't laid out yet (first frame), then to a grid-relative
    // position if the bar itself hasn't laid out either.
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
    final idx = _controller.activeIndex;
    if (result == null) return;
    if (idx < 0 || idx >= result.finalMultipliers.length) return;

    final landing = result.finalMultipliers[idx];
    final start = _cellCenter(landing.column, landing.row);
    final end = _flightTargetCenter();
    final cellW = widget.gridWidth / widget.columns;
    final cellH = widget.gridHeight / widget.rows;
    // Asset displays at the cell's smaller dimension so it sits cleanly
    // inside the multiplier symbol's cell at start.
    final cellSize = cellW < cellH ? cellW : cellH;

    // The cell shows the bomb frozen on frame 0; this overlay plays the
    // full Lottie timeline (fuse → blast → tail) on top. We don't await
    // the whole timeline — we kick off the bomb in parallel, then wait
    // only until the blast moment fires so the multiplier value can lift
    // off in sync with the explosion. The smoke tail keeps playing
    // alongside the collect flight.
    // Wipe the resting bomb sprite from the grid the instant the
    // overlay launches — otherwise the cell's frozen bomb sits behind
    // the playing Lottie all through the fuse and blast frames, which
    // reads as "two bombs" until the cell clear that used to be tied
    // to the blast moment finally fires.
    widget.onMultiplierLifted?.call(landing.column, landing.row);

    final blastCompleter = Completer<void>();
    final bombFuture = MultiplierBombAnimation.play(
      context: context,
      cellCenter: start,
      cellSize: cellSize,
      multiplierValue: landing.value,
      onBlast: () {
        if (!blastCompleter.isCompleted) blastCompleter.complete();
      },
    );

    await blastCompleter.future;
    if (!mounted) return;

    // Landing is triggered the moment the floating asset crosses the
    // approach threshold (~70% of the flight) — well before the asset
    // has fully faded. The bar pulse and the asset's last 30% of fade
    // overlap, reading as a single merge instead of "lands then
    // pulses". Collect runs in parallel with the bomb's smoke tail.
    await Future.wait([
      bombFuture,
      MultiplierCollectAnimation.play(
        context: context,
        start: start,
        end: end,
        value: landing.value,
        cellSize: cellSize * 0.67,
        // End size at the bar tracks the bar's text height — the value
        // shrinks to about a regular symbol slot in the running-sum text.
        endSize: 30,
        settleDuration: WinPresentationController.multiplierSettleDuration,
        flightDuration: WinPresentationController.multiplierFlightDuration,
        onApproaching: () {
          if (!mounted) return;
          _controller.onMultiplierLanded();
        },
      ),
    ]);
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
      ),
    );
  }
}
