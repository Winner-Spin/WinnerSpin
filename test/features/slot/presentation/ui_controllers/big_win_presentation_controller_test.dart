import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/models/multiplier_landing.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/big_win_presentation_controller.dart';

void main() {
  testWidgets('does not replay a persisted last win during app startup', (
    tester,
  ) async {
    final controller = BigWinPresentationController();
    var showCalls = 0;

    controller.trackNormalWin(
      isInFreeSpins: false,
      lastWin: 5000,
      result: () => null,
      isMounted: () => true,
      showBigWin: (_) => showCalls++,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(showCalls, 0);
    controller.dispose();
  });

  testWidgets('uses the current result when balance listeners run first', (
    tester,
  ) async {
    final controller = BigWinPresentationController();
    addTearDown(controller.dispose);
    var visibleResult = _result();
    var showCalls = 0;

    controller.trackNormalWin(
      isInFreeSpins: false,
      lastWin: 5000,
      result: () => visibleResult,
      isMounted: () => true,
      showBigWin: (_) => showCalls++,
    );
    visibleResult = _result(
      baseWin: 2500,
      multipliers: const [MultiplierLanding(column: 0, row: 0, value: 2)],
    );

    await tester.pump(const Duration(seconds: 1));

    expect(showCalls, 0);
  });
}

SpinResult _result({
  double baseWin = 0,
  List<MultiplierLanding> multipliers = const [],
}) {
  return SpinResult(
    initialGrid: const [],
    tumbles: const [],
    totalWin: baseWin,
    baseWin: baseWin,
    finalMultipliers: multipliers,
    tumbleCount: 0,
    freeSpinsTriggered: false,
    scatterCount: 0,
    scatterPayout: 0,
  );
}
