import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../audio/ui_click_sound.dart';
import '../navigation/game_screen_navigation.dart';
import '../viewmodels/game_viewmodel.dart';
import 'game_asset_precache_service.dart';

class GameScreenStartupService {
  const GameScreenStartupService();

  void start({
    required BuildContext context,
    required GameViewModel viewModel,
    required GameAssetPrecacheService assetPrecacheService,
    required FirstLaunchDisclaimerRepository disclaimerRepository,
    required bool Function() isMounted,
  }) {
    UiClickSound.enabled = viewModel.soundEffects;
    unawaited(UiClickSound.preload());
    viewModel.fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      assetPrecacheService.precacheInitialAssets(
        context: context,
        openingGrid: viewModel.grid,
        isMounted: isMounted,
      );
      unawaited(
        GameScreenNavigation.maybeShowFirstLaunchDisclaimer(
          context: context,
          repository: disclaimerRepository,
        ),
      );
    });
  }
}
