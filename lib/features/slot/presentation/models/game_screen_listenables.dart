import 'package:flutter/foundation.dart';

import '../viewmodels/game_viewmodel.dart';
import '../ui_controllers/win_presentation_controller.dart';

class GameScreenListenables {
  final Listenable freeSpinVisual;
  final Listenable gridVisual;
  final Listenable balanceStatus;
  final Listenable fsInfo;
  final Listenable buyFeature;
  final Listenable anteToggle;
  final Listenable spinControls;
  final Listenable tumbleWin;

  GameScreenListenables({
    required GameViewModel viewModel,
    required WinPresentationController winController,
  }) : freeSpinVisual = Listenable.merge([viewModel, viewModel.fsCtrl]),
       gridVisual = Listenable.merge([viewModel, viewModel.gridCtrl]),
       balanceStatus = Listenable.merge([viewModel, viewModel.balanceCtrl]),
       fsInfo = Listenable.merge([
         viewModel,
         viewModel.fsCtrl,
         viewModel.gridCtrl,
       ]),
       buyFeature = Listenable.merge([
         viewModel,
         viewModel.balanceCtrl,
         viewModel.anteCtrl,
         viewModel.fsCtrl,
       ]),
       anteToggle = Listenable.merge([
         viewModel,
         viewModel.anteCtrl,
         viewModel.balanceCtrl,
         viewModel.fsCtrl,
       ]),
       spinControls = Listenable.merge([
         viewModel,
         viewModel.balanceCtrl,
         viewModel.fsCtrl,
         winController,
       ]),
       tumbleWin = Listenable.merge([
         viewModel,
         viewModel.balanceCtrl,
         viewModel.gridCtrl,
         winController,
       ]);
}
