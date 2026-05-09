import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'multiplier_label.dart';

/// Lottie bomb animation that plays in a root overlay above a multiplier
/// cell. The grid cell renders the bomb frozen on frame 0; this overlay
/// then plays the full timeline (fuse → blast → tail) on top. The blast
/// moment is exposed via [onBlast] so the host can clear the underlying
/// frozen bomb the instant it visually detonates, instead of waiting for
/// the smoke tail to finish.
class MultiplierBombAnimation {
  MultiplierBombAnimation._();

  static const String assetPath =
      'assets/animations/Bomb_Animation_ORIGINAL_LOGIC_fuse_burn_spark_synced_tip_removed.json';

  /// Composition timeline: blast frame / total frames (35 / 85).
  static const double _blastProgress = 35.0 / 85.0;

  /// Cut-off shortly after the blast trigger — keeps the explosion
  /// visible just long enough to read, then drops the overlay so the
  /// rising 5x sprite has the screen to itself instead of competing
  /// with the smoke tail.
  static const double _blastEndProgress = 38.0 / 85.0;

  /// Spawns the bomb in the root overlay. Future resolves the moment
  /// the full timeline finishes and the entry has been removed.
  static Future<void> play({
    required BuildContext context,
    required Offset cellCenter,
    required double cellSize,
    required int multiplierValue,
    VoidCallback? onBlast,
  }) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final completer = Completer<void>();
    late final OverlayEntry entry;

    // Match the cell so the blast scale stays consistent with the
    // resting bomb in the grid.
    final renderSize = cellSize;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: cellCenter.dx - renderSize / 2,
        top: cellCenter.dy - renderSize / 2,
        width: renderSize,
        height: renderSize,
        child: IgnorePointer(
          child: _BombPlayer(
            multiplierValue: multiplierValue,
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
  final int multiplierValue;

  const _BombPlayer({
    required this.onComplete,
    required this.multiplierValue,
    this.onBlast,
  });

  @override
  State<_BombPlayer> createState() => _BombPlayerState();
}

class _BombPlayerState extends State<_BombPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _blastFired = false;
  bool _bombEnded = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    _ctrl.addListener(_onTick);
  }

  void _onTick() {
    final v = _ctrl.value;
    if (!_blastFired && v >= MultiplierBombAnimation._blastProgress) {
      _blastFired = true;
      widget.onBlast?.call();
    }
    if (!_bombEnded && v >= MultiplierBombAnimation._blastEndProgress) {
      _bombEnded = true;
      // The full blast has been on-screen now; cut the overlay before
      // the smoke tail starts so the rising 5x sprite isn't covered.
      _ctrl.stop();
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  // (frame, scale-relative-to-base) pairs taken straight from the bomb
  // composition's Bomb-layer scale keyframes. Lerping between them gives
  // the label the same anticipation pop the bomb body itself plays.
  static const _kBombScaleKeyframes = <List<double>>[
    [23.788, 1.0],
    [25.076, 1.218],
    [26.608, 1.0],
    [28.141, 1.218],
    [29.673, 1.0],
    [31.398, 1.218],
    [32.325, 1.0],
    [33.338, 1.218],
    [34.266, 1.0],
    [35.000, 1.384],
  ];
  static const _kCompositionFrames = 85.0;

  double _bombScaleAt(double progress) {
    final frame = progress * _kCompositionFrames;
    if (frame <= _kBombScaleKeyframes.first[0]) return 1.0;
    if (frame >= _kBombScaleKeyframes.last[0]) {
      return _kBombScaleKeyframes.last[1];
    }
    for (var i = 0; i < _kBombScaleKeyframes.length - 1; i++) {
      final a = _kBombScaleKeyframes[i];
      final b = _kBombScaleKeyframes[i + 1];
      if (frame >= a[0] && frame < b[0]) {
        final t = (frame - a[0]) / (b[0] - a[0]);
        return a[1] + (b[1] - a[1]) * t;
      }
    }
    return _kBombScaleKeyframes.last[1];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        // Lottie back layer plays the JSON's blast frames at full
        // opacity — fade was muting the colourful explosion. The
        // overlay still cuts off at _blastEndProgress so the smoke
        // tail doesn't linger behind the rising sprite.
        Lottie.asset(
          MultiplierBombAnimation.assetPath,
          controller: _ctrl,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            _ctrl
              ..duration = composition.duration
              ..forward().then((_) {
                if (!mounted || _bombEnded) return;
                _bombEnded = true;
                if (!_blastFired) {
                  _blastFired = true;
                  widget.onBlast?.call();
                }
                widget.onComplete();
              });
          },
        ),
        // Multiplier label rides in the same overlay, on top of the
        // bomb. The fade above only dims the Lottie, so the label
        // stays at full opacity through the entire fuse + blast.
        // The label also pops larger the instant the blast triggers,
        // riding the explosion's energy until the overlay closes.
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            // Mirror the bomb composition's full scale curve so the
            // label oscillates with the same anticipation pop pattern
            // and lands the 1.384 peak on the exact blast frame.
            // Frames are normalised against the 85-frame timeline.
            final v = _ctrl.value;
            final scale = _bombScaleAt(v);
            return Align(
              alignment: Alignment(
                MultiplierLabel.labelXOffsetFor(widget.multiplierValue),
                0.22,
              ),
              child: Transform.scale(scale: scale, child: child),
            );
          },
          child: FractionallySizedBox(
            widthFactor: 1.0,
            heightFactor: 0.43,
            child: MultiplierLabel(
              value: widget.multiplierValue,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}
