import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/engine/spin_task.dart';
import 'package:winner_spin/features/slot/domain/models/game_history_entry.dart';
import 'package:winner_spin/features/slot/domain/models/pending_spin_recovery.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/models/spin_result.dart';
import 'package:winner_spin/features/slot/domain/repositories/game_history_repository.dart';
import 'package:winner_spin/features/slot/domain/repositories/pool_repository.dart';
import 'package:winner_spin/features/slot/domain/repositories/spin_recovery_repository.dart';
import 'package:winner_spin/features/slot/presentation/audio/game_music_service.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/spin_execution_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/game_viewmodel.dart';

void main() {
  test(
    'stale remote balance cannot overwrite an active protected spin',
    () async {
      final authRepository = _MemoryAuthRepository();
      final recoveryRepository = _MemorySpinRecoveryRepository();
      final viewModel = _viewModel(
        authRepository: authRepository,
        recoveryRepository: recoveryRepository,
        result: _result(totalWin: 50),
      );
      await viewModel.fetchUserData();
      viewModel.setVibration(false);

      await viewModel.spin();
      expect(viewModel.userBalance, 900);

      authRepository.emitBalance(1000);
      await _flushAsyncWork();
      expect(viewModel.userBalance, 900);

      await viewModel.onSpinComplete();
      expect(viewModel.userBalance, 950);
      await _flushAsyncWork();
      expect(recoveryRepository.recovery, isNull);

      viewModel.dispose();
      await authRepository.close();
    },
  );

  test(
    'recovered Free Spin award remains pending until acknowledgement',
    () async {
      final authRepository = _MemoryAuthRepository(initialBalance: 900);
      final recoveryRepository = _MemorySpinRecoveryRepository(
        recovery: _recovery(pendingFreeSpinAward: 10),
      );
      final viewModel = _viewModel(
        authRepository: authRepository,
        recoveryRepository: recoveryRepository,
        result: _result(totalWin: 0),
      );

      await viewModel.fetchUserData();

      expect(viewModel.userBalance, 950);
      expect(viewModel.freeSpinsRemaining, 10);
      expect(recoveryRepository.recovery, isNotNull);
      final pendingAward = viewModel.takeRecoveredFreeSpinAward();
      expect(pendingAward?.value, 10);
      expect(pendingAward?.isRetrigger, isFalse);
      expect(viewModel.takeRecoveredFreeSpinAward(), isNull);

      viewModel.acknowledgePendingFreeSpinAward();
      await _flushAsyncWork();
      expect(recoveryRepository.recovery, isNull);

      viewModel.dispose();
      await authRepository.close();
    },
  );

  test('pool failure keeps the cold recovery journal intact', () async {
    final authRepository = _MemoryAuthRepository(initialBalance: 900);
    final recoveryRepository = _MemorySpinRecoveryRepository(
      recovery: _recovery(),
    );
    final viewModel = _viewModel(
      authRepository: authRepository,
      recoveryRepository: recoveryRepository,
      poolRepository: _MemoryPoolRepository(failSave: true),
      result: _result(totalWin: 0),
    );

    await viewModel.fetchUserData();

    expect(viewModel.username, 'Error');
    expect(viewModel.userBalance, 900);
    expect(recoveryRepository.recovery, isNotNull);

    viewModel.dispose();
    await authRepository.close();
  });

  test('slow recovery persistence does not block spin completion', () async {
    final authRepository = _MemoryAuthRepository();
    final recoveryRepository = _MemorySpinRecoveryRepository();
    final viewModel = _viewModel(
      authRepository: authRepository,
      recoveryRepository: recoveryRepository,
      result: _result(totalWin: 50),
    );
    await viewModel.fetchUserData();
    viewModel.setVibration(false);
    await viewModel.spin();
    authRepository.blockSaves();

    var completionReturned = false;
    final completion = viewModel.onSpinComplete().then(
      (_) => completionReturned = true,
    );
    await completion;

    expect(completionReturned, isTrue);
    expect(viewModel.userBalance, 950);
    expect(recoveryRepository.recovery, isNotNull);

    authRepository.releaseSaves();
    await _flushAsyncWork();
    expect(recoveryRepository.recovery, isNull);

    viewModel.dispose();
    await authRepository.close();
  });

  test('Buy Feature trigger does not create a recovery journal', () async {
    final authRepository = _MemoryAuthRepository(initialBalance: 20000);
    final recoveryRepository = _MemorySpinRecoveryRepository();
    final viewModel = _viewModel(
      authRepository: authRepository,
      recoveryRepository: recoveryRepository,
      result: _result(totalWin: 0, freeSpinsTriggered: true),
    );
    await viewModel.fetchUserData();
    viewModel.setVibration(false);

    await viewModel.buyFreeSpins();

    expect(recoveryRepository.recovery, isNull);
    await viewModel.onSpinComplete();

    viewModel.dispose();
    await authRepository.close();
  });
}

GameViewModel _viewModel({
  required _MemoryAuthRepository authRepository,
  required _MemorySpinRecoveryRepository recoveryRepository,
  required SpinResult result,
  PoolRepository? poolRepository,
}) {
  return GameViewModel(
    authRepository: authRepository,
    poolRepository: poolRepository ?? _MemoryPoolRepository(),
    gameHistoryRepository: _MemoryHistoryRepository(),
    spinRecoveryRepository: recoveryRepository,
    musicService: _SilentGameMusicService(),
    spinExecutionController: _FixedSpinExecutionController(result),
  );
}

