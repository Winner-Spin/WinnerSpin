import 'package:flutter/foundation.dart';

class SlotReelController {
  Object? _owner;
  VoidCallback? _quickStop;

  void quickStop() => _quickStop?.call();

  void attach(Object owner, VoidCallback quickStop) {
    _owner = owner;
    _quickStop = quickStop;
  }

  void detach(Object owner) {
    if (_owner == owner) {
      _owner = null;
      _quickStop = null;
    }
  }
}
