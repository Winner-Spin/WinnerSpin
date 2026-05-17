import 'package:flutter/material.dart';

import '../../../../../../../../core/format/money_format.dart';
import '../../../../../../../../core/widgets/money_text.dart';
import '../../../../../../domain/models/spin_result.dart';
import '../../../../../models/game_presentation_timings.dart';
import '../../../../../models/spin_result_presentation_rules.dart';
import 'win_amount_counter.dart';
import 'win_presentation.dart';
import '../../../../../ui_controllers/win_presentation_controller.dart';

class GameStatusText extends StatelessWidget {
  final bool showInsufficientFundsHint;
  final bool isFreeSpinVisualMode;
  final bool isTumbling;
  final bool isBusy;
  final bool isAutoSpinning;
  final bool lastSpinWasFreeSpin;
  final double freeSpinAccumulatedWin;
  final double liveTumbleWin;
  final double lastWin;
  final SpinResult? result;
  final WinPresentationController winController;
  final double screenH;
  final double screenW;
  final double gridLeft;
  final double gridRight;
  final TextStyle baseStyle;
  final TextStyle accentStyle;
  final TextStyle insufficientStyle;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int speedMultiplier;
  final Key? kazancAnchorKey;
  final void Function(int column, int row) onMultiplierLifted;

  const GameStatusText({
    super.key,
    required this.showInsufficientFundsHint,
    required this.isFreeSpinVisualMode,
    required this.isTumbling,
    required this.isBusy,
    required this.isAutoSpinning,
    required this.lastSpinWasFreeSpin,
    required this.freeSpinAccumulatedWin,
    required this.liveTumbleWin,
    required this.lastWin,
    required this.result,
    required this.winController,
    required this.screenH,
    required this.screenW,
    required this.gridLeft,
    required this.gridRight,
    required this.baseStyle,
    required this.accentStyle,
    required this.insufficientStyle,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.speedMultiplier,
    required this.kazancAnchorKey,
    required this.onMultiplierLifted,
  });

  @override
  Widget build(BuildContext context) {
    if (showInsufficientFundsHint) {
      return Text('PLEASE DEPOSIT MONEY!', style: insufficientStyle);
    }

    if (isFreeSpinVisualMode) {
      return _winCounterRow(
        to: freeSpinAccumulatedWin,
        duration: GamePresentationTimings.statusFreeSpinWinCount,
        anchorKey: kazancAnchorKey,
      );
    }

    if (isTumbling && liveTumbleWin > 0) {
      return _winCounterRow(
        to: liveTumbleWin,
        duration: GamePresentationTimings.statusTumbleWinCount,
      );
    }

    if (lastWin > 0 && !isBusy) {
      final spinResult = result;
      final hasMultiplierSequence =
          SpinResultPresentationRules.shouldShowMainWinSequence(
            result: spinResult,
            lastSpinWasFreeSpin: lastSpinWasFreeSpin,
            isFreeSpinVisualMode: isFreeSpinVisualMode,
          );

      if (hasMultiplierSequence) {
        return WinPresentation(
          key: ValueKey<double>(lastWin),
          controller: winController,
          spinResult: spinResult,
          gridLeft: gridLeft,
          gridTop: screenH * 0.195,
          gridWidth: screenW - gridLeft - gridRight,
          gridHeight: screenH * 0.32,
          baseStyle: baseStyle,
          accentStyle: accentStyle,
          soundEnabled: soundEnabled,
          vibrationEnabled: vibrationEnabled,
          speedMultiplier: speedMultiplier,
          onMultiplierLifted: onMultiplierLifted,
        );
      }

      return _winMoneyRow(lastWin);
    }

    if (isBusy || isAutoSpinning) {
      return Text('GOOD LUCK!', style: baseStyle);
    }

    return Text('PLACE YOUR BETS!', style: baseStyle);
  }

  Widget _winCounterRow({
    required double to,
    required Duration duration,
    Key? anchorKey,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('WIN', style: accentStyle),
        const SizedBox(width: 6),
        Container(
          key: anchorKey,
          child: WinAmountCounter(
            to: to,
            style: baseStyle,
            duration: duration,
            vibrationEnabled: vibrationEnabled,
          ),
        ),
      ],
    );
  }

  Widget _winMoneyRow(double amount) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('WIN', style: accentStyle),
        const SizedBox(width: 6),
        MoneyText(
          text: formatMoney(amount),
          style: baseStyle,
          symbolOffset: const Offset(0, 1.5),
          lineYOffset: 0.75,
          lineLengthScale: 0.94,
          lineTopExtend: 0.9,
        ),
      ],
    );
  }
}
