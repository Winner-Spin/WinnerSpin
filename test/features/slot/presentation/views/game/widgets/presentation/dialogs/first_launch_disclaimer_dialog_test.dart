import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/dialogs/first_launch_disclaimer_dialog.dart';

void main() {
  testWidgets('the accept button does nothing until the box is ticked', (
    tester,
  ) async {
    var confirmations = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchDisclaimerDialog(
          platform: TargetPlatform.iOS,
          onOkay: () => confirmations++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final okay = find.byKey(const ValueKey('disclaimer-okay'));
    final checkbox = find.byKey(const ValueKey('disclaimer-checkbox'));

    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    await tester.tap(okay);
    await tester.pump();
    expect(
      confirmations,
      0,
      reason: 'the notice must not be dismissable without the tick',
    );

    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    expect(tester.widget<Checkbox>(checkbox).value, isTrue);

    await tester.tap(okay);
    await tester.pump();
    expect(confirmations, 1);
  });

  testWidgets('the whole acknowledgement row toggles the box', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchDisclaimerDialog(
          platform: TargetPlatform.iOS,
          onOkay: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final checkbox = find.byKey(const ValueKey('disclaimer-checkbox'));
    final acknowledgement = find.byKey(
      const ValueKey('disclaimer-acknowledgement'),
    );

    // Tapping the label, not the 24pt square.
    await tester.ensureVisible(acknowledgement);
    await tester.tap(acknowledgement);
    await tester.pump();

    expect(tester.widget<Checkbox>(checkbox).value, isTrue);
  });

  testWidgets('states the age and the policies it covers', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchDisclaimerDialog(
          platform: TargetPlatform.iOS,
          onOkay: () {},
        ),
      ),
    );

    final label = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('disclaimer-acknowledgement')),
            matching: find.byType(Text),
          ),
        )
        .textSpan!
        .toPlainText();

    expect(label, contains('read and understood'));
    expect(label, contains('18 or older'));
    expect(label, contains('Privacy Policy'));
    expect(label, contains('Terms of Use'));
  });

  testWidgets('omits the Apple terms link off Apple platforms', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FirstLaunchDisclaimerDialog(
          platform: TargetPlatform.android,
          onOkay: () {},
        ),
      ),
    );

    final label = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('disclaimer-acknowledgement')),
            matching: find.byType(Text),
          ),
        )
        .textSpan!
        .toPlainText();

    // The link points at Apple's standard EULA, which says nothing about an
    // Android build.
    expect(label, contains('Privacy Policy'));
    expect(label, isNot(contains('Terms of Use')));
  });
}
