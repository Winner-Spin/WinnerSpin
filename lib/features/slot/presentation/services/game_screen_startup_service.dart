import 'dart:async';

import 'package:flutter/widgets.dart';

import '../audio/multiplier_bomb_explosion_sound.dart';
import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';
import 'game_asset_precache_service.dart';

class GameScreenStartupService {
  const GameScreenStartupService();

  void start({
    required BuildContext context,
    required GameViewModel viewModel,
    required GameAssetPrecacheService assetPrecacheService,
    required bool Function() isMounted,
  }) {
    UiClickSound.enabled = viewModel.soundEffects;
    unawaited(UiClickSound.preload());
    if (viewModel.soundEffects) {
      unawaited(MultiplierBombExplosionSound.preload());
    }
    viewModel.fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      assetPrecacheService.precacheInitialAssets(
        context: context,
        openingGrid: viewModel.grid,
        isMounted: isMounted,
      );
    });
  }
}
