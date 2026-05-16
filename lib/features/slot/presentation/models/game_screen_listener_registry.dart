import 'package:flutter/foundation.dart';

import '../viewmodels/game_viewmodel.dart';
import '../views/widgets/win_presentation_controller.dart';

class GameScreenListenerRegistry {
  GameScreenListenerRegistry({
    required this.viewModel,
    required this.winController,
    required this.onViewModelChange,
    required this.onFreeSpinStateChange,
    required this.onWinControllerChange,
  });

  final GameViewModel viewModel;
  final WinPresentationController winController;
  final VoidCallback onViewModelChange;
  final VoidCallback onFreeSpinStateChange;
  final VoidCallback onWinControllerChange;

  void attach() {
    viewModel.addListener(onViewModelChange);
    viewModel.balanceCtrl.addListener(onViewModelChange);
    viewModel.gridCtrl.addListener(onViewModelChange);
    viewModel.fsCtrl.addListener(onViewModelChange);
    viewModel.fsCtrl.addListener(onFreeSpinStateChange);
    viewModel.addListener(onFreeSpinStateChange);
    winController.addListener(onWinControllerChange);
  }

  void detach() {
    viewModel.removeListener(onViewModelChange);
    viewModel.balanceCtrl.removeListener(onViewModelChange);
    viewModel.gridCtrl.removeListener(onViewModelChange);
    viewModel.fsCtrl.removeListener(onViewModelChange);
    viewModel.fsCtrl.removeListener(onFreeSpinStateChange);
    viewModel.removeListener(onFreeSpinStateChange);
    winController.removeListener(onWinControllerChange);
  }
}
