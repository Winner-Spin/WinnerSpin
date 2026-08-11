import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_build_info.dart';
import 'package:winner_spin/features/slot/presentation/views/settings/widgets/system_settings_footer.dart';

void main() {
  testWidgets('shows the project and developer GitHub links', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 250,
              child: SingleChildScrollView(
                child: SystemSettingsFooter(platform: TargetPlatform.android),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('LEGAL'), findsNothing);
    expect(find.text('PRIVACY POLICY'), findsOneWidget);
    expect(find.text('TERMS OF USE'), findsNothing);
    expect(find.text('ABOUT & SUPPORT'), findsOneWidget);
    expect(find.text('PROJECT & CREDITS'), findsNothing);
    expect(find.text('Winner-Spin/WinnerSpin'), findsNothing);
    expect(find.text('@hakangunesdev'), findsNothing);
    expect(find.text('@eneseken95'), findsNothing);
    expect(find.text('AND'), findsNothing);
    expect(find.text('&'), findsOneWidget);
    expect(find.text('WINNER SPIN SOURCE CODE'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
    // Every chip carries an icon that names its destination.
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsNothing);
    // The credit chips lead with their bundled, offline GitHub avatars.
    expect(find.byKey(const ValueKey('hakan-github-avatar')), findsOneWidget);
    expect(find.byKey(const ValueKey('enes-github-avatar')), findsOneWidget);
    final hakanAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('hakan-github-avatar')),
        matching: find.byType(Image),
      ),
    );
    final enesAvatar = tester.widget<Image>(
      find.descendant(
        of: find.byKey(const ValueKey('enes-github-avatar')),
        matching: find.byType(Image),
      ),
    );
    expect(
      hakanAvatar.image,
      const AssetImage('assets/avatars/hakangunesdev.jpg'),
    );
    expect(
      enesAvatar.image,
      const AssetImage('assets/avatars/eneseken95.jpg'),
    );
    expect(
      find.byKey(const ValueKey('winner-spin-source-app-icon')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('winner-spin-source-github-icon')),
      findsOneWidget,
    );

    final madeWithY = tester.getCenter(find.textContaining('Made with')).dy;
    final hakanY = tester.getCenter(find.text('HAKAN GÜNEŞ')).dy;
    final enesY = tester.getCenter(find.text('ENES EKEN')).dy;
    final sourceCodeY = tester
        .getCenter(find.text('WINNER SPIN SOURCE CODE'))
        .dy;
    final privacyPolicyY = tester.getCenter(find.text('PRIVACY POLICY')).dy;
    expect(hakanY, closeTo(madeWithY, 1));
    expect(enesY, closeTo(madeWithY, 1));
    expect(sourceCodeY, greaterThan(madeWithY));
    expect(privacyPolicyY, closeTo(sourceCodeY, 1));

    // The support address sits on its own row below the link chips so the
    // existing chips are not squeezed by the extra width.
    final supportFinder = find.text(
      SystemSettingsFooter.supportEmail.toUpperCase(),
    );
    expect(supportFinder, findsOneWidget);
    expect(tester.getCenter(supportFinder).dy, greaterThan(sourceCodeY));
    expect(find.byIcon(Icons.mail_outline_rounded), findsOneWidget);

    // Instagram shares that row: it is a contact channel, not a legal link.
    final instagramFinder = find.text(
      SystemSettingsFooter.instagramHandle.toUpperCase(),
    );
    expect(instagramFinder, findsOneWidget);
    expect(
      find.byKey(const ValueKey('winner-spin-instagram-icon')),
      findsOneWidget,
    );
    expect(
      tester.getCenter(instagramFinder).dy,
      closeTo(tester.getCenter(supportFinder).dy, 1),
    );

    // Version metadata reads last, below the disclaimer.
    final versionFinder = find.byKey(const ValueKey('settings-app-version'));
    expect(versionFinder, findsOneWidget);
    expect(
      tester.widget<Text>(versionFinder).data,
      'VERSION $kAppVersion ($kAppBuildNumber)',
    );
    expect(
      tester.getCenter(versionFinder).dy,
      greaterThan(tester.getCenter(supportFinder).dy),
    );

    // The copyright notice closes the screen, under the version.
    final copyrightFinder = find.byKey(const ValueKey('settings-copyright'));
    expect(copyrightFinder, findsOneWidget);
    expect(
      tester.widget<Text>(copyrightFinder).data,
      '© 2026 Hakan Güneş & Enes Eken. All rights reserved.',
    );
    expect(
      tester.getCenter(copyrightFinder).dy,
      greaterThan(tester.getCenter(versionFinder).dy),
    );

    final hakanStyle = tester.widget<Text>(find.text('HAKAN GÜNEŞ')).style;
    final enesStyle = tester.widget<Text>(find.text('ENES EKEN')).style;
    final sourceStyle = tester
        .widget<Text>(find.text('WINNER SPIN SOURCE CODE'))
        .style;
    expect(hakanStyle?.fontSize, 11);
    expect(enesStyle?.fontSize, 11);
    expect(sourceStyle?.fontSize, 11);

    final madeWithStyle = tester
        .widget<Text>(find.textContaining('Made with'))
        .style;
    final ampersandStyle = tester.widget<Text>(find.text('&')).style;
    expect(madeWithStyle?.fontSize, 12.5);
    expect(ampersandStyle?.fontSize, 12.5);
    expect(madeWithStyle?.fontSize, greaterThan(hakanStyle!.fontSize!));
    expect(ampersandStyle?.fontSize, greaterThan(enesStyle!.fontSize!));
    expect(sourceStyle?.fontSize, hakanStyle.fontSize);
  });

  testWidgets('shows Apple standard terms on Apple devices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSettingsFooter(platform: TargetPlatform.iOS),
          ),
        ),
      ),
    );

    expect(find.text('PRIVACY POLICY'), findsOneWidget);
    expect(find.text('TERMS OF USE'), findsOneWidget);
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    final sourceCodeY = tester
        .getCenter(find.text('WINNER SPIN SOURCE CODE'))
        .dy;
    expect(
      tester.getCenter(find.text('PRIVACY POLICY')).dy,
      closeTo(sourceCodeY, 1),
    );
    expect(
      tester.getCenter(find.text('TERMS OF USE')).dy,
      closeTo(sourceCodeY, 1),
    );
    // Still its own row on Apple devices, where the chip row is busiest.
    expect(
      tester
          .getCenter(find.text(SystemSettingsFooter.supportEmail.toUpperCase()))
          .dy,
      greaterThan(sourceCodeY),
    );
  });

  testWidgets('copies the support address when no mail client opens', (
    tester,
  ) async {
    final messages = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        messages.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SystemSettingsFooter(platform: TargetPlatform.android),
          ),
        ),
      ),
    );

    await tester.tap(
      find.text(SystemSettingsFooter.supportEmail.toUpperCase()),
    );
    await tester.pumpAndSettle();

    // url_launcher has no platform implementation under test, so the tap falls
    // back to the clipboard path instead of leaving the user with nothing.
    final copied = messages.firstWhere(
      (call) => call.method == 'Clipboard.setData',
      orElse: () => const MethodCall('none'),
    );
    expect(copied.method, 'Clipboard.setData');
    expect(
      (copied.arguments as Map)['text'],
      SystemSettingsFooter.supportEmail,
    );
    expect(
      find.textContaining(SystemSettingsFooter.supportEmail),
      findsOneWidget,
    );
  });
}
