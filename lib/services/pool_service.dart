import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/pool_state.dart';

/// Handles Firestore persistence of pool data.
/// Optimized for minimal read/write operations:
///   - Read: once per login
///   - Write: every 10 spins + on logout/background
class PoolService {
  PoolService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _collection = 'users';
  static const String _poolField = 'pool';

  /// Loads pool state from Firestore. Returns a fresh PoolState if none exists.
  /// Called ONCE when the user logs in.
  static Future<PoolState> load(String uid) async {
    try {
      final doc = await _db.collection(_collection).doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey(_poolField)) {
          return PoolState.fromMap(
              Map<String, dynamic>.from(data[_poolField]));
        }
      }
    } catch (_) {
      // Silently fall back to fresh state to avoid app crashes.
    }
    return PoolState();
  }

  /// Saves pool state to Firestore using merge to avoid overwriting
  /// other user fields. This is a single write operation.
  static Future<void> save(String uid, PoolState state) async {
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
