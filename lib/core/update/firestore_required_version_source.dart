import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'required_version_source.dart';

/// Reads the demanded minimum version from a single Firestore document.
///
/// Document: `config/appVersion`
/// ```
/// minimumVersion: "1.1.0"     // required, string
/// storeUrl:       "https://apps.apple.com/app/id6795310235"   // optional
/// ```
///
/// Chosen over querying the App Store because the decision stays yours: a
/// release only becomes mandatory when you raise `minimumVersion`, so shipping
/// a minor update does not lock out everyone still on the previous build.
///
/// The document is read unauthenticated on purpose — the gate has to work on
/// the login screen too, before anyone signs in. `firestore.rules` therefore
/// allows public reads of `config/**` and no client writes at all.
class FirestoreRequiredVersionSource implements RequiredVersionSource {
  FirestoreRequiredVersionSource({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 6),
  }) : _injectedDb = firestore;

  final FirebaseFirestore? _injectedDb;
  final Duration timeout;

  /// Resolved lazily so constructing this never requires an initialized
  /// Firebase app, which keeps widget tests cheap.
  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  static const String collection = 'config';
  static const String document = 'appVersion';
  static const String minimumVersionField = 'minimumVersion';
  static const String storeUrlField = 'storeUrl';

  @override
  Future<RequiredVersion?> fetchRequiredVersion() async {
    try {
      final snapshot = await _db
          .collection(collection)
          .doc(document)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);

      if (!snapshot.exists) return null;
      return parse(snapshot.data());
    } catch (error) {
      // Offline, permission denied, missing document, slow network — none of
      // these justify blocking the app, so the caller sees "unknown".
      debugPrint('Required version lookup failed: $error');
      return null;
    }
  }

  /// Turns the raw document into a [RequiredVersion], or null when the data is
  /// unusable.
  ///
  /// Kept separate from the network call so the parsing — where the bugs
  /// actually live — is testable without a Firestore instance. Consistent with
  /// the other Firestore adapters in this project, the call itself is covered
  /// by the rules tests rather than a unit test.
  @visibleForTesting
  static RequiredVersion? parse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final version = data[minimumVersionField];
    if (version is! String || version.trim().isEmpty) return null;

    final storeUrl = data[storeUrlField];
    return RequiredVersion(
      version: version.trim(),
      storeUrl: storeUrl is String && storeUrl.trim().isNotEmpty
          ? storeUrl.trim()
          : null,
    );
  }
}
