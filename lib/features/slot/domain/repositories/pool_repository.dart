import '../models/pool_state.dart';

/// Abstract pool persistence contract. ViewModels depend on this; the
/// concrete impl (Firestore, future test mocks) implements it.
abstract class PoolRepository {
  /// Loads the user's pool state. Returns a fresh [PoolState] when none
  /// exists yet (first login) or on transient backend failures.
  Future<PoolState> load(String uid);

  /// Persists the pool state. The implementation merges with the user
  /// document so other fields (balance, FS counter) are untouched.
  Future<void> save(String uid, PoolState state);
}
