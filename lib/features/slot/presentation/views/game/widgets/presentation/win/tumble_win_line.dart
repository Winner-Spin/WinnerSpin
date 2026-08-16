import 'package:flutter/material.dart';

import '../../../../../../../../core/format/money_format.dart';
import '../../../../../../../../core/widgets/money_text.dart';
import '../../../../../../domain/models/spin_result.dart';
import '../../../../../models/game_presentation_timings.dart';
import '../../../../../models/spin_result_presentation_rules.dart';
import '../effects/pulsing_multiplier_sum.dart';
import 'win_amount_counter.dart';
import '../../../../../ui_controllers/win_presentation_controller.dart';

class TumbleWinLine extends StatelessWidget {
  final bool isFlyingTumble;
  final bool isPostWinPulsing;
  final bool isBusy;
  final double liveTumbleWin;
  final double lastWin;
  final SpinResult? result;
  final WinPresentationController controller;
  final Key? anchorKey;
  final TextStyle labelStyle;
  final TextStyle valueStyle;
  final bool vibrationEnabled;

  const TumbleWinLine({
    super.key,
    required this.isFlyingTumble,
    this.isPostWinPulsing = false,
    required this.isBusy,
    required this.liveTumbleWin,
    required this.lastWin,
    required this.result,
    required this.controller,
    required this.anchorKey,
    required this.labelStyle,
    required this.valueStyle,
    required this.vibrationEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final line = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('TUMBLE WIN', style: labelStyle),
        const SizedBox(width: 6),
        _buildValue(),
      ],
    );
    return TumbleWinPulse(active: isPostWinPulsing, child: line);
  }

  Widget _buildValue() {
    if (isFlyingTumble) {
      return _moneyValue(0);
    }

    if (isBusy) {
      return Container(
        key: anchorKey,
        child: WinAmountCounter(
          to: liveTumbleWin,
          style: valueStyle,
          duration: GamePresentationTimings.tumbleLineLiveCount,
          vibrationEnabled: vibrationEnabled,
        ),
      );
    }

    final spinResult = result;
    if (spinResult == null) {
      return _moneyValue(lastWin);
    }

    final hasSequence = SpinResultPresentationRules.hasMultiplierSequence(
      spinResult,
    );
    if (!hasSequence) {
      return _moneyValue(spinResult.totalWin);
    }

    switch (controller.phase) {
      case WinPresentationPhase.idle:
      case WinPresentationPhase.baseCounting:
        return _moneyValue(spinResult.baseWin, lineTopExtend: 0.9);

      case WinPresentationPhase.multiplierCollecting:
        return _buildMultiplierCollectingValue(spinResult);

      case WinPresentationPhase.finalCounting:
        return Container(
          key: anchorKey,
          child: WinAmountCounter(
            from: controller.baseWin,
            to: spinResult.totalWin,
            style: valueStyle,
            duration: WinPresentationController.finalCountUpDuration,
            vibrationEnabled: vibrationEnabled,
          ),
        );

      case WinPresentationPhase.done:
        return _moneyValue(spinResult.totalWin, lineTopExtend: 0.9);
    }
  }

  Widget _buildMultiplierCollectingValue(SpinResult spinResult) {
    final sum = controller.runningSum;
    final showMultiplySign = controller.multiplierFlightStarted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        _plainMoney(spinResult.baseWin),
        if (showMultiplySign) ...[
          const SizedBox(width: 8),
          Text(String.fromCharCode(0x00D7), style: valueStyle),
          const SizedBox(width: 6),
          Container(
            key: anchorKey,
            child: sum > 0
                ? PulsingMultiplierSum(value: sum, style: labelStyle)
                : Text(
                    '0',
                    style: labelStyle.copyWith(color: const Color(0x00000000)),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _moneyValue(double amount, {double lineTopExtend = 0}) {
    return Container(
      key: anchorKey,
      child: _plainMoney(amount, lineTopExtend: lineTopExtend),
    );
  }

  Widget _plainMoney(double amount, {double lineTopExtend = 0}) {
    return MoneyText(
      text: formatMoney(amount),
      style: valueStyle,
      symbolOffset: const Offset(0, 1.5),
      lineYOffset: 0.75,
      lineLengthScale: 0.94,
      lineTopExtend: lineTopExtend,
    );
  }
}

class TumbleWinPulse extends StatefulWidget {
  const TumbleWinPulse({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<TumbleWinPulse> createState() => _TumbleWinPulseState();
}

class _TumbleWinPulseState extends State<TumbleWinPulse>
    with SingleTickerProviderStateMixin {
  static const double _peakScale = 1.12;

  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: GamePresentationTimings.freeSpinPostWinPulse,
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: _peakScale,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: _peakScale,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_controller);
    if (widget.active) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(covariant TumbleWinPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _controller.forward(from: 0);
    } else if (oldWidget.active && !widget.active && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}
