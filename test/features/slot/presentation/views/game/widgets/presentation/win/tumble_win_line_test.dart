import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/ui_controllers/win_presentation_controller.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/win/tumble_win_line.dart';

void main() {
  testWidgets('pulses the complete TUMBLE WIN line during the post-win hold', (
    tester,
  ) async {
    final controller = WinPresentationController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TumbleWinLine(
            isFlyingTumble: false,
            isPostWinPulsing: true,
            isBusy: false,
            liveTumbleWin: 50,
            lastWin: 50,
            result: null,
            controller: controller,
            anchorKey: null,
            labelStyle: const TextStyle(fontSize: 18),
            valueStyle: const TextStyle(fontSize: 18),
            vibrationEnabled: false,
          ),
        ),
      ),
    );

    final pulse = tester.widget<ScaleTransition>(
      find.descendant(
        of: find.byType(TumbleWinPulse),
        matching: find.byType(ScaleTransition),
      ),
    );
    expect(find.text('TUMBLE WIN'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 225));
    expect(pulse.scale.value, closeTo(1.12, 0.001));

    await tester.pump(const Duration(milliseconds: 275));
    expect(pulse.scale.value, closeTo(1, 0.001));
  });
}
