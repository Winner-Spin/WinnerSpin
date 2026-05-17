import 'package:flutter/material.dart';

import '../../../../../../../core/format/money_format.dart';
import '../../../../../../../core/widgets/money_text.dart';
import 'win_amount_counter.dart';
import 'win_presentation_controller.dart';

class WinSequenceBar extends StatelessWidget {
  final WinPresentationController controller;
  final TextStyle baseStyle;
  final TextStyle accentStyle;

  final GlobalKey sumAnchorKey;

  final bool formulaOnly;
  final bool vibrationEnabled;

  const WinSequenceBar({
    super.key,
    required this.controller,
    required this.baseStyle,
    required this.accentStyle,
    required this.sumAnchorKey,
    this.formulaOnly = false,
    this.vibrationEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (formulaOnly) {
          return const SizedBox.shrink();
        }

        switch (controller.phase) {
          case WinPresentationPhase.idle:
            return const SizedBox.shrink();

          case WinPresentationPhase.baseCounting:
            return _kazancRow(
              accentStyle: accentStyle,
              valueWidget: MoneyText(
                text: formatMoney(controller.baseWin),
                style: baseStyle,
                symbolOffset: const Offset(0, 1.5),
                lineYOffset: 0.75,
                lineLengthScale: 0.94,
                lineTopExtend: 0.9,
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
            return _kazancRow(
              accentStyle: accentStyle,
              valueWidget: WinAmountCounter(
                from: controller.baseWin,
                to: controller.totalWin,
                style: baseStyle,
                duration: WinPresentationController.finalCountUpDuration,
                vibrationEnabled: vibrationEnabled,
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
        Text('WIN', style: accentStyle),
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
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          MoneyText(
            text: formatMoney(base),
            style: baseStyle,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
          ),
          if (showMultiplySign) ...[
            const SizedBox(width: 8),
            Text('×', style: baseStyle),
            const SizedBox(width: 6),
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
            if (sum > 0) ...[
              const SizedBox(width: 8),
              Text('=', style: baseStyle),
              const SizedBox(width: 6),
              WinAmountCounter(
                from: base,
                to: base * sum,
                style: accentStyle,
                duration: const Duration(milliseconds: 350),
                vibrationEnabled: vibrationEnabled,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _PulsingValue extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _PulsingValue({required this.value, required this.style});

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
        tween: Tween<double>(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_ctrl);
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
