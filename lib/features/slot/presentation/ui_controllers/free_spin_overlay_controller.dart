import 'package:flutter/material.dart';

import '../services/free_spin_popup_image_provider.dart';
import '../views/game/widgets/presentation/free_spins/free_spin_summary_popup.dart';
import '../views/game/widgets/presentation/free_spins/free_spin_win_popup.dart';

class FreeSpinOverlayController {
  OverlayEntry? _activeEntry;

  bool get hasActiveOverlay => _activeEntry != null;

  void showWinPopup({
    required OverlayState overlay,
    required int value,
    required bool isRetrigger,
    required double winAmount,
    required VoidCallback onDismiss,
  }) {
    clear();

    final imageProvider = FreeSpinPopupImageProvider.resolve(
      overlay.context,
      FreeSpinWinPopup.assetPath,
    );
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FreeSpinWinPopup(
        value: value,
        isRetrigger: isRetrigger,
        winAmount: winAmount,
        imageProvider: imageProvider,
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
    required VoidCallback onDismiss,
  }) {
    clear();

    final imageProvider = FreeSpinPopupImageProvider.resolve(
      overlay.context,
      FreeSpinSummaryPopup.assetPath,
    );
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FreeSpinSummaryPopup(
        totalWin: totalWin,
        totalFreeSpins: totalFreeSpins,
        imageProvider: imageProvider,
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
