import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/pool_state.dart';
import '../../domain/repositories/pool_repository.dart';

/// Firestore implementation of [PoolRepository].
/// Pool state is stored under a `pool` field on the user document.
/// Reads happen once per login; writes happen on the engine's save interval
/// (every 10 spins) plus once on logout/background.
class FirestorePoolRepository implements PoolRepository {
  FirestorePoolRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String _collection = 'users';
  static const String _poolField = 'pool';

  @override
  Future<PoolState> load(String uid) async {
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey(_poolField)) {
          return PoolState.fromMap(
            Map<String, dynamic>.from(data[_poolField]),
          );
        }
      }
    } catch (_) {
      // Silently fall back to fresh state to avoid app crashes.
    }
    return PoolState();
  }

  @override
  Future<void> save(String uid, PoolState state) async {
    try {
      await _db.collection(_collection).doc(uid).set(
        {_poolField: state.toMap()},
        SetOptions(merge: true),
      );
      state.markSaved();
    } catch (_) {
      // Fail silently — will retry on next save interval.
    }
  }
}
