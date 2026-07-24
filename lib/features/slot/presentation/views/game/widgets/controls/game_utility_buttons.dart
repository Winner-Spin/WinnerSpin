import 'package:flutter/material.dart';

import '../../../../models/game_stage_layout.dart';
import 'auto_spin_button.dart';
import 'info_button.dart';
import 'settings_button.dart';
import 'speed_button.dart';

class GameUtilityButtons extends StatelessWidget {
  final double screenH;
  final Listenable listenable;
  final bool Function() bigWinShowing;
  final bool Function() autoSpinning;
  final double Function() betAmount;
  final int Function() speedMultiplier;
  final VoidCallback onInfoTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAutoSpinTap;
  final VoidCallback onSpeedTap;

  const GameUtilityButtons({
    super.key,
    required this.screenH,
    required this.listenable,
    required this.bigWinShowing,
    required this.autoSpinning,
    required this.betAmount,
    required this.speedMultiplier,
    required this.onInfoTap,
    required this.onSettingsTap,
    required this.onAutoSpinTap,
    required this.onSpeedTap,
  });

  @override
  Widget build(BuildContext context) {
    final buttonTop = GameStageLayout.utilityButtonTop(screenH);

    return Stack(
      children: [
        Positioned(
          top: buttonTop,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ListenableBuilder(
                listenable: listenable,
                builder: (context, _) => InfoButton(
                  betAmount: betAmount(),
                  onTap: bigWinShowing() ? null : onInfoTap,
                ),
              ),
              ListenableBuilder(
                listenable: listenable,
                builder: (context, _) => AutoSpinButton(
                  onTap: bigWinShowing() || autoSpinning()
                      ? null
                      : onAutoSpinTap,
                ),
              ),
              ListenableBuilder(
                listenable: listenable,
                builder: (context, _) => SpeedButton(
                  level: speedMultiplier(),
                  onTap: bigWinShowing() ? null : onSpeedTap,
                ),
              ),
              SettingsButton(
                onTap: bigWinShowing() ? null : onSettingsTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
