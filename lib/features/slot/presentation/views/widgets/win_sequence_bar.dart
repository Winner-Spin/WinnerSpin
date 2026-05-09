import 'package:flutter/material.dart';

import '../../../../../core/format/money_format.dart';
import 'win_amount_counter.dart';
import 'win_presentation_controller.dart';

/// Renders the current phase of [WinPresentationController] inside the
/// status bar slot. Stays under one widget so the bar's GlobalKey can
/// hand back a stable target rect for the multiplier flights.
class WinSequenceBar extends StatelessWidget {
  final WinPresentationController controller;
  final TextStyle baseStyle;
  final TextStyle accentStyle;

  /// Anchor for the running-sum text. Multipliers in flight aim at this
  /// key's centre so the asset lands on the same spot the sum lives,
  /// instead of the bar's geometric centre. The key follows whichever
  /// child currently holds that slot (placeholder before the first
  /// landing, the live sum after).
  final GlobalKey sumAnchorKey;

  /// When true the bar omits the Kazanç readout rows and only renders
  /// the running multiplier formula. Used by the free-spin layout where
  /// the strip's top half already shows the live total.
  final bool formulaOnly;

  const WinSequenceBar({
    super.key,
    required this.controller,
    required this.baseStyle,
    required this.accentStyle,
    required this.sumAnchorKey,
    this.formulaOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (formulaOnly) {
          // Formula-only mode: bar holds the running multiplier
          // formula across baseCounting → finalCounting and stays
          // empty everywhere else; the host slot's primary readout
          // carries the Kazanç value.
          switch (controller.phase) {
            case WinPresentationPhase.baseCounting:
            case WinPresentationPhase.multiplierCollecting:
            case WinPresentationPhase.finalCounting:
              return _formulaRow(
                base: controller.baseWin,
                sum: controller.runningSum,
                showMultiplySign: controller.multiplierFlightStarted,
                baseStyle: baseStyle,
                accentStyle: accentStyle,
              );
            case WinPresentationPhase.idle:
            case WinPresentationPhase.done:
              return const SizedBox.shrink();
          }
        }

        switch (controller.phase) {
          case WinPresentationPhase.idle:
            return const SizedBox.shrink();

          case WinPresentationPhase.baseCounting:
            // Static hold — the live cascade counter already counted
            // up to baseWin during the tumbles, so the bar just keeps
            // showing the value while the player reads it.
            return _kazancRow(
              accentStyle: accentStyle,
              valueWidget: Text(
                '₺${formatMoney(controller.baseWin)}',
                style: baseStyle,
              ),
            );

          case WinPresentationPhase.multiplierCollecting:
            return _formulaRow(
              base: controller.baseWin,
              sum: controller.runningSum,
              showMultiplySign: controller.multiplierFlightStarted,
              baseStyle: baseStyle,
              accentStyle: accentStyle,
            );

          case WinPresentationPhase.finalCounting:
          case WinPresentationPhase.done:
            // Final reveal counts from the base (already on screen at
            // the end of the multiplier formula) up to the total —
            // never resets to zero.
            return _kazancRow(
              accentStyle: accentStyle,
              valueWidget: WinAmountCounter(
                from: controller.baseWin,
                to: controller.totalWin,
                style: baseStyle,
                duration: WinPresentationController.finalCountUpDuration,
              ),
            );
        }
      },
    );
  }

  Widget _kazancRow({
    required TextStyle accentStyle,
    required Widget valueWidget,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('KAZANÇ', style: accentStyle),
        const SizedBox(width: 6),
        valueWidget,
      ],
    );
  }

  Widget _formulaRow({
    required double base,
    required int sum,
    required bool showMultiplySign,
    required TextStyle baseStyle,
    required TextStyle accentStyle,
  }) {
    // Layout — left half always shows the base. Right half evolves:
    //   • flight not started yet → empty
    //   • flight started, sum still 0 → bare "×" placeholder
    //   • after first landing → "× N"; on every new sum the value pops
    //     from 1.0 → ~1.5 → 1.0 in place (no crossfade) so the player
    //     reads it as the SAME running total being increased.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('₺${formatMoney(base)}', style: baseStyle),
          if (showMultiplySign) ...[
            const SizedBox(width: 8),
            Text('×', style: baseStyle),
            const SizedBox(width: 6),
            // Anchor for incoming multiplier flights. Holds a small
            // invisible placeholder before the first landing so the
            // anchor exists; once sum > 0 the live pulsing value
            // takes over the same slot.
            Container(
              key: sumAnchorKey,
              child: sum > 0
                  ? _PulsingValue(value: sum, style: accentStyle)
                  : Text(
                      '0',
                      style: accentStyle.copyWith(
                        color: const Color(0x00000000),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows [value] and runs a brief 1.0 → 1.5 → 1.0 scale pulse every
/// time [value] changes (and once on first mount). The text widget is
/// stable across updates so there's no crossfade — the player reads
/// the same running total being bumped up.
class _PulsingValue extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _PulsingValue({
    required this.value,
    required this.style,
  });

  @override
  State<_PulsingValue> createState() => _PulsingValueState();
}

class _PulsingValueState extends State<_PulsingValue>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 380);

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _pulseDuration);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_ctrl);
    // First appearance pulses immediately.
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _PulsingValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        alignment: Alignment.center,
        child: Text('${widget.value}', style: widget.style),
      ),
    );
  }
}