PendingSpinRecovery _recovery({int pendingFreeSpinAward = 0}) {
  return PendingSpinRecovery(
    spinId: 'user-1-spin-1',
    playedAt: DateTime.utc(2026, 7, 23),
    isFreeSpin: false,
    historyBet: 100,
    winAmount: 50,
    userBalance: 950,
    freeSpinsRemaining: pendingFreeSpinAward == 0 ? 0 : 10,
    freeSpinAccumulatedWin: pendingFreeSpinAward == 0 ? 0 : 50,
    freeSpinsAwardedThisRound: pendingFreeSpinAward == 0 ? 0 : 10,
    pendingFreeSpinAward: pendingFreeSpinAward,
    roundFromAnte: false,
    roundFromBuy: false,
    poolTotalBetsPlaced: 100,
    poolTotalPaidOut: 50,
    poolTotalSpins: 1,
  );
}

SpinResult _result({
  required double totalWin,
  bool freeSpinsTriggered = false,
}) {
  return SpinResult(
    initialGrid: List.generate(
      SlotEngine.columns,
      (_) => List.filled(SlotEngine.rows, 'H1'),
    ),
    tumbles: const [],
    totalWin: totalWin,
    tumbleCount: 0,
    freeSpinsTriggered: freeSpinsTriggered,
    scatterCount: 0,
    scatterPayout: 0,
  );
}

Future<void> _flushAsyncWork() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _MemoryAuthRepository implements AuthRepository {
  _MemoryAuthRepository({double initialBalance = 1000})
    : _data = {
        'username': 'Player',
        'email': 'player@example.com',
        'userBalance': initialBalance,
        'lastWin': 0.0,
        'freeSpinsRemaining': 0,
        'freeSpinAccumulatedWin': 0.0,
        'freeSpinsAwardedThisRound': 0,
      };

  final Map<String, dynamic> _data;
  final StreamController<Map<String, dynamic>?> _userData =
      StreamController<Map<String, dynamic>?>.broadcast();
  Completer<void>? _saveGate;

  @override
  String? get currentUserId => 'user-1';

  @override
  String? get currentUserEmail => 'player@example.com';

  @override
  bool get currentUserEmailVerified => true;

  void emitBalance(double value) {
    _userData.add({'userBalance': value});
  }

  Future<void> close() => _userData.close();

  void blockSaves() {
    _saveGate = Completer<void>();
  }

  void releaseSaves() {
    final gate = _saveGate;
    _saveGate = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async => Map.of(_data);

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) => _userData.stream;

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) async {
    final gate = _saveGate;
    if (gate != null) await gate.future;
    if (userBalance != null) _data['userBalance'] = userBalance;
    if (lastWin != null) _data['lastWin'] = lastWin;
    if (freeSpinsRemaining != null) {
      _data['freeSpinsRemaining'] = freeSpinsRemaining;
    }
    if (freeSpinAccumulatedWin != null) {
      _data['freeSpinAccumulatedWin'] = freeSpinAccumulatedWin;
    }
    if (freeSpinsAwardedThisRound != null) {
      _data['freeSpinsAwardedThisRound'] = freeSpinsAwardedThisRound;
    }
    if (userBalance != null) emitBalance(userBalance);
  }

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) async {}

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {}

  @override
  Future<void> reloadCurrentUser() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteAccount() async {}

  @override
  Future<void> sendEmailVerificationLink() async {}

  @override
  Future<String?> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) => throw UnimplementedError();
}

class _MemoryPoolRepository implements PoolRepository {
  _MemoryPoolRepository({this.failSave = false});

  final bool failSave;
  PoolState state = PoolState();

  @override
  Future<PoolState> load(String uid) async => PoolState.fromMap(state.toMap());

  @override
  Future<void> save(String uid, PoolState state) async {
    if (failSave) throw StateError('pool unavailable');
    this.state = PoolState.fromMap(state.toMap());
  }
}

class _MemoryHistoryRepository implements GameHistoryRepository {
  List<GameHistoryEntry> entries = [];

  @override
  Future<List<GameHistoryEntry>> load(String userId) async => List.of(entries);

  @override
  Future<void> save(String userId, List<GameHistoryEntry> entries) async {
    this.entries = List.of(entries);
  }
}

class _MemorySpinRecoveryRepository implements SpinRecoveryRepository {
  _MemorySpinRecoveryRepository({this.recovery});

  PendingSpinRecovery? recovery;

  @override
  Future<PendingSpinRecovery?> load(String userId) async => recovery;

  @override
  Future<void> save(String userId, PendingSpinRecovery recovery) async {
    this.recovery = recovery;
  }

  @override
  Future<void> clear(String userId, String spinId) async {
    if (recovery?.spinId == spinId) recovery = null;
  }
}

class _FixedSpinExecutionController extends SpinExecutionController {
  _FixedSpinExecutionController(this.result);

  final SpinResult result;

  @override
  Future<SpinTaskOutput> run({
    required PoolState pool,
    required double betAmount,
    required bool isFreeSpins,
    required bool anteBet,
    required bool buyFs,
    bool forceFsTrigger = false,
  }) async {
    return SpinTaskOutput(result: result, pool: pool);
  }
}

class _SilentGameMusicService extends GameMusicService {
  @override
  Future<void> initialize({required bool playWhenReady}) async {}

  @override
  Future<void> dispose() async {}
}
