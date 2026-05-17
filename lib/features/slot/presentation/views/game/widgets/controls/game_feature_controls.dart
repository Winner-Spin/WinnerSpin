import 'package:flutter/material.dart';

import 'buy_feature_button.dart';
import 'double_chance_button.dart';

class GameFeatureControls extends StatelessWidget {
  final double screenH;
  final double screenW;
  final Listenable buyFeatureListenable;
  final Listenable anteToggleListenable;
  final bool Function() isFreeSpinVisualMode;
  final bool Function() isBigWinShowing;
  final bool Function() isBusy;
  final bool Function() isCelebrationActive;
  final bool Function() anteBetActive;
  final bool Function() canBuyFreeSpinsForUi;
  final bool Function() isAutoSpinning;
  final bool Function() isInFreeSpins;
  final bool Function() vibrationEnabled;
  final double Function() buyFeaturePrice;
  final double Function() anteCost;
  final VoidCallback onBuyFeatureTap;
  final VoidCallback onAnteTap;

  const GameFeatureControls({
    super.key,
    required this.screenH,
    required this.screenW,
    required this.buyFeatureListenable,
    required this.anteToggleListenable,
    required this.isFreeSpinVisualMode,
    required this.isBigWinShowing,
    required this.isBusy,
    required this.isCelebrationActive,
    required this.anteBetActive,
    required this.canBuyFreeSpinsForUi,
    required this.isAutoSpinning,
    required this.isInFreeSpins,
    required this.vibrationEnabled,
    required this.buyFeaturePrice,
    required this.anteCost,
    required this.onBuyFeatureTap,
    required this.onAnteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: screenH * 0.55,
          left: screenW * 0.08,
          child: ListenableBuilder(
            listenable: buyFeatureListenable,
            builder: (context, _) {
              if (isFreeSpinVisualMode()) {
                return const SizedBox.shrink();
              }
              final passive =
                  isBigWinShowing() || isBusy() || isCelebrationActive();
              return RepaintBoundary(
                child: BuyFeatureButton(
                  price: buyFeaturePrice(),
                  disabled:
                      anteBetActive() || passive || !canBuyFreeSpinsForUi(),
                  vibrationEnabled: vibrationEnabled(),
                  onTap: onBuyFeatureTap,
                  width: screenW * 0.39,
                  height: screenW * 0.22,
                ),
              );
            },
          ),
        ),
        Positioned(
          top: screenH * 0.55,
          right: screenW * 0.08,
          child: ListenableBuilder(
            listenable: anteToggleListenable,
            builder: (context, _) {
              if (isFreeSpinVisualMode()) {
                return const SizedBox.shrink();
              }
              return RepaintBoundary(
                child: DoubleChanceButton(
                  betAmount: anteCost(),
                  isOn: anteBetActive(),
                  disabled:
                      isBigWinShowing() ||
                      isBusy() ||
                      isAutoSpinning() ||
                      isInFreeSpins(),
                  vibrationEnabled: vibrationEnabled(),
                  onTap: onAnteTap,
                  width: screenW * 0.39,
                  height: screenW * 0.22,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
