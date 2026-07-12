import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/game_presentation_timings.dart';

class FreeSpinAutoPlayController {
  Timer? _continueTimer;
  bool _awaitingAwardAcknowledgement = false;

  bool get awaitingAwardAcknowledgement => _awaitingAwardAcknowledgement;

  void pauseForAwardAcknowledgement() {
    _awaitingAwardAcknowledgement = true;
    cancelPending();
  }

  void acknowledgeAward() {
    _awaitingAwardAcknowledgement = false;
  }

  void continueIfReady({
    required bool Function() canStart,
    required VoidCallback spin,
    Duration delay = GamePresentationTimings.freeSpinAutoPlayDelay,
  }) {
    if (_awaitingAwardAcknowledgement ||
        !canStart() ||
        _continueTimer?.isActive == true) {
      return;
    }

    _continueTimer = Timer(delay, () {
      _continueTimer = null;
      if (_awaitingAwardAcknowledgement || !canStart()) return;
      spin();
    });
  }

  void cancelPending() {
    _continueTimer?.cancel();
    _continueTimer = null;
  }

  void dispose() {
    cancelPending();
  }
}
