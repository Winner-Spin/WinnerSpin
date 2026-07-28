import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/app/app.dart';
import 'package:winner_spin/core/audio/ambient_music_service.dart';

import '../features/auth/support/fake_auth_repository.dart';
import '../core/network/support/fake_internet_connection_monitor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owns ambient music lifecycle once at the application root', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final lifecycle = _RecordingAmbientMusicLifecycle();
    final repository = FakeAuthRepository()..currentUserId = null;
    final internetMonitor = FakeInternetConnectionMonitor();

    await tester.pumpWidget(
      WinnerSpinApp(
        authRepository: repository,
        ambientMusicLifecycle: lifecycle,
        internetConnectionMonitor: internetMonitor,
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(lifecycle.pauseCalls, 1);
    expect(lifecycle.resumeCalls, 0);
    expect(internetMonitor.pauseCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(lifecycle.pauseCalls, 1);
    expect(lifecycle.resumeCalls, 1);
    expect(internetMonitor.refreshCalls, 2);

    await tester.pumpWidget(const SizedBox());
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();

    expect(lifecycle.pauseCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}

class _RecordingAmbientMusicLifecycle implements AmbientMusicLifecycle {
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  Future<void> pauseForLifecycle() async {
    pauseCalls++;
  }

  @override
  Future<void> resumeAfterLifecycle() async {
    resumeCalls++;
  }
}
