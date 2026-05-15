import '../models/pool_state.dart';

abstract class PoolRepository {
  Future<PoolState> load(String uid);

  Future<void> save(String uid, PoolState state);
}
