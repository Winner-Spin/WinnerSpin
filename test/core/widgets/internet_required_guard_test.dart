import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/network/internet_connection_monitor.dart';
import 'package:winner_spin/core/widgets/internet_required_guard.dart';

import '../network/support/fake_internet_connection_monitor.dart';

void main() {
  testWidgets('blocks the app offline and dismisses itself after recovery', (
    tester,
  ) async {
    var taps = 0;
    final monitor = FakeInternetConnectionMonitor(
      initialStatus: InternetConnectionStatus.disconnected,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InternetRequiredGuard(
          monitor: monitor,
          child: Scaffold(
            body: Center(
              child: FilledButton(
                key: const ValueKey('guarded-action'),
                onPressed: () => taps++,
                child: const Text('PLAY'),
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('internet-required-overlay')),
      findsOneWidget,
    );
    expect(find.text('INTERNET CONNECTION REQUIRED'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('guarded-action')),
      warnIfMissed: false,
    );
    expect(taps, 0);

    monitor.setStatus(InternetConnectionStatus.connected);
    await tester.pump();

    expect(
      find.byKey(const ValueKey('internet-required-overlay')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('guarded-action')));
    expect(taps, 1);

    await tester.pumpWidget(const SizedBox());
    monitor.dispose();
  });

  testWidgets('checks silently while blocking startup interaction', (
    tester,
  ) async {
    var taps = 0;
    final monitor = FakeInternetConnectionMonitor(
      initialStatus: InternetConnectionStatus.checking,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: InternetRequiredGuard(
          monitor: monitor,
          child: Scaffold(
            body: FilledButton(
              key: const ValueKey('checking-guarded-action'),
              onPressed: () => taps++,
              child: const Text('PLAY'),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('internet-required-overlay')),
      findsNothing,
    );
    expect(find.text('INTERNET CONNECTION REQUIRED'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('checking-guarded-action')),
      warnIfMissed: false,
    );
    expect(taps, 0);

    await tester.pumpWidget(const SizedBox());
    monitor.dispose();
  });

  testWidgets('offline labels are not painted with the debug underline', (
    tester,
  ) async {
    final monitor = FakeInternetConnectionMonitor(
      initialStatus: InternetConnectionStatus.disconnected,
    );

    // Mounted exactly like the real app does it: from `MaterialApp.builder`,
    // which sits above the Navigator and so above every Scaffold/Material.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => InternetRequiredGuard(
          monitor: monitor,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    expect(
      find.byKey(const ValueKey('internet-required-overlay')),
      findsOneWidget,
    );

    // Without a Material ancestor Flutter falls back to a debug text style that
    // draws a yellow double underline under every label.
    const labels = [
      'INTERNET CONNECTION REQUIRED',
      'WAITING FOR CONNECTION...',
    ];
    for (final label in labels) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text(label),
      );
      final style = paragraph.text.style;
      expect(
        style?.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: '"$label" must not be underlined',
      );
      expect(
        style?.decorationColor,
        isNot(const Color(0xFFFFFF00)),
        reason: '"$label" must not use the debug yellow',
      );
    }

    await tester.pumpWidget(const SizedBox());
    monitor.dispose();
  });
}
