import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_update_monitor.dart';
import 'package:winner_spin/core/widgets/update_required_guard.dart';

/// The guard is mounted from `MaterialApp.builder`, which wraps the Navigator
/// itself. These tests pin down what that buys: the block covers every route
/// and every dialog, not just the first screen.
void main() {
  testWidgets('covers a pushed route, not just the first screen', (
    tester,
  ) async {
    var taps = 0;
    final monitor = _FakeUpdateMonitor(AppUpdateStatus.upToDate);
    await tester.pumpWidget(_app(monitor, onTap: () => taps++));

    // Navigate deeper into the app before the update is discovered.
    await tester.tap(find.text('GO DEEPER'));
    await tester.pumpAndSettle();
    expect(find.text('SECOND PAGE'), findsOneWidget);

    monitor.setStatus(AppUpdateStatus.updateRequired);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsOneWidget,
      reason: 'the block must follow the user onto inner pages',
    );
    await tester.tap(
      find.byKey(const ValueKey('second-page-action')),
      warnIfMissed: false,
    );
    expect(taps, 0, reason: 'the inner page must be unusable');

    monitor.dispose();
  });

  testWidgets('covers dialogs, which the settings screen uses', (tester) async {
    var taps = 0;
    final monitor = _FakeUpdateMonitor(AppUpdateStatus.updateRequired);
    await tester.pumpWidget(_app(monitor, onTap: () => taps++));

    final context = tester.element(find.text('GO DEEPER'));
    unawaited(
      showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'dialog',
        pageBuilder: (context, _, _) => Center(
          child: Material(
            child: TextButton(
              key: const ValueKey('dialog-action'),
              onPressed: () => taps++,
              child: const Text('DIALOG BUTTON'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('DIALOG BUTTON'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsOneWidget,
      reason: 'dialogs live in the same Navigator, so they are covered too',
    );
    await tester.tap(
      find.byKey(const ValueKey('dialog-action')),
      warnIfMissed: false,
    );
    expect(taps, 0, reason: 'dialog buttons must be unusable as well');

    monitor.dispose();
  });

  testWidgets('play stays blocked until the monitor clears', (tester) async {
    var taps = 0;
    final monitor = _FakeUpdateMonitor(AppUpdateStatus.updateRequired);
    await tester.pumpWidget(_app(monitor, onTap: () => taps++));

    await tester.tap(find.text('GO DEEPER'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('SECOND PAGE'), findsNothing, reason: 'cannot navigate');

    monitor.setStatus(AppUpdateStatus.upToDate);
    await tester.pumpAndSettle();

    await tester.tap(find.text('GO DEEPER'));
    await tester.pumpAndSettle();
    expect(find.text('SECOND PAGE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('second-page-action')));
    expect(taps, 1);

    monitor.dispose();
  });
}

/// Mirrors the real wiring in `WinnerSpinApp`: the guard goes in `builder`.
Widget _app(AppUpdateMonitor monitor, {required VoidCallback onTap}) {
  return MaterialApp(
    builder: (context, child) => UpdateRequiredGuard(
      monitor: monitor,
      child: child ?? const SizedBox.shrink(),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('SECOND PAGE'),
                        TextButton(
                          key: const ValueKey('second-page-action'),
                          onPressed: onTap,
                          child: const Text('SPIN'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            child: const Text('GO DEEPER'),
          ),
        ),
      ),
    ),
  );
}

class _FakeUpdateMonitor extends AppUpdateMonitor {
  _FakeUpdateMonitor(this._status);

  AppUpdateStatus _status;

  @override
  AppUpdateStatus get status => _status;

  @override
  String? get requiredVersion => '999.0.0';

  @override
  String? get storeUrl => 'https://apps.apple.com/app/id6795310235';

  void setStatus(AppUpdateStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}
