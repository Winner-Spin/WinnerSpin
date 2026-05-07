import 'dart:async';

import 'package:flutter/material.dart';

import 'floating_collect_text.dart';

/// Drops a [FloatingCollectText] into the root overlay and removes it
/// when the flight finishes. Decoupled from layout — the caller
/// supplies start/end screen coordinates and the cell-sized origin
/// dimensions for the on-grid pop.
class MultiplierCollectAnimation {
  MultiplierCollectAnimation._();

  /// Spawns the flying value. The returned future resolves the moment
  /// the flight reaches [end] and the overlay entry is removed.
  ///
  /// [onApproaching] fires once the flight crosses the approach
  /// threshold (default 70% of the flight). Use it to start the in-bar
  /// pulse early so the floating asset and the bar pulse merge into a
  /// single beat instead of playing back to back.
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
    final overlay = Overlay.of(context, rootOverlay: true);
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
