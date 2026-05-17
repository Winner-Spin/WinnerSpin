import 'dart:async';

import 'package:flutter/foundation.dart';

class InsufficientFundsHintController {
  bool _visible = false;
  Timer? _timer;

  bool get visible => _visible;

  void flash(VoidCallback notifyListeners) {
    _visible = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      _visible = false;
      notifyListeners();
    });
  }

  void clear() {
    _visible = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    clear();
  }
}
