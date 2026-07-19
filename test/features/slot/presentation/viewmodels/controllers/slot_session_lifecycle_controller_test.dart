import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/repositories/pool_repository.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_persistence_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_session_lifecycle_controller.dart';

void main() {
  test('persists and restores the active free-spin round total', () async {
    final authRepository = _MemoryAuthRepository();
    final persistenceController = SlotPersistenceController(
      authRepository: authRepository,
      poolRepository: _MemoryPoolRepository(),
    );
    final balanceController = BalanceController();
    balanceController.awardWin(81.25);
    final originalRound = FreeSpinsController()
      ..awardInitial(initialWin: 25.50)
      ..recordRoundWin(74.25)
      ..awardRetrigger();

    await SlotSessionLifecycleController().savePlayerState(
      persistenceController: persistenceController,
      balanceController: balanceController,
      freeSpinsController: originalRound,
    );

    final restoredRound = FreeSpinsController()
      ..hydrate((await authRepository.getUserData('user-1'))!);
    final restoredBalance = BalanceController()
      ..hydrate((await authRepository.getUserData('user-1'))!);

    expect(restoredRound.remaining, 15);
    expect(restoredRound.accumulatedWin, 99.75);
    expect(restoredRound.awardedThisRound, 15);
    expect(restoredBalance.lastWin, 81.25);

    originalRound.dispose();
    restoredRound.dispose();
    restoredBalance.dispose();
    balanceController.dispose();
  });

  test('starts the player-state write without waiting for the pool', () async {
    final authRepository = _MemoryAuthRepository();
    final poolRepository = _BlockingPoolRepository();
    final persistenceController = SlotPersistenceController(
      authRepository: authRepository,
      poolRepository: poolRepository,
    );

    final save = persistenceController.forceSavePool(
      userId: 'user-1',
      pool: PoolState(),
      userBalance: 10050,
      lastWin: 50,
      freeSpinsRemaining: 0,
      freeSpinAccumulatedWin: 0,
      freeSpinsAwardedThisRound: 0,
    );
    await Future<void>.delayed(Duration.zero);

    expect((await authRepository.getUserData('user-1'))!['lastWin'], 50);

    poolRepository.completeSave();
    await save;
  });
}

class _MemoryAuthRepository implements AuthRepository {
  final Map<String, dynamic> _userData = {};

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<Map<String, dynamic>?> getUserData(String uid) async => _userData;

  @override
  Future<void> savePlayerState(
    String uid, {
    double? userBalance,
    double? lastWin,
    int? freeSpinsRemaining,
    double? freeSpinAccumulatedWin,
    int? freeSpinsAwardedThisRound,
  }) async {
    if (userBalance != null) _userData['userBalance'] = userBalance;
    if (lastWin != null) _userData['lastWin'] = lastWin;
    if (freeSpinsRemaining != null) {
      _userData['freeSpinsRemaining'] = freeSpinsRemaining;
    }
    if (freeSpinAccumulatedWin != null) {
      _userData['freeSpinAccumulatedWin'] = freeSpinAccumulatedWin;
    }
    if (freeSpinsAwardedThisRound != null) {
      _userData['freeSpinsAwardedThisRound'] = freeSpinsAwardedThisRound;
    }
  }

  @override
  Future<String?> signIn({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<void> signOut() => throw UnimplementedError();

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) => throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      Stream.value(_userData);
}

class _MemoryPoolRepository implements PoolRepository {
  @override
  Future<PoolState> load(String uid) async => PoolState();

  @override
  Future<void> save(String uid, PoolState state) async {}
}

class _BlockingPoolRepository implements PoolRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PoolState> load(String uid) async => PoolState();

  @override
  Future<void> save(String uid, PoolState state) => _saveCompleter.future;

  void completeSave() => _saveCompleter.complete();
}
