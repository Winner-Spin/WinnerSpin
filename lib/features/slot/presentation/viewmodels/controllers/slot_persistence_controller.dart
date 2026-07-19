import 'package:flutter/foundation.dart';

import '../../../../auth/data/repositories/firebase_auth_repository.dart';
import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../data/repositories/firestore_pool_repository.dart';
import '../../../domain/models/pool_state.dart';
import '../../../domain/repositories/pool_repository.dart';

class SlotPersistenceController {
  SlotPersistenceController({
    required AuthRepository authRepository,
    required PoolRepository poolRepository,
  }) : _authRepository = authRepository,
       _poolRepository = poolRepository;

  factory SlotPersistenceController.withDefaults({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
  }) {
    return SlotPersistenceController(
      authRepository: authRepository ?? FirebaseAuthRepository(),
      poolRepository: poolRepository ?? FirestorePoolRepository(),
    );
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;

  String? get currentUserId => _authRepository.currentUserId;

  Future<Map<String, dynamic>?> getUserData(String userId) {
    return _authRepository.getUserData(userId);
  }

  Stream<Map<String, dynamic>?> watchUserData(String userId) {
    return _authRepository.watchUserData(userId);
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
    _poolRepository.save(userId, pool);
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
      _poolRepository.save(userId, pool),
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

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
