import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/network/internet_connection_monitor.dart';

void main() {
  test('reports connection changes and recovers automatically', () async {
    final source = _FakeInternetConnectionStatusSource();
    final monitor = AppInternetConnectionMonitor(source: source);

    expect(monitor.status, InternetConnectionStatus.checking);
    await monitor.start();

    source.emit(false);
    await Future<void>.delayed(Duration.zero);
    expect(monitor.status, InternetConnectionStatus.disconnected);

    source.emit(true);
    await Future<void>.delayed(Duration.zero);
    expect(monitor.status, InternetConnectionStatus.connected);

    monitor.dispose();
  });

  test('refresh verifies real internet access', () async {
    final source = _FakeInternetConnectionStatusSource()
      ..hasInternetAccessResult = false;
    final monitor = AppInternetConnectionMonitor(source: source);

    await monitor.refresh();
    expect(monitor.status, InternetConnectionStatus.disconnected);

    source.hasInternetAccessResult = true;
    await monitor.refresh();
    expect(monitor.status, InternetConnectionStatus.connected);

    monitor.dispose();
  });

  test('pause stops reacting to connection events', () async {
    final source = _FakeInternetConnectionStatusSource();
    final monitor = AppInternetConnectionMonitor(source: source);
    await monitor.start();

    source.emit(true);
    await Future<void>.delayed(Duration.zero);
    await monitor.pause();
    source.emit(false);
    await Future<void>.delayed(Duration.zero);

    expect(monitor.status, InternetConnectionStatus.connected);
    monitor.dispose();
  });
}

class _FakeInternetConnectionStatusSource
    implements InternetConnectionStatusSource {
  final _controller = StreamController<bool>.broadcast();
  bool hasInternetAccessResult = true;

  @override
  Future<bool> get hasInternetAccess async => hasInternetAccessResult;

  @override
  Stream<bool> get statusChanges => _controller.stream;

  void emit(bool value) => _controller.add(value);

  @override
  Future<void> dispose() => _controller.close();
}
