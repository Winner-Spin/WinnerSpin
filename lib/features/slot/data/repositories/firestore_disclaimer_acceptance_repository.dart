import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/first_launch_disclaimer_repository.dart';

/// Stores the disclaimer acceptance on the user document.
///
/// Three fields, no more: which text was accepted, when, and by which build.
/// Nothing device-identifying is recorded — the account already identifies the
/// player, and collecting an IP or device id would add a privacy obligation
/// without adding evidentiary value.
class FirestoreDisclaimerAcceptanceRepository
    implements DisclaimerAcceptanceRepository {
  FirestoreDisclaimerAcceptanceRepository({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 6),
  }) : _injectedDb = firestore;

  final FirebaseFirestore? _injectedDb;
  final Duration timeout;

  /// Resolved lazily so constructing the repository never requires an
  /// initialized Firebase app (keeps widget tests cheap).
  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  static const String collection = 'users';
  static const String versionField = 'disclaimerVersion';
  static const String acceptedAtField = 'disclaimerAcceptedAt';
  static const String appVersionField = 'disclaimerAppVersion';

  @override
  Future<bool> hasAccepted({
    required String userId,
    required int version,
  }) async {
    final doc = await _db
        .collection(collection)
        .doc(userId)
        .get()
        .timeout(timeout);
    return acceptedVersionOf(doc.data()) >= version;
  }

  @override
  Future<void> recordAcceptance({
    required String userId,
    required int version,
    required String appVersion,
  }) {
    return _db.collection(collection).doc(userId).set({
      versionField: version,
      // Server time, not the device clock: a player with a wrong or tampered
      // clock would otherwise stamp the record with a meaningless date.
      acceptedAtField: FieldValue.serverTimestamp(),
      appVersionField: appVersion,
    }, SetOptions(merge: true)).timeout(timeout);
  }

  @override
  Future<void> archiveAcceptance({
    required String userId,
    required String email,
  }) async {
    final source = await _db
        .collection(collection)
        .doc(userId)
        .get()
        .timeout(timeout);
    final data = source.data();
    if (acceptedVersionOf(data) <= 0) return;

    // The values are copied, not re-stated. The rules check each one against
    // the live user document, so an archive that says something the account
    // never said cannot be written.
    await _db.collection(archiveCollection).doc(userId).set({
      emailField: email,
      versionField: data![versionField],
      acceptedAtField: data[acceptedAtField],
      appVersionField: data[appVersionField],
      archivedAtField: FieldValue.serverTimestamp(),
    }).timeout(timeout);
  }

  static const String archiveCollection = 'disclaimerAcceptances';
  static const String emailField = 'email';
  static const String archivedAtField = 'archivedAt';

  /// Highest disclaimer version [data] records as accepted, or 0 for none.
  @visibleForTesting
  static int acceptedVersionOf(Map<String, dynamic>? data) {
    final stored = data?[versionField];
    return stored is num ? stored.toInt() : 0;
  }
}
