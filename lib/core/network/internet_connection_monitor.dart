import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum InternetConnectionStatus { checking, connected, disconnected }

abstract class InternetConnectionMonitor extends ChangeNotifier {
  InternetConnectionStatus get status;

  Future<void> start();

  Future<void> refresh();

  Future<void> pause();
}

abstract interface class InternetConnectionStatusSource {
  Stream<bool> get statusChanges;

  Future<bool> get hasInternetAccess;

  Future<void> dispose();
}

class InternetConnectionCheckerStatusSource
    implements InternetConnectionStatusSource {
  InternetConnectionCheckerStatusSource._(this._connection);

  factory InternetConnectionCheckerStatusSource.live() {
    bool successStatus(int statusCode) => statusCode >= 200 && statusCode < 500;
    final connectivity = Connectivity();
    return InternetConnectionCheckerStatusSource._(
      InternetConnection.createInstance(
        checkInterval: const Duration(seconds: 2),
        triggerStream: connectivity.onConnectivityChanged,
        useDefaultOptions: false,
        customCheckOptions: [
          InternetCheckOption(
            uri: Uri.parse('https://www.gstatic.com/generate_204'),
            timeout: const Duration(seconds: 3),
            responseStatusFn: (response) => response.statusCode == 204,
          ),
          InternetCheckOption(
            uri: Uri.parse('https://identitytoolkit.googleapis.com'),
            timeout: const Duration(seconds: 3),
            responseStatusFn: (response) => successStatus(response.statusCode),
          ),
        ],
      ),
    );
  }

  final InternetConnection _connection;

  @override
  Future<bool> get hasInternetAccess => _connection.hasInternetAccess;

  @override
  Stream<bool> get statusChanges => _connection.onStatusChange.map(
    (status) => status == InternetStatus.connected,
  );

  @override
  Future<void> dispose() => _connection.dispose();
}

class AppInternetConnectionMonitor extends InternetConnectionMonitor {
  AppInternetConnectionMonitor({InternetConnectionStatusSource? source})
    : _source = source ?? InternetConnectionCheckerStatusSource.live();

  final InternetConnectionStatusSource _source;
  StreamSubscription<bool>? _subscription;
  Future<void>? _refreshOperation;
  InternetConnectionStatus _status = InternetConnectionStatus.checking;
  bool _disposed = false;

  @override
  InternetConnectionStatus get status => _status;

  @override
  Future<void> start() async {
    if (_disposed || _subscription != null) return;
    _subscription = _source.statusChanges.listen(
      _applyConnectionResult,
      onError: (_, _) => _setStatus(InternetConnectionStatus.disconnected),
    );
  }

  @override
  Future<void> refresh() {
    if (_disposed) return Future<void>.value();
    return _refreshOperation ??= _performRefresh();
  }

  Future<void> _performRefresh() async {
    try {
      _applyConnectionResult(await _source.hasInternetAccess);
    } catch (_) {
      _setStatus(InternetConnectionStatus.disconnected);
    } finally {
      _refreshOperation = null;
    }
  }

  @override
  Future<void> pause() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
  }

  void _applyConnectionResult(bool isConnected) {
    _setStatus(
      isConnected
          ? InternetConnectionStatus.connected
          : InternetConnectionStatus.disconnected,
    );
  }

  void _setStatus(InternetConnectionStatus value) {
    if (_disposed || _status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_source.dispose());
    super.dispose();
  }
}
