import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../data/repositories/firestore_pool_repository.dart';
import '../../../data/repositories/local_spin_recovery_repository.dart';
import '../../../data/repositories/firestore_disclaimer_acceptance_repository.dart';
import '../../../data/repositories/local_user_data_eraser.dart';
import '../../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../../../domain/models/pending_spin_recovery.dart';
import '../../../domain/models/pool_state.dart';
import '../../../domain/repositories/pool_repository.dart';
import '../../../domain/repositories/spin_recovery_repository.dart';

class SlotPersistenceController {
  SlotPersistenceController({
    required AuthRepository authRepository,
    required PoolRepository poolRepository,
    SpinRecoveryRepository? spinRecoveryRepository,
    LocalUserDataEraser localUserDataEraser = const LocalUserDataEraser(),
    DisclaimerAcceptanceRepository? disclaimerAcceptanceRepository,
  }) : _authRepository = authRepository,
       _poolRepository = poolRepository,
       _spinRecoveryRepository = spinRecoveryRepository,
       _localUserDataEraser = localUserDataEraser,
       _disclaimerAcceptanceRepository = disclaimerAcceptanceRepository;

  factory SlotPersistenceController.withDefaults({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
    SpinRecoveryRepository? spinRecoveryRepository,
    LocalUserDataEraser localUserDataEraser = const LocalUserDataEraser(),
    DisclaimerAcceptanceRepository? disclaimerAcceptanceRepository,
  }) {
    return SlotPersistenceController(
      authRepository: authRepository ?? FirebaseAuthRepository(),
      poolRepository: poolRepository ?? FirestorePoolRepository(),
      spinRecoveryRepository: spinRecoveryRepository,
      localUserDataEraser: localUserDataEraser,
      disclaimerAcceptanceRepository: disclaimerAcceptanceRepository,
    );
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  final LocalUserDataEraser _localUserDataEraser;
  final DisclaimerAcceptanceRepository? _disclaimerAcceptanceRepository;
  SpinRecoveryRepository? _spinRecoveryRepository;

  String? get currentUserId => _authRepository.currentUserId;

  Future<Map<String, dynamic>?> getUserData(String userId) {
    return _authRepository.getUserData(userId);
  }

  Stream<Map<String, dynamic>?> watchUserData(String userId) {
    return _authRepository.watchUserData(userId);
  }

  Future<void> updateProfileAvatar(String avatarId) {
    final userId = currentUserId;
    if (userId == null) return Future.value();
    return _authRepository.updateProfileAvatar(userId, avatarId);
  }

  Future<void> sendPasswordResetEmail(String email) {
    final userId = currentUserId;
    if (userId == null) return Future.value();
    return _authRepository.sendPasswordResetEmail(userId, email);
  }

  Future<PoolState> loadPool(String userId) {
    return _poolRepository.load(userId);
  }

  Future<({Map<String, dynamic>? userData, PoolState pool})> loadUserSession(
    String userId,
  ) async {
    final results = await Future.wait<Object?>([
      getUserData(userId),
      loadPool(userId),
    ]);

    return (
      userData: results[0] as Map<String, dynamic>?,
      pool: results[1] as PoolState,
    );
  }

  Future<PendingSpinRecovery?> loadSpinRecovery() {
    final userId = currentUserId;
    if (userId == null) return Future.value();
    return _recoveryRepository.load(userId);
  }

  Future<void> saveSpinRecovery(PendingSpinRecovery recovery) {
    final userId = currentUserId;
    if (userId == null) return Future.value();
    return _recoveryRepository.save(userId, recovery);
  }

  Future<void> clearSpinRecovery(String spinId, {String? userId}) {
    final recoveryUserId = userId ?? currentUserId;
    if (recoveryUserId == null) return Future.value();
    return _recoveryRepository.clear(recoveryUserId, spinId);
  }

  Future<void> persistSpinRecoveryPlayer({
    required String userId,
    required PendingSpinRecovery recovery,
  }) {
    return _authRepository.savePlayerState(
      userId,
      userBalance: recovery.userBalance,
      lastWin: recovery.winAmount,
      freeSpinsRemaining: recovery.freeSpinsRemaining,
      freeSpinAccumulatedWin: recovery.freeSpinAccumulatedWin,
      freeSpinsAwardedThisRound: recovery.freeSpinsAwardedThisRound,
    );
  }

  Future<void> persistRecoveredSpin({
    required String userId,
    required PendingSpinRecovery recovery,
  }) async {
    await Future.wait([
      persistSpinRecoveryPlayer(userId: userId, recovery: recovery),
      _poolRepository.save(
        userId,
        PoolState(
          totalBetsPlaced: recovery.poolTotalBetsPlaced,
          totalPaidOut: recovery.poolTotalPaidOut,
          totalSpins: recovery.poolTotalSpins,
        ),
      ),
    ]);
  }

  Future<void> savePlayerState({
    String? userId,
    required double userBalance,
    required double lastWin,
    required int freeSpinsRemaining,
    required double freeSpinAccumulatedWin,
    required int freeSpinsAwardedThisRound,
    String debugLabel = 'Player state save',
  }) async {
    if (userId == null) return;
    try {
      await _authRepository.savePlayerState(
        userId,
        userBalance: userBalance,
        lastWin: lastWin,
        freeSpinsRemaining: freeSpinsRemaining,
        freeSpinAccumulatedWin: freeSpinAccumulatedWin,
        freeSpinsAwardedThisRound: freeSpinsAwardedThisRound,
      );
    } catch (e) {
      debugPrint('$debugLabel error: $e');
    }
  }

  void savePlayerStateSilently({
    String? userId,
    required double userBalance,
    required double lastWin,
    required int freeSpinsRemaining,
    required double freeSpinAccumulatedWin,
    required int freeSpinsAwardedThisRound,
  }) {
    if (userId == null) return;
    _authRepository.savePlayerState(
      userId,
      userBalance: userBalance,
      lastWin: lastWin,
      freeSpinsRemaining: freeSpinsRemaining,
      freeSpinAccumulatedWin: freeSpinAccumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsAwardedThisRound,
    );
  }

  void savePoolIfNeeded({
    String? userId,
    required PoolState pool,
    required double userBalance,
    required double lastWin,
    required int freeSpinsRemaining,
    required double freeSpinAccumulatedWin,
    required int freeSpinsAwardedThisRound,
  }) {
    if (userId == null || !pool.shouldSave) return;
    unawaited(_savePoolSilently(userId, pool));
    savePlayerStateSilently(
      userId: userId,
      userBalance: userBalance,
      lastWin: lastWin,
      freeSpinsRemaining: freeSpinsRemaining,
      freeSpinAccumulatedWin: freeSpinAccumulatedWin,
      freeSpinsAwardedThisRound: freeSpinsAwardedThisRound,
    );
  }

  Future<void> forceSavePool({
    String? userId,
    required PoolState pool,
    required double userBalance,
    required double lastWin,
    required int freeSpinsRemaining,
    required double freeSpinAccumulatedWin,
    required int freeSpinsAwardedThisRound,
  }) async {
    if (userId == null) return;
    await Future.wait([
      _savePoolSilently(userId, pool),
      _authRepository.savePlayerState(
        userId,
        userBalance: userBalance,
        lastWin: lastWin,
        freeSpinsRemaining: freeSpinsRemaining,
        freeSpinAccumulatedWin: freeSpinAccumulatedWin,
        freeSpinsAwardedThisRound: freeSpinsAwardedThisRound,
      ),
    ]);
  }

  SpinRecoveryRepository get _recoveryRepository {
    return _spinRecoveryRepository ??= LocalSpinRecoveryRepository();
  }

  Future<void> _savePoolSilently(String userId, PoolState pool) async {
    try {
      await _poolRepository.save(userId, pool);
    } catch (error) {
      debugPrint('Pool save error: $error');
    }
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }

  Future<bool> refreshCurrentSession() async {
    if (currentUserId == null) return false;
    try {
      await _authRepository.reloadCurrentUser();
    } catch (_) {
      // A temporary network failure must not sign an otherwise valid user out.
      return currentUserId != null;
    }
    return currentUserId != null;
  }

  Future<void> deleteAccount(String password) async {
    // Read before the account goes: afterwards there is no uid to name the
    // files with.
    final userId = currentUserId;
    final email = _authRepository.currentUserEmail;

    await _authRepository.deleteAccount(
      password,
      onReauthenticated: userId == null || email == null
          ? null
          : () => _archiveDisclaimerAcceptance(userId, email),
    );
    // Only once the account is really gone. Wiping the device first would lose
    // the player's history to a mistyped password.
    if (userId != null) await _localUserDataEraser.eraseFor(userId);
  }

  /// Best effort. Failing to keep the evidence is a problem for us; refusing
  /// to delete the account over it would be a problem for the player, who has
  /// already asked and already proven who they are.
  Future<void> _archiveDisclaimerAcceptance(String userId, String email) async {
    final repository =
        _disclaimerAcceptanceRepository ??
        FirestoreDisclaimerAcceptanceRepository();
    try {
      await repository.archiveAcceptance(userId: userId, email: email);
    } catch (error) {
      debugPrint('Disclaimer acceptance could not be archived: $error');
    }
  }
}
