import 'package:flutter_test/flutter_test.dart';
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
}
