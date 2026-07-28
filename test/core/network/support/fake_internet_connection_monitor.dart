import 'package:winner_spin/core/network/internet_connection_monitor.dart';

class FakeInternetConnectionMonitor extends InternetConnectionMonitor {
  FakeInternetConnectionMonitor({
    InternetConnectionStatus initialStatus = InternetConnectionStatus.connected,
  }) : _status = initialStatus;

  InternetConnectionStatus _status;
  int startCalls = 0;
  int refreshCalls = 0;
  int pauseCalls = 0;

  @override
  InternetConnectionStatus get status => _status;

  void setStatus(InternetConnectionStatus value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  @override
  Future<void> start() async {
    startCalls++;
  }

  @override
  Future<void> refresh() async {
    refreshCalls++;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
  }
}
