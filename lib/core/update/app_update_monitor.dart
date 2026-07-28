import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'required_version_source.dart';

enum AppUpdateStatus {
  /// Not checked yet, or the check could not reach a conclusion.
  unknown,

  /// Installed build meets the demanded minimum.
  upToDate,

  /// Backend demands a newer version; the app must not be used until updated.
  updateRequired,
}

abstract class AppUpdateMonitor extends ChangeNotifier {
  AppUpdateStatus get status;

  /// Version the backend demands, when known — shown in the prompt.
  String? get requiredVersion;

  /// Listing URL to send the player to.
  String? get storeUrl;

  Future<void> refresh();
}

/// Reports whether the installed build is older than the version demanded by
/// the backend.
///
/// The single most important rule here is that every failure path resolves to
/// [AppUpdateStatus.upToDate], never [AppUpdateStatus.updateRequired]. The read
/// can fail because the device is offline, because the config document is
/// missing, or because Firestore is slow — none of those are reasons to lock a
/// player out of a game they already installed.
///
/// [refresh] performs exactly one check per call and de-duplicates concurrent
/// calls, so the app can call it once on start-up and once per resume.
class StoreAppUpdateMonitor extends AppUpdateMonitor {
  StoreAppUpdateMonitor({
    required RequiredVersionSource source,
    required Future<String?> Function() installedVersion,
    this.fallbackStoreUrl,
  }) : _source = source,
       _installedVersion = installedVersion;

  final RequiredVersionSource _source;
  final Future<String?> Function() _installedVersion;

  /// Used when the config document carries no `storeUrl`.
  final String? fallbackStoreUrl;

  AppUpdateStatus _status = AppUpdateStatus.unknown;
  String? _requiredVersion;
  String? _storeUrl;
  Future<void>? _inFlight;
  bool _disposed = false;

  @override
  AppUpdateStatus get status => _status;

  @override
  String? get requiredVersion => _requiredVersion;

  @override
  String? get storeUrl => _storeUrl ?? fallbackStoreUrl;

  @override
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    return _inFlight ??= _performCheck();
  }

  Future<void> _performCheck() async {
    try {
      final installed = AppVersion.tryParse(await _installedVersion());
      if (installed == null) {
        _setStatus(AppUpdateStatus.upToDate);
        return;
      }

      final required = await _source.fetchRequiredVersion();
      final minimum = AppVersion.tryParse(required?.version);
      if (required == null || minimum == null) {
        // Missing document, offline device, or an unusable value.
        _setStatus(AppUpdateStatus.upToDate);
        return;
      }

      _requiredVersion = required.version;
      _storeUrl = required.storeUrl;
      _setStatus(
        minimum > installed
            ? AppUpdateStatus.updateRequired
            : AppUpdateStatus.upToDate,
      );
    } catch (error) {
      debugPrint('App update check failed: $error');
      _setStatus(AppUpdateStatus.upToDate);
    } finally {
      _inFlight = null;
    }
  }

  void _setStatus(AppUpdateStatus value) {
    if (_disposed || _status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
