import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_update_monitor.dart';
import 'package:winner_spin/core/widgets/update_required_guard.dart';

void main() {
  testWidgets('blocks the app and offers the store link when outdated', (
    tester,
  ) async {
    var taps = 0;
    final monitor = _FakeUpdateMonitor(
      status: AppUpdateStatus.updateRequired,
      requiredVersion: '1.1.0',
      storeUrl: 'https://apps.apple.com/app/id6795310235',
    );

    await tester.pumpWidget(_host(monitor, onTap: () => taps++));

    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsOneWidget,
    );
    expect(find.text('UPDATE REQUIRED'), findsOneWidget);
    expect(find.text('VERSION 1.1.0'), findsOneWidget);
    expect(find.text('UPDATE NOW'), findsOneWidget);

    // The app behind the prompt must be unreachable.
    await tester.tap(
      find.byKey(const ValueKey('guarded-action')),
      warnIfMissed: false,
    );
    expect(taps, 0);

    monitor.dispose();
  });

  testWidgets('stays hidden while the installed build is current', (
    tester,
  ) async {
    var taps = 0;
    final monitor = _FakeUpdateMonitor(status: AppUpdateStatus.upToDate);

    await tester.pumpWidget(_host(monitor, onTap: () => taps++));

    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('guarded-action')));
    expect(taps, 1);

    monitor.dispose();
  });

  testWidgets('stays hidden while the check is inconclusive', (tester) async {
    final monitor = _FakeUpdateMonitor(status: AppUpdateStatus.unknown);

    await tester.pumpWidget(_host(monitor, onTap: () {}));

    // Unknown must never block: it covers offline and unpublished apps.
    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsNothing,
    );

    monitor.dispose();
  });

  testWidgets('clears itself once the monitor reports an updated build', (
    tester,
  ) async {
    final monitor = _FakeUpdateMonitor(
      status: AppUpdateStatus.updateRequired,
      requiredVersion: '1.1.0',
    );

    await tester.pumpWidget(_host(monitor, onTap: () {}));
    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsOneWidget,
    );

    monitor.setStatus(AppUpdateStatus.upToDate);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('update-required-overlay')),
      findsNothing,
    );
    monitor.dispose();
  });

  testWidgets('labels are not painted with the debug underline', (
    tester,
  ) async {
    final monitor = _FakeUpdateMonitor(
      status: AppUpdateStatus.updateRequired,
      requiredVersion: '1.1.0',
    );

    // Mounted from `MaterialApp.builder` exactly like the real app does it,
    // i.e. above the Navigator and outside any Scaffold.
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => UpdateRequiredGuard(
          monitor: monitor,
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );

    for (final label in ['UPDATE REQUIRED', 'UPDATE NOW']) {
      final style = tester
          .renderObject<RenderParagraph>(find.text(label))
          .text
          .style;
      expect(
        style?.decoration ?? TextDecoration.none,
        TextDecoration.none,
        reason: '"$label" must not be underlined',
      );
    }

    monitor.dispose();
  });
}

Widget _host(AppUpdateMonitor monitor, {required VoidCallback onTap}) {
  return MaterialApp(
    home: UpdateRequiredGuard(
      monitor: monitor,
      child: Scaffold(
        body: Center(
          child: FilledButton(
            key: const ValueKey('guarded-action'),
            onPressed: onTap,
            child: const Text('PLAY'),
          ),
        ),
      ),
    ),
  );
}

class _FakeUpdateMonitor extends AppUpdateMonitor {
  _FakeUpdateMonitor({
    required AppUpdateStatus status,
    this.requiredVersion,
    this.storeUrl,
  }) : _status = status;

  AppUpdateStatus _status;

  @override
  final String? requiredVersion;

  @override
  final String? storeUrl;

  @override
  AppUpdateStatus get status => _status;

  void setStatus(AppUpdateStatus value) {
    _status = value;
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
}
