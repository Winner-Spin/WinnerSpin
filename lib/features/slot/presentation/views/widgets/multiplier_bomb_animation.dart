import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/audio/app_audio_context.dart';
import 'multiplier_label.dart';

class MultiplierBombAnimation {
  MultiplierBombAnimation._();

  static const String assetPath =
      'assets/animations/Bomb_Animation_ORIGINAL_LOGIC_fuse_burn_spark_synced_tip_removed.json';

  static const double _blastProgress = 35.0 / 85.0;

  static const double _blastEndProgress = 50.0 / 85.0;

  static Future<void> play({
    required BuildContext context,
    required Offset cellCenter,
    required double cellSize,
    required int multiplierValue,
    bool soundEnabled = true,
    int speedMultiplier = 1,
    VoidCallback? onBlast,
  }) async {
    final overlay = Overlay.of(context);
    final completer = Completer<void>();
    late final OverlayEntry entry;

    final bombSize = cellSize * MultiplierLabel.bombScaleFor(multiplierValue);
    final renderSize = bombSize * 2.25;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        left: cellCenter.dx - renderSize / 2,
        top: cellCenter.dy - renderSize / 2,
        width: renderSize,
        height: renderSize,
        child: IgnorePointer(
          child: Center(
            child: SizedBox(
              width: bombSize,
              height: bombSize,
              child: _BombPlayer(
                multiplierValue: multiplierValue,
                soundEnabled: soundEnabled,
                speedMultiplier: speedMultiplier,
                onBlast: onBlast,
                onComplete: () {
                  if (entry.mounted) entry.remove();
                  if (!completer.isCompleted) completer.complete();
                },
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    await completer.future;
  }
}

class MultiplierDustResidue extends StatelessWidget {
  const MultiplierDustResidue({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(
        painter: _DustResiduePainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _BombPlayer extends StatefulWidget {
  final VoidCallback? onBlast;
  final VoidCallback onComplete;
  final int multiplierValue;
  final bool soundEnabled;
  final int speedMultiplier;

  const _BombPlayer({
    required this.onComplete,
    required this.multiplierValue,
    required this.soundEnabled,
    this.speedMultiplier = 1,
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
      if (widget.soundEnabled) {
        unawaited(_BombExplosionSound.play());
      }
      widget.onBlast?.call();
    }
    if (!_bombEnded && v >= MultiplierBombAnimation._blastEndProgress) {
      _bombEnded = true;
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
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final blastT =
                ((_ctrl.value - MultiplierBombAnimation._blastProgress) /
                        (MultiplierBombAnimation._blastEndProgress -
                            MultiplierBombAnimation._blastProgress))
                    .clamp(0.0, 1.0);
            final scale = 1.0 + Curves.easeOutCubic.transform(blastT) * 0.55;
            return Transform.scale(scale: scale, child: child);
          },
          child: Lottie.asset(
            MultiplierBombAnimation.assetPath,
            controller: _ctrl,
            fit: BoxFit.contain,
            onLoaded: (composition) {
              final speed = widget.speedMultiplier.clamp(1, 3).toInt();
              final durationMs = (composition.duration.inMilliseconds / speed)
                  .round();
              _ctrl
                ..duration = Duration(milliseconds: durationMs)
                ..forward().then((_) {
                  if (!mounted || _bombEnded) return;
                  _bombEnded = true;
                  if (!_blastFired) {
                    _blastFired = true;
                    if (widget.soundEnabled) {
                      unawaited(_BombExplosionSound.play());
                    }
                    widget.onBlast?.call();
                  }
                  widget.onComplete();
                });
            },
          ),
        ),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final v = _ctrl.value;
            final scale = _bombScaleAt(v);
            final visible = v < MultiplierBombAnimation._blastProgress;
            return Align(
              alignment: Alignment(
                MultiplierLabel.labelXOffsetFor(widget.multiplierValue),
                0.22,
              ),
              child: Opacity(
                opacity: visible ? 1.0 : 0.0,
                child: Transform.scale(scale: scale, child: child),
              ),
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

class _BombExplosionSound {
  static const _assetPath = 'audio/Items/Bomb_Explosion.wav';
  static const _volume = 0.72;

  static Future<AudioPool>? _poolFuture;

  static Future<void> play() async {
    try {
      final pool = await (_poolFuture ??= AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: 3,
        maxPlayers: 8,
        playerMode: PlayerMode.mediaPlayer,
        audioContext: AppAudioContext.game,
      ));
      await pool.start(volume: _volume);
    } catch (_) {

    }
  }
}

class _DustResiduePainter extends CustomPainter {
  const _DustResiduePainter();

  static const _coreColor = Color(0xFFFFF6C8);
  static const _palette = <Color>[
    Color(0xFFFFEC50),
    Color(0xFFFFC247),
    Color(0xFFFF7A30),
    Color(0xFFFF3E70),
    Color(0xFFB246FF),
    Color(0xFF24D8FF),
  ];

  double _h(int seed, int i) =>
      (math.sin(seed * 12.9898 + i * 78.233) * 43758.5453) % 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = shortest * 0.42;

    final coreGlow = Paint()
      ..shader = RadialGradient(
        colors: [
          _coreColor.withValues(alpha: 0.78),
          const Color(0xFFFFC247).withValues(alpha: 0.40),
          const Color(0xFFFF7A30).withValues(alpha: 0.18),
          const Color(0x00FF7A30),
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.55));
    canvas.drawCircle(center, radius * 0.55, coreGlow);

    const rayCount = 30;
    for (var i = 0; i < rayCount; i++) {
      final base = (i / rayCount) * math.pi * 2;
      final jitter = (_h(11, i) - 0.5) * (math.pi / rayCount) * 1.4;
      final angle = base + jitter;

      final outer = radius * (0.55 + _h(17, i) * 0.55);
      final inner = radius * (0.14 + _h(23, i) * 0.12);
      final width = shortest * (0.010 + _h(31, i) * 0.014);

      final color = _palette[i % _palette.length];
      _drawSpark(canvas, center, angle, inner, outer, width, color);
    }

    for (var i = 0; i < 36; i++) {
      final angle = i * 2.399963229728653 + 0.7;
      final dist = radius * (0.30 + _h(53, i) * 0.70);
      final point =
          center + Offset(math.cos(angle) * dist, math.sin(angle) * dist);
      final dotRadius = shortest * (0.008 + _h(67, i) * 0.012);
      final color = _palette[(i * 5) % _palette.length];

      final glow = Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.50), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: point, radius: dotRadius * 2.6));
      canvas.drawCircle(point, dotRadius * 2.6, glow);
      canvas.drawCircle(
        point,
        dotRadius,
        Paint()..color = color.withValues(alpha: 0.75),
      );
    }
  }

  void _drawSpark(
    Canvas canvas,
    Offset center,
    double angle,
    double innerR,
    double outerR,
    double width,
    Color color,
  ) {
    final p1 =
        center + Offset(math.cos(angle) * innerR, math.sin(angle) * innerR);
    final p2 =
        center + Offset(math.cos(angle) * outerR, math.sin(angle) * outerR);
    final paint = Paint()
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..shader =
          LinearGradient(
            colors: [
              _coreColor.withValues(alpha: 0.55),
              color.withValues(alpha: 0.65),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4, 1.0],
            begin: const Alignment(-1, 0),
            end: const Alignment(1, 0),
            transform: GradientRotation(angle),
          ).createShader(
            Rect.fromPoints(
              center.translate(-outerR, -outerR),
              center.translate(outerR, outerR),
            ),
          );
    canvas.drawLine(p1, p2, paint);
  }

  @override
  bool shouldRepaint(covariant _DustResiduePainter oldDelegate) => false;
}
