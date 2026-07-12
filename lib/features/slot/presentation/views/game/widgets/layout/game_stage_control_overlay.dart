import 'package:flutter/material.dart';

import '../../../../models/game_screen_listenables.dart';
import '../../../../models/game_screen_text_styles.dart';
import '../../../../models/game_stage_metrics.dart';
import '../../../../viewmodels/game_viewmodel.dart';
import 'game_bottom_info_slot.dart';
import '../controls/game_feature_controls.dart';
import '../controls/game_spin_controls_slot.dart';
import '../controls/game_utility_buttons.dart';

class GameStageControlOverlay extends StatelessWidget {
  const GameStageControlOverlay({
    super.key,
    required this.metrics,
    required this.viewModel,
    required this.listenables,
    required this.styles,
    required this.isFreeSpinVisualMode,
    required this.displayedFreeSpinsRemaining,
    required this.isBigWinShowing,
    required this.isCelebrationActive,
    required this.onBuyFeatureTap,
    required this.onInfoTap,
    required this.onSettingsTap,
    required this.onAutoSpinTap,
  });

  final GameStageMetrics metrics;
  final GameViewModel viewModel;
  final GameScreenListenables listenables;
  final GameScreenTextStyles styles;
  final bool Function() isFreeSpinVisualMode;
  final int Function() displayedFreeSpinsRemaining;
  final bool Function() isBigWinShowing;
  final bool Function() isCelebrationActive;
  final VoidCallback onBuyFeatureTap;
  final VoidCallback onInfoTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAutoSpinTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GameFeatureControls(
          screenH: metrics.screenH,
          screenW: metrics.screenW,
          buyFeatureListenable: listenables.buyFeature,
          anteToggleListenable: listenables.anteToggle,
          isFreeSpinVisualMode: isFreeSpinVisualMode,
          isBigWinShowing: isBigWinShowing,
          isBusy: () => viewModel.isBusy,
          isCelebrationActive: isCelebrationActive,
          anteBetActive: () => viewModel.anteBetActive,
          canBuyFreeSpinsForUi: () => viewModel.canBuyFreeSpinsForUi,
          isAutoSpinning: () => viewModel.isAutoSpinning,
          isInFreeSpins: () => viewModel.isInFreeSpins,
          vibrationEnabled: () => viewModel.vibration,
          buyFeaturePrice: () => viewModel.buyFeaturePrice,
          anteCost: () => viewModel.anteCost,
          onBuyFeatureTap: onBuyFeatureTap,
          onAnteTap: viewModel.toggleAnteBet,
        ),
        GameSpinControlsSlot(
          screenH: metrics.screenH,
          listenable: listenables.spinControls,
          autoSpinActive: () => viewModel.isAutoSpinning,
          bigWinShowing: isBigWinShowing,
          spinning: () => viewModel.isBusy || isCelebrationActive(),
          canDecreaseBet: () => viewModel.canDecreaseBet,
          canIncreaseBet: () => viewModel.canIncreaseBet,
          isInFreeSpins: () => viewModel.isInFreeSpins,
          autoSpinsRemaining: () => viewModel.autoSpinsRemaining,
          freeSpinsRemaining: displayedFreeSpinsRemaining,
          onDecreaseBet: viewModel.decreaseBet,
          onIncreaseBet: viewModel.increaseBet,
          onSpin: viewModel.spin,
          onStopAutoSpin: viewModel.stopAutoSpin,
        ),
        GameUtilityButtons(
          screenH: metrics.screenH,
          screenW: metrics.screenW,
          listenable: viewModel,
          bigWinShowing: isBigWinShowing,
          autoSpinning: () => viewModel.isAutoSpinning,
          betAmount: () => viewModel.betAmount,
          speedMultiplier: () => viewModel.speedMultiplier,
          onInfoTap: onInfoTap,
          onSettingsTap: onSettingsTap,
          onAutoSpinTap: onAutoSpinTap,
          onSpeedTap: viewModel.toggleSpeed,
        ),
        GameBottomInfoSlot(
          balanceListenable: viewModel.balanceCtrl,
          balance: () => viewModel.balance,
          betAmount: () => viewModel.betAmount,
          labelStyle: styles.bottomLabel,
          valueStyle: styles.bottomValue,
          clockStyle: styles.bottomClock,
        ),
      ],
    );
  }
}
