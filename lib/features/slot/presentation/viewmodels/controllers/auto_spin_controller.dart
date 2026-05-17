class AutoSpinController {
  bool _active = false;
  int _remaining = 0;
  int _speedMultiplier = 1;

  bool get active => _active;
  int get remaining => _remaining;
  int get speedMultiplier => _speedMultiplier;

  bool start(int spinCount, {required int speedMultiplier}) {
    if (_active || spinCount <= 0) return false;
    _remaining = spinCount;
    _speedMultiplier = speedMultiplier.clamp(1, 3).toInt();
    _active = true;
    return true;
  }

  bool stop() {
    if (!_active && _remaining == 0) return false;
    stopSilently();
    return true;
  }

  void stopSilently() {
    _active = false;
    _remaining = 0;
  }

  void consumeAtSpinStart() {
    if (!_active) return;
    _remaining = (_remaining - 1).clamp(0, 9999).toInt();
  }

  void stopIfCompleted() {
    if (_active && _remaining == 0) {
      _active = false;
    }
  }

  bool canContinue({required bool isBusy}) {
    return _active && !isBusy;
  }

  void nextSpeed() {
    _speedMultiplier = (_speedMultiplier % 3) + 1;
  }
}
