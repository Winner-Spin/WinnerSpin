import 'package:flutter/foundation.dart';

import '../../../../auth/domain/repositories/auth_repository.dart';
import '../../../domain/models/pool_state.dart';
import '../../../domain/repositories/pool_repository.dart';

class SlotPersistenceController {
  SlotPersistenceController({
    required AuthRepository authRepository,
    required PoolRepository poolRepository,
  }) : _authRepository = authRepository,
       _poolRepository = poolRepository;

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

  Future<void> savePlayerState({
    String? userId,
    required double userBalance,
    required int freeSpinsRemaining,
    String debugLabel = 'Player state save',
  }) async {
    if (userId == null) return;
    try {
      await _authRepository.savePlayerState(
        userId,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    } catch (e) {
      debugPrint('$debugLabel error: $e');
    }
  }

  void savePlayerStateSilently({
    String? userId,
    required double userBalance,
    required int freeSpinsRemaining,
  }) {
    if (userId == null) return;
    _authRepository.savePlayerState(
      userId,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  void savePoolIfNeeded({
    String? userId,
    required PoolState pool,
    required double userBalance,
    required int freeSpinsRemaining,
  }) {
    if (userId == null || !pool.shouldSave) return;
    _poolRepository.save(userId, pool);
    savePlayerStateSilently(
      userId: userId,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  Future<void> forceSavePool({
    String? userId,
    required PoolState pool,
    required double userBalance,
    required int freeSpinsRemaining,
  }) async {
    if (userId == null) return;
    await _poolRepository.save(userId, pool);
    await _authRepository.savePlayerState(
      userId,
      userBalance: userBalance,
      freeSpinsRemaining: freeSpinsRemaining,
    );
  }

  Future<void> signOut() {
    return _authRepository.signOut();
  }
}
