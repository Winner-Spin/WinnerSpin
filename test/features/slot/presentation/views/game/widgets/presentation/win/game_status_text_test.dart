import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/widgets/money_text.dart';
import 'package:winner_spin/features/slot/presentation/models/free_spin_presentation_state.dart';
import 'package:winner_spin/features/slot/presentation/models/game_presentation_timings.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/win_presentation_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/win/game_status_text.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/win/win_amount_counter.dart';

void main() {
  testWidgets(
    'renders a consecutive natural entry win before the first Free Spin',
    (tester) async {
      final presentation = FreeSpinPresentationState()
        ..updateFreeSpinMode(true)
        ..updateLastSeenWin(25)
        ..updateFreeSpinMode(false);

      expect(presentation.shouldResetRound(true), isTrue);
      presentation
        ..resetRound()
        ..updateFreeSpinMode(true);
      expect(presentation.shouldCaptureLastWin(10), isTrue);
      presentation
        ..capturePendingSpinWin(10)
        ..commitPendingSpinWin();

      final winController = WinPresentationController();
      addTearDown(winController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: GameStatusText(
                showInsufficientFundsHint: false,
                isFreeSpinVisualMode: true,
                isTumbling: false,
                isBusy: false,
                isAutoSpinning: false,
                lastSpinWasFreeSpin: false,
                freeSpinAccumulatedWin: presentation.accumulatedWin,
                liveTumbleWin: 0,
                lastWin: 10,
                result: null,
                winController: winController,
                screenH: 800,
                screenW: 400,
                gridLeft: 20,
                gridRight: 20,
                baseStyle: const TextStyle(fontSize: 18),
                accentStyle: const TextStyle(fontSize: 18),
                insufficientStyle: const TextStyle(fontSize: 18),
                soundEnabled: false,
                vibrationEnabled: false,
                speedMultiplier: 1,
                kazancAnchorKey: const ValueKey('free-spin-win-anchor'),
                onMultiplierLifted: (_, _) {},
                onMultiplierBlastComplete: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('WIN'), findsOneWidget);
      expect(find.byType(WinAmountCounter), findsNothing);
      expect(tester.widget<MoneyText>(find.byType(MoneyText)).text, '10.00');
      final renderedAmount = tester.widget<RichText>(
        find.descendant(
          of: find.byType(MoneyText),
          matching: find.byType(RichText),
        ),
      );
      expect(renderedAmount.text.toPlainText(), endsWith('10.00'));
    },
  );

  testWidgets('uses the free-spin tumble count duration in the farm', (
    tester,
  ) async {
    final winController = WinPresentationController();
    addTearDown(winController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameStatusText(
            showInsufficientFundsHint: false,
            isFreeSpinVisualMode: false,
            isTumbling: true,
            isBusy: true,
            isAutoSpinning: false,
            lastSpinWasFreeSpin: false,
            freeSpinAccumulatedWin: 0,
            liveTumbleWin: 50,
            lastWin: 0,
            result: null,
            winController: winController,
            screenH: 800,
            screenW: 400,
            gridLeft: 20,
            gridRight: 20,
            baseStyle: const TextStyle(fontSize: 18),
            accentStyle: const TextStyle(fontSize: 18),
            insufficientStyle: const TextStyle(fontSize: 18),
            soundEnabled: false,
            vibrationEnabled: false,
            speedMultiplier: 1,
            kazancAnchorKey: null,
            onMultiplierLifted: (_, _) {},
            onMultiplierBlastComplete: (_, _) {},
          ),
        ),
      ),
    );

    expect(
      tester.widget<WinAmountCounter>(find.byType(WinAmountCounter)).duration,
      GamePresentationTimings.tumbleLineLiveCount,
    );
  });
}
