import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/widgets/money_text.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/win_presentation_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/win/win_amount_counter.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/win/win_sequence_bar.dart';

void main() {
  testWidgets(
    'matches the free-spin formula and keeps the completed total static',
    (tester) async {
      final controller = WinPresentationController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WinSequenceBar(
              controller: controller,
              baseStyle: const TextStyle(fontSize: 18),
              accentStyle: const TextStyle(fontSize: 18),
              sumAnchorKey: GlobalKey(),
            ),
          ),
        ),
      );

      controller.start(
        baseWin: 100,
        multiplierValues: const [2],
        totalWin: 200,
      );
      await tester.pump(WinPresentationController.holdAfterBaseCountUp);
      controller.onMultiplierLanded(0);
      await tester.pump();

      expect(controller.phase, WinPresentationPhase.multiplierCollecting);
      expect(find.text('='), findsNothing);
      expect(find.byType(WinAmountCounter), findsNothing);

      controller.onMultiplierPresentationComplete(0);
      await tester.pump(
        WinPresentationController.postLandPulse +
            WinPresentationController.formulaToFinalGap,
      );

      expect(controller.phase, WinPresentationPhase.finalCounting);
      expect(find.byType(WinAmountCounter), findsOneWidget);

      await tester.pump(WinPresentationController.finalCountUpDuration);

      expect(controller.phase, WinPresentationPhase.done);
      expect(find.byType(WinAmountCounter), findsNothing);
      expect(
        tester
            .widgetList<MoneyText>(find.byType(MoneyText))
            .any((money) => money.text == '200.00'),
        isTrue,
      );
    },
  );
}
