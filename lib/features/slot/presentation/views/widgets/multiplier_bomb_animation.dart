import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Lottie bomb animation that plays in a root overlay above a multiplier
/// cell. The grid cell renders the bomb frozen on frame 0; this overlay
/// then plays the full timeline (fuse → blast → tail) on top. The blast
/// moment is exposed via [onBlast] so the host can clear the underlying
/// frozen bomb the instant it visually detonates, instead of waiting for
/// the smoke tail to finish.
class MultiplierBombAnimation {
  MultiplierBombAnimation._();

  static const String assetPath =
      'assets/animations/Bomb_Animation_extra_colorful_reference_style_35fuse_50explosion.json';

  /// Composition timeline: blast frame / total frames (35 / 85).
  static const double _blastProgress = 35.0 / 85.0;

  /// Spawns the bomb in the root overlay. Future resolves the moment
  /// the full timeline finishes and the entry has been removed.
  static Future<void> play({
    required BuildContext context,
    required Offset cellCenter,
    required double cellSize,
    VoidCallback? onBlast,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<void>();
    late final OverlayEntry entry;

    // Overlay matches the cell so the playing bomb stays at the same
    // visual size as the frozen bomb in the grid.
    final renderSize = cellSize;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: cellCenter.dx - renderSize / 2,
        top: cellCenter.dy - renderSize / 2,
        width: renderSize,
        height: renderSize,
        child: IgnorePointer(
          child: _BombPlayer(
            onBlast: onBlast,
            onComplete: () {
              if (entry.mounted) entry.remove();
              if (!completer.isCompleted) completer.complete();
            },
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await completer.future;
  }
}

class _BombPlayer extends StatefulWidget {
  final VoidCallback? onBlast;
  final VoidCallback onComplete;

  const _BombPlayer({required this.onComplete, this.onBlast});

  @override
  State<_BombPlayer> createState() => _BombPlayerState();
}

class _BombPlayerState extends State<_BombPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _blastFired = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addListener(_maybeFireBlast);
  }

  void _maybeFireBlast() {
    if (_blastFired) return;
    if (_ctrl.value >= MultiplierBombAnimation._blastProgress) {
      _blastFired = true;
      widget.onBlast?.call();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_maybeFireBlast);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Lottie.asset(
      MultiplierBombAnimation.assetPath,
      controller: _ctrl,
      fit: BoxFit.contain,
      onLoaded: (composition) {
        _ctrl
          ..duration = composition.duration
          ..forward().then((_) {
            if (!mounted) return;
            if (!_blastFired) {
              _blastFired = true;
              widget.onBlast?.call();
            }
            widget.onComplete();
          });
      },
    );
  }
}
