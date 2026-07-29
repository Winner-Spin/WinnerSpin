import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'required_version_source.dart';

/// Reads the demanded minimum version from a single Firestore document.
///
/// Document: `config/appVersion`
/// ```
/// androidMinimumVersion: "1.1.0"
/// iosMinimumVersion: "1.2.0"
/// androidStoreUrl: "https://play.google.com/store/apps/details?id=..."
/// iosStoreUrl: "https://apps.apple.com/app/id..."
/// ```
/// `minimumVersion` remains a shared fallback for existing configurations.
class FirestoreRequiredVersionSource implements RequiredVersionSource {
  FirestoreRequiredVersionSource({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 6),
    TargetPlatform? platform,
  }) : _injectedDb = firestore,
       _platform = platform ?? defaultTargetPlatform;

  final FirebaseFirestore? _injectedDb;
  final TargetPlatform _platform;
  final Duration timeout;

  /// Resolved lazily so constructing this never requires an initialized
  /// Firebase app, which keeps widget tests cheap.
  FirebaseFirestore get _db => _injectedDb ?? FirebaseFirestore.instance;

  static const String collection = 'config';
  static const String document = 'appVersion';
  static const String minimumVersionField = 'minimumVersion';
  static const String storeUrlField = 'storeUrl';
  static const String androidMinimumVersionField = 'androidMinimumVersion';
  static const String iosMinimumVersionField = 'iosMinimumVersion';
  static const String androidStoreUrlField = 'androidStoreUrl';
  static const String iosStoreUrlField = 'iosStoreUrl';

  @override
  Future<RequiredVersion?> fetchRequiredVersion() async {
    try {
      final snapshot = await _db
          .collection(collection)
          .doc(document)
          .get(const GetOptions(source: Source.server))
          .timeout(timeout);

      if (!snapshot.exists) return null;
      return parse(snapshot.data(), platform: _platform);
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
  static RequiredVersion? parse(
    Map<String, dynamic>? data, {
    TargetPlatform? platform,
  }) {
    if (data == null) return null;

    final version = switch (platform) {
      TargetPlatform.android =>
        data[androidMinimumVersionField] ?? data[minimumVersionField],
      TargetPlatform.iOS || TargetPlatform.macOS =>
        data[iosMinimumVersionField] ?? data[minimumVersionField],
      _ => data[minimumVersionField],
    };
    if (version is! String || version.trim().isEmpty) return null;

    final storeUrl = switch (platform) {
      TargetPlatform.android =>
        data[androidStoreUrlField] ?? data[storeUrlField],
      TargetPlatform.iOS ||
      TargetPlatform.macOS => data[iosStoreUrlField] ?? data[storeUrlField],
      _ => data[storeUrlField],
    };
    return RequiredVersion(
      version: version.trim(),
      storeUrl: storeUrl is String && storeUrl.trim().isNotEmpty
          ? storeUrl.trim()
          : null,
    );
  }
}
