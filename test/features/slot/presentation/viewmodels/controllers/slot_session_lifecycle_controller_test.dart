import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/auth/domain/repositories/auth_repository.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/repositories/pool_repository.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/balance_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/free_spins_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/player_session_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_persistence_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_pool_controller.dart';
import 'package:winner_spin/features/slot/presentation/viewmodels/controllers/slot_session_lifecycle_controller.dart';

void main() {
  test('persists gameplay state when the app leaves the foreground', () async {
    final authRepository = _MemoryAuthRepository();
    final poolRepository = _MemoryPoolRepository();
    final persistenceController = SlotPersistenceController(
      authRepository: authRepository,
      poolRepository: poolRepository,
    );
    final poolController = SlotPoolController()
      ..recordBet(100)
      ..recordPayout(25);
    final balanceController = BalanceController()..awardWin(40);
    final freeSpinsController = FreeSpinsController()
      ..awardInitial(initialWin: 15);

    await SlotSessionLifecycleController().onAppLifecycleEvent(
      poolController: poolController,
      persistenceController: persistenceController,
      balanceController: balanceController,
      freeSpinsController: freeSpinsController,
    );

    final savedPlayer = (await authRepository.getUserData('user-1'))!;
    expect(poolRepository.saveCalls, 1);
    expect(poolRepository.lastSavedPool?.totalBetsPlaced, 100);
    expect(poolRepository.lastSavedPool?.totalPaidOut, 25);
    expect(savedPlayer['userBalance'], 10040);
    expect(savedPlayer['lastWin'], 40);
    expect(savedPlayer['freeSpinsRemaining'], 10);
    expect(savedPlayer['freeSpinAccumulatedWin'], 15);

    balanceController.dispose();
    freeSpinsController.dispose();
  });

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

  test('forwards profile avatar and password reset operations', () async {
    final authRepository = _MemoryAuthRepository();
    final persistenceController = SlotPersistenceController(
      authRepository: authRepository,
      poolRepository: _MemoryPoolRepository(),
    );

    await persistenceController.updateProfileAvatar('heart');
    await persistenceController.sendPasswordResetEmail('player@example.com');

    expect(
      (await authRepository.getUserData('user-1'))!['profileAvatarId'],
      'heart',
    );
    expect(authRepository.passwordResetEmail, 'player@example.com');
  });

  test(
    'marks the player logged out when the refreshed session expired',
    () async {
      final authRepository = _MemoryAuthRepository()
        ..expireSessionOnReload = true;
      final persistenceController = SlotPersistenceController(
        authRepository: authRepository,
        poolRepository: _MemoryPoolRepository(),
      );
      final sessionController = PlayerSessionController();

      final isSessionActive = await SlotSessionLifecycleController()
          .validateSessionOnResume(
            sessionController: sessionController,
            persistenceController: persistenceController,
          );

      expect(isSessionActive, isFalse);
      expect(sessionController.loggedOut, isTrue);
      sessionController.dispose();
    },
  );

  test(
    'keeps the player signed in during a temporary refresh failure',
    () async {
      final authRepository = _MemoryAuthRepository()
        ..reloadError = Exception('offline');
      final persistenceController = SlotPersistenceController(
        authRepository: authRepository,
        poolRepository: _MemoryPoolRepository(),
      );
      final sessionController = PlayerSessionController();

      final isSessionActive = await SlotSessionLifecycleController()
          .validateSessionOnResume(
            sessionController: sessionController,
            persistenceController: persistenceController,
          );

      expect(isSessionActive, isTrue);
      expect(sessionController.loggedOut, isFalse);
      sessionController.dispose();
    },
  );
}

class _MemoryAuthRepository implements AuthRepository {
  final Map<String, dynamic> _userData = {};
  String? passwordResetEmail;
  String? activeUserId = 'user-1';
  bool expireSessionOnReload = false;
  Object? reloadError;

  @override
  String? get currentUserId => activeUserId;

  @override
  String? get currentUserEmail => 'player@example.com';

  @override
  bool get currentUserEmailVerified => true;

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
  Future<void> deleteAccount() => throw UnimplementedError();

  @override
  Future<void> reloadCurrentUser() async {
    if (reloadError case final error?) throw error;
    if (expireSessionOnReload) activeUserId = null;
  }

  @override
  Future<void> sendEmailVerificationLink() => throw UnimplementedError();

  @override
  Future<String?> signUp({
    required String email,
    required String password,
    required String username,
  }) => throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>?> watchUserData(String uid) =>
      Stream.value(_userData);

  @override
  Future<void> updateProfileAvatar(String uid, String avatarId) async {
    _userData['profileAvatarId'] = avatarId;
  }

  @override
  Future<void> sendPasswordResetEmail(String uid, String email) async {
    passwordResetEmail = email;
  }
}

class _MemoryPoolRepository implements PoolRepository {
  int saveCalls = 0;
  PoolState? lastSavedPool;

  @override
  Future<PoolState> load(String uid) async => PoolState();

  @override
  Future<void> save(String uid, PoolState state) async {
    saveCalls++;
    lastSavedPool = PoolState.fromMap(state.toMap());
  }
}

class _BlockingPoolRepository implements PoolRepository {
  final Completer<void> _saveCompleter = Completer<void>();

  @override
  Future<PoolState> load(String uid) async => PoolState();

  @override
  Future<void> save(String uid, PoolState state) => _saveCompleter.future;

  void completeSave() => _saveCompleter.complete();
}
