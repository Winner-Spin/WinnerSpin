import 'dart:async';

import 'package:flutter/material.dart';

import 'floating_collect_text.dart';

class MultiplierCollectAnimation {
  MultiplierCollectAnimation._();

  static Future<void> play({
    required BuildContext context,
    required Offset start,
    required Offset end,
    required int value,
    required double cellSize,
    double endSize = 32,
    Duration settleDuration = const Duration(milliseconds: 250),
    Duration flightDuration = const Duration(milliseconds: 700),
    Duration burstDuration = const Duration(milliseconds: 850),
    VoidCallback? onApproaching,
    VoidCallback? onSettleComplete,
  }) async {
    final overlay = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => FloatingCollectText(
        start: start,
        end: end,
        value: value,
        startSize: cellSize,
        endSize: endSize,
        settleDuration: settleDuration,
        flightDuration: flightDuration,
        burstDuration: burstDuration,
        onApproaching: onApproaching,
        onSettleComplete: onSettleComplete,
        onArrived: () {
          if (entry.mounted) entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );

    overlay.insert(entry);
    await completer.future;
  }
}
