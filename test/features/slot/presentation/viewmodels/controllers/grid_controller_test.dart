import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/grid_controller.dart';

void main() {
  test('multiplier residue changes notify only the grid visual channel', () {
    final controller = GridController(
      List.generate(
        GridController.columns,
        (_) => List.filled(GridController.rows, ''),
      ),
    );
    addTearDown(controller.dispose);

    var controllerNotifications = 0;
    var visualNotifications = 0;
    controller.addListener(() => controllerNotifications++);
    controller.multiplierVisualListenable.addListener(
      () => visualNotifications++,
    );

    controller.clearMultiplierPosition(2, 3);
    controller.revealMultiplierResidue(2, 3);
    controller.revealMultiplierResidue(2, 3);

    expect(controller.clearedPositions, contains(203));
    expect(controller.multiplierResiduePositions, contains(203));
    expect(visualNotifications, 2);
    expect(controllerNotifications, 0);

    controller.clearMultiplierResidues();

    expect(controller.clearedPositions, isEmpty);
    expect(controller.multiplierResiduePositions, isEmpty);
    expect(visualNotifications, 3);
    expect(controllerNotifications, 0);

    controller.setGrid(controller.grid);
    expect(controllerNotifications, 1);
  });
}
