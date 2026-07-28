import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/slot/domain/repositories/first_launch_disclaimer_repository.dart';
import 'package:winner_spin/features/slot/presentation/views/game/disclaimer_gate.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/dialogs/first_launch_disclaimer_dialog.dart';

void main() {
  testWidgets('does not build the game until the notice is accepted', (
    tester,
  ) async {
    final local = _MemoryLocalRepository();
    final remote = _MemoryAcceptanceRepository();
    var gameBuilds = 0;

    await tester.pumpWidget(
      _host(
        local: local,
        remote: remote,
        child: Builder(
          builder: (_) {
            gameBuilds++;
            return const Text('GAME');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchDisclaimerDialog), findsOneWidget);
    expect(
      gameBuilds,
      0,
      reason: 'the game must not be mounted behind the notice',
    );

    await tester.tap(find.byKey(const ValueKey('disclaimer-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('disclaimer-okay')));
    await tester.pumpAndSettle();

    expect(find.text('GAME'), findsOneWidget);
    expect(find.byType(FirstLaunchDisclaimerDialog), findsNothing);
  });

  testWidgets('records the acceptance against the account', (tester) async {
    final local = _MemoryLocalRepository();
    final remote = _MemoryAcceptanceRepository();

    await tester.pumpWidget(_host(local: local, remote: remote));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('disclaimer-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('disclaimer-okay')));
    await tester.pumpAndSettle();

    expect(local.seen['user-1'], kDisclaimerVersion);
    expect(remote.accepted['user-1'], kDisclaimerVersion);
    expect(remote.recordedAppVersion, isNotEmpty);
  });

  testWidgets('skips the notice when this device already has it', (
    tester,
  ) async {
    final local = _MemoryLocalRepository()..seen['user-1'] = kDisclaimerVersion;
    final remote = _MemoryAcceptanceRepository();

    await tester.pumpWidget(_host(local: local, remote: remote));
    await tester.pumpAndSettle();

    expect(find.text('GAME'), findsOneWidget);
    expect(
      remote.reads,
      0,
      reason: 'a local answer must not cost a Firestore read',
    );
  });

  testWidgets('skips the notice after a reinstall', (tester) async {
    // Nothing on the device, but the account remembers.
    final local = _MemoryLocalRepository();
    final remote = _MemoryAcceptanceRepository()
      ..accepted['user-1'] = kDisclaimerVersion;

    await tester.pumpWidget(_host(local: local, remote: remote));
    await tester.pumpAndSettle();

    expect(find.text('GAME'), findsOneWidget);
    expect(
      local.seen['user-1'],
      kDisclaimerVersion,
      reason: 'mirrored locally so the next launch needs no read',
    );
  });

  testWidgets('asks a second account on the same device', (tester) async {
    // user-1 accepted here; user-2 is a different person and has not.
    final local = _MemoryLocalRepository()..seen['user-1'] = kDisclaimerVersion;
    final remote = _MemoryAcceptanceRepository()
      ..accepted['user-1'] = kDisclaimerVersion;

    await tester.pumpWidget(
      _host(local: local, remote: remote, userId: 'user-2'),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchDisclaimerDialog), findsOneWidget);
  });

  testWidgets('asks again when the text version is raised', (tester) async {
    final local = _MemoryLocalRepository()
      ..seen['user-1'] = kDisclaimerVersion - 1;
    final remote = _MemoryAcceptanceRepository()
      ..accepted['user-1'] = kDisclaimerVersion - 1;

    await tester.pumpWidget(_host(local: local, remote: remote));
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchDisclaimerDialog), findsOneWidget);
  });

  testWidgets('asks when the records cannot be read', (tester) async {
    // Fail closed: an unreadable record is not an acceptance.
    await tester.pumpWidget(
      _host(local: _FailingLocalRepository(), remote: _FailingRemote()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(FirstLaunchDisclaimerDialog), findsOneWidget);
  });

  testWidgets('lets the player in when the account write fails', (
    tester,
  ) async {
    final local = _MemoryLocalRepository();

    await tester.pumpWidget(_host(local: local, remote: _FailingRemote()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('disclaimer-checkbox')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('disclaimer-okay')));
    await tester.pumpAndSettle();

    // Losing the evidence copy is a problem for us, not a reason to lock the
    // player out of a game they just agreed to play.
    expect(find.text('GAME'), findsOneWidget);
    expect(local.seen['user-1'], kDisclaimerVersion);
  });
}

Widget _host({
  required FirstLaunchDisclaimerRepository local,
  required DisclaimerAcceptanceRepository remote,
  String userId = 'user-1',
  Widget? child,
}) {
  return MaterialApp(
    home: DisclaimerGate(
      authRepository: _StubAuthRepository(userId),
      localRepository: local,
      acceptanceRepository: remote,
      child: child ?? const Text('GAME'),
    ),
  );
}

class _MemoryLocalRepository implements FirstLaunchDisclaimerRepository {
  final Map<String, int> seen = {};

  @override
  Future<bool> hasSeenDisclaimer(String userId) async =>
      (seen[userId] ?? 0) >= kDisclaimerVersion;

  @override
  Future<void> markDisclaimerSeen(String userId) async {
    seen[userId] = kDisclaimerVersion;
  }
}

class _FailingLocalRepository implements FirstLaunchDisclaimerRepository {
  @override
  Future<bool> hasSeenDisclaimer(String userId) async =>
      throw Exception('unreadable');

  @override
  Future<void> markDisclaimerSeen(String userId) async =>
      throw Exception('unwritable');
}

class _MemoryAcceptanceRepository implements DisclaimerAcceptanceRepository {
  final Map<String, int> accepted = {};
  String recordedAppVersion = '';
  int reads = 0;

  @override
  Future<bool> hasAccepted({
    required String userId,
    required int version,
  }) async {
    reads++;
    return (accepted[userId] ?? 0) >= version;
  }

  @override
  Future<void> recordAcceptance({
    required String userId,
    required int version,
    required String appVersion,
  }) async {
    accepted[userId] = version;
    recordedAppVersion = appVersion;
  }

  @override
  Future<void> archiveAcceptance({
    required String userId,
    required String email,
  }) async {}
}

class _FailingRemote implements DisclaimerAcceptanceRepository {
  @override
  Future<bool> hasAccepted({
    required String userId,
    required int version,
  }) async => throw Exception('offline');

  @override
  Future<void> recordAcceptance({
    required String userId,
    required int version,
    required String appVersion,
  }) async => throw Exception('offline');

  @override
  Future<void> archiveAcceptance({
    required String userId,
    required String email,
  }) async => throw Exception('offline');
}

class _StubAuthRepository implements AuthRepository {
  _StubAuthRepository(this.currentUserId);

  @override
  final String? currentUserId;

  // The gate only reads the id; anything else would be a bug, so let it throw.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
