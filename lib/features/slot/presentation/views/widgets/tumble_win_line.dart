import 'package:flutter/material.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../../domain/models/spin_result.dart';
import 'pulsing_multiplier_sum.dart';
import 'win_amount_counter.dart';
import 'win_presentation_controller.dart';

class TumbleWinLine extends StatelessWidget {
  final bool isFlyingTumble;
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('TUMBLE WIN', style: labelStyle),
        const SizedBox(width: 6),
        _buildValue(),
      ],
    );
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
          duration: const Duration(milliseconds: 350),
          vibrationEnabled: vibrationEnabled,
        ),
      );
    }

    final spinResult = result;
    if (spinResult == null) {
      return _moneyValue(lastWin);
    }

    final hasSequence =
        spinResult.baseWin > 0 && spinResult.finalMultipliers.isNotEmpty;
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
