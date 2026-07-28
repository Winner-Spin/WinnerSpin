import 'package:flutter/foundation.dart';

/// The minimum version the backend currently demands.
@immutable
class RequiredVersion {
  const RequiredVersion({required this.version, this.storeUrl});

  /// Raw version string, e.g. `1.1.0`. Builds older than this are blocked.
  final String version;

  /// Where to send the player to update. Falls back to a compiled-in URL.
  final String? storeUrl;

  @override
  bool operator ==(Object other) =>
      other is RequiredVersion &&
      other.version == version &&
      other.storeUrl == storeUrl;

  @override
  int get hashCode => Object.hash(version, storeUrl);
}

abstract interface class RequiredVersionSource {
  /// Returns the demanded version, or null when it cannot be determined.
  ///
  /// Null must never be read as "an update is required". A failed read means
  /// the app could not ask — being offline is not a reason to lock a player
  /// out of a game they already installed.
  Future<RequiredVersion?> fetchRequiredVersion();
}
