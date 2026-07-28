import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/update/app_update_monitor.dart';
import 'package:winner_spin/core/update/required_version_source.dart';

void main() {
  test('blocks when Firestore demands a newer version', () async {
    final monitor = _monitor(installed: '1.0.0', required: '1.1.0');

    await monitor.refresh();

    expect(monitor.status, AppUpdateStatus.updateRequired);
    expect(monitor.requiredVersion, '1.1.0');
    monitor.dispose();
  });

  test('allows a build that exactly meets the minimum', () async {
    final monitor = _monitor(installed: '1.1.0', required: '1.1.0');

    await monitor.refresh();

    expect(monitor.status, AppUpdateStatus.upToDate);
    monitor.dispose();
  });

  test('allows a build newer than the minimum', () async {
    final monitor = _monitor(installed: '1.2.0', required: '1.1.0');

    await monitor.refresh();

    expect(monitor.status, AppUpdateStatus.upToDate);
    monitor.dispose();
  });

  test('compares numerically, so 1.10.0 satisfies a 1.9.0 minimum', () async {
    final monitor = _monitor(installed: '1.10.0', required: '1.9.0');

    await monitor.refresh();

    expect(monitor.status, AppUpdateStatus.upToDate);
    monitor.dispose();
  });

  group('fails open — a failed check must never lock the player out', () {
    test('when the config document is missing', () async {
      final monitor = _monitor(installed: '1.0.0', required: null);

      await monitor.refresh();

      expect(monitor.status, AppUpdateStatus.upToDate);
      monitor.dispose();
    });

    test('when the read throws, e.g. the device is offline', () async {
      final monitor = StoreAppUpdateMonitor(
        source: _ThrowingSource(),
        installedVersion: () async => '1.0.0',
      );

      await monitor.refresh();

      expect(monitor.status, AppUpdateStatus.upToDate);
      monitor.dispose();
    });

    test('when the configured value is not a version', () async {
      final monitor = _monitor(installed: '1.0.0', required: 'not-a-version');

      await monitor.refresh();

      expect(monitor.status, AppUpdateStatus.upToDate);
      monitor.dispose();
    });

    test('when the installed version cannot be read', () async {
      final monitor = StoreAppUpdateMonitor(
        source: _FakeSource(const RequiredVersion(version: '9.9.9')),
        installedVersion: () async => null,
      );

      await monitor.refresh();

      expect(monitor.status, AppUpdateStatus.upToDate);
      monitor.dispose();
    });
  });

  test('performs one read per refresh, so once per app entry', () async {
    final source = _FakeSource(const RequiredVersion(version: '1.0.0'));
    final monitor = StoreAppUpdateMonitor(
      source: source,
      installedVersion: () async => '1.0.0',
    );

    await monitor.refresh();
    expect(source.calls, 1);

    // A later entry (resume) checks again — the value may have changed.
    await monitor.refresh();
    expect(source.calls, 2);
    monitor.dispose();
  });

  test('de-duplicates overlapping refreshes into a single read', () async {
    final source = _FakeSource(const RequiredVersion(version: '1.0.0'));
    final monitor = StoreAppUpdateMonitor(
      source: source,
      installedVersion: () async => '1.0.0',
    );

    await Future.wait([monitor.refresh(), monitor.refresh()]);

    expect(source.calls, 1);
    monitor.dispose();
  });

  test('re-checking clears the block once the player has updated', () async {
    var installed = '1.0.0';
    final source = _FakeSource(const RequiredVersion(version: '2.0.0'));
    final monitor = StoreAppUpdateMonitor(
      source: source,
      installedVersion: () async => installed,
    );

    await monitor.refresh();
    expect(monitor.status, AppUpdateStatus.updateRequired);

    installed = '2.0.0';
    await monitor.refresh();

    expect(monitor.status, AppUpdateStatus.upToDate);
    monitor.dispose();
  });

  test('prefers the configured store url and falls back when absent', () async {
    final withUrl = _monitor(
      installed: '1.0.0',
      required: '1.1.0',
      storeUrl: 'https://apps.apple.com/tr/app/winner-spin/id6795310235',
    );
    await withUrl.refresh();
    expect(withUrl.storeUrl, contains('/tr/'));
    withUrl.dispose();

    final withoutUrl = StoreAppUpdateMonitor(
      source: _FakeSource(const RequiredVersion(version: '1.1.0')),
      installedVersion: () async => '1.0.0',
      fallbackStoreUrl: 'https://apps.apple.com/app/id6795310235',
    );
    await withoutUrl.refresh();
    expect(withoutUrl.storeUrl, 'https://apps.apple.com/app/id6795310235');
    withoutUrl.dispose();
  });
}

StoreAppUpdateMonitor _monitor({
  required String installed,
  required String? required,
  String? storeUrl,
}) {
  return StoreAppUpdateMonitor(
    source: _FakeSource(
      required == null
          ? null
          : RequiredVersion(version: required, storeUrl: storeUrl),
    ),
    installedVersion: () async => installed,
  );
}

class _FakeSource implements RequiredVersionSource {
  _FakeSource(this.required);

  RequiredVersion? required;
  int calls = 0;

  @override
  Future<RequiredVersion?> fetchRequiredVersion() async {
    calls++;
    return required;
  }
}

class _ThrowingSource implements RequiredVersionSource {
  @override
  Future<RequiredVersion?> fetchRequiredVersion() async =>
      throw Exception('offline');
}
