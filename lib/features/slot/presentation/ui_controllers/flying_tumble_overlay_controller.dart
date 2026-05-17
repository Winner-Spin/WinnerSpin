import 'package:flutter/material.dart';

import '../views/game/widgets/presentation/effects/flying_tumble_sprite.dart';

class FlyingTumbleOverlayController {
  OverlayEntry? _activeEntry;

  bool get hasActiveFlight => _activeEntry != null;

  bool showFromAnchors({
    required OverlayState overlay,
    required GlobalKey startKey,
    required GlobalKey endKey,
    required double amount,
    required TextStyle style,
    required Duration duration,
    required VoidCallback onComplete,
  }) {
    final startCenter = _globalCenterOf(startKey);
    final endCenter = _globalCenterOf(endKey);
    if (startCenter == null || endCenter == null) return false;

    clear();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => FlyingTumbleSprite(
        amount: amount,
        start: startCenter,
        end: endCenter,
        style: style,
        duration: duration,
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
    return true;
  }

  Offset? _globalCenterOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
  }

  void clear() {
    _activeEntry?.remove();
    _activeEntry = null;
  }

  void dispose() {
    clear();
  }
}
