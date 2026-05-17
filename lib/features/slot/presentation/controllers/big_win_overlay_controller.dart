import 'package:flutter/material.dart';

import '../models/win_tier.dart';
import '../views/game/widgets/presentation/big_win_overlay.dart';

class BigWinOverlayController {
  OverlayEntry? _activeEntry;

  bool get hasActiveOverlay => _activeEntry != null;

  void show({
    required OverlayState overlay,
    required double amount,
    required WinTier tier,
    required bool instantAmount,
    required bool soundEnabled,
    required bool vibrationEnabled,
    required VoidCallback onComplete,
  }) {
    if (_activeEntry != null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => BigWinOverlay(
        amount: amount,
        tier: tier,
        instantAmount: instantAmount,
        soundEnabled: soundEnabled,
        vibrationEnabled: vibrationEnabled,
        onComplete: () {
          if (_activeEntry != entry) return;
          _activeEntry = null;
          entry.remove();
          onComplete();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  void clear() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  void dispose() {
    clear();
  }
}
