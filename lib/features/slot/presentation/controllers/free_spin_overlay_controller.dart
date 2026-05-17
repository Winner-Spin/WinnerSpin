import 'package:flutter/material.dart';

import '../views/game/widgets/presentation/free_spin_summary_popup.dart';
import '../views/game/widgets/presentation/free_spin_win_popup.dart';

class FreeSpinOverlayController {
  OverlayEntry? _activeEntry;

  bool get hasActiveOverlay => _activeEntry != null;

  void showWinPopup({
    required OverlayState overlay,
    required int value,
    required bool isRetrigger,
    required double winAmount,
    required int cacheWidth,
    required VoidCallback onDismiss,
  }) {
    clear();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FreeSpinWinPopup(
        value: value,
        isRetrigger: isRetrigger,
        winAmount: winAmount,
        cacheWidth: cacheWidth,
        onDismiss: () {
          if (_activeEntry != entry) return;
          _activeEntry = null;
          entry.remove();
          onDismiss();
        },
      ),
    );
    _activeEntry = entry;
    overlay.insert(entry);
  }

  void showSummaryPopup({
    required OverlayState overlay,
    required double totalWin,
    required int totalFreeSpins,
    required int cacheWidth,
    required VoidCallback onDismiss,
  }) {
    clear();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FreeSpinSummaryPopup(
        totalWin: totalWin,
        totalFreeSpins: totalFreeSpins,
        cacheWidth: cacheWidth,
        onDismiss: () {
          if (_activeEntry != entry) return;
          _activeEntry = null;
          entry.remove();
          onDismiss();
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
