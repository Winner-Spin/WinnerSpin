import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/audio/ui_click_sound.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/controls/minus_button.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/controls/plus_button.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/controls/respin_button.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/controls/spin_controls_row.dart';

void main() {
  setUp(() => UiClickSound.enabled = false);
  tearDown(() => UiClickSound.enabled = true);

  testWidgets('free spins hide bet controls and disable the spin button', (
    tester,
  ) async {
    var spinCalls = 0;
    var stopCalls = 0;

    await tester.pumpWidget(
      _testApp(
        isInFreeSpins: true,
        freeSpinsRemaining: 10,
        onSpin: () => spinCalls++,
        onStopAutoSpin: () => stopCalls++,
      ),
    );

    expect(find.byType(MinusButton), findsNothing);
    expect(find.byType(PlusButton), findsNothing);
    expect(find.byType(RespinButton), findsOneWidget);
    expect(find.text('10'), findsOneWidget);

    final button = tester.widget<RespinButton>(find.byType(RespinButton));
    expect(button.disabled, isTrue);
    expect(button.dimWhenDisabled, isFalse);
    expect(button.onTap, isNull);
    expect(button.autoSpinsRemaining, 10);
    final opacity = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(RespinButton),
        matching: find.byType(Opacity),
      ),
    );
    expect(opacity.opacity, 1.0);
    expect(spinCalls, 0);
    expect(stopCalls, 0);
  });

  testWidgets('free-spin count takes priority over a paid autoplay count', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        autoSpinActive: true,
        autoSpinsRemaining: 37,
        isInFreeSpins: true,
        freeSpinsRemaining: 8,
      ),
    );

    expect(find.text('8'), findsOneWidget);
    expect(find.text('37'), findsNothing);
    expect(find.byType(MinusButton), findsNothing);
    expect(find.byType(PlusButton), findsNothing);

    final button = tester.widget<RespinButton>(find.byType(RespinButton));
    expect(button.disabled, isTrue);
    expect(button.onTap, isNull);
    expect(button.autoSpinsRemaining, 8);
  });

  testWidgets('normal manual spin controls keep their existing behavior', (
    tester,
  ) async {
    var spinCalls = 0;

    await tester.pumpWidget(
      _testApp(onSpin: () => spinCalls++),
    );

    expect(find.byType(MinusButton), findsOneWidget);
    expect(find.byType(PlusButton), findsOneWidget);

    final button = tester.widget<RespinButton>(find.byType(RespinButton));
    expect(button.disabled, isFalse);
    expect(button.dimWhenDisabled, isTrue);
    expect(button.autoSpinsRemaining, isNull);

    await tester.tap(find.byType(RespinButton));
    expect(spinCalls, 1);
  });

  testWidgets('normal autoplay still shows its count and remains stoppable', (
    tester,
  ) async {
    var stopCalls = 0;

    await tester.pumpWidget(
      _testApp(
        autoSpinActive: true,
        autoSpinsRemaining: 24,
        onStopAutoSpin: () => stopCalls++,
      ),
    );

    expect(find.byType(MinusButton), findsNothing);
    expect(find.byType(PlusButton), findsNothing);
    expect(find.text('24'), findsOneWidget);

    final button = tester.widget<RespinButton>(find.byType(RespinButton));
    expect(button.disabled, isFalse);
    expect(button.autoSpinsRemaining, 24);

    await tester.tap(find.byType(RespinButton));
    expect(stopCalls, 1);
  });
}

Widget _testApp({
  bool autoSpinActive = false,
  bool isInFreeSpins = false,
  int? autoSpinsRemaining,
  int freeSpinsRemaining = 0,
  VoidCallback? onSpin,
  VoidCallback? onStopAutoSpin,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SpinControlsRow(
          autoSpinActive: autoSpinActive,
          bigWinShowing: false,
          spinning: false,
          canDecreaseBet: true,
          canIncreaseBet: true,
          isInFreeSpins: isInFreeSpins,
          autoSpinsRemaining: autoSpinsRemaining,
          freeSpinsRemaining: freeSpinsRemaining,
          onDecreaseBet: () {},
          onIncreaseBet: () {},
          onSpin: onSpin ?? () {},
          onStopAutoSpin: onStopAutoSpin ?? () {},
        ),
      ),
    ),
  );
}
