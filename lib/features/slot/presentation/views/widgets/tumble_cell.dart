import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/audio/app_audio_context.dart';
import '../../../domain/enums/symbol_tier.dart';
import '../../../domain/models/symbol_registry.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_label.dart';

/// A single grid cell that handles four cascade-tumble effects independently
/// of the column-wide spin in [SlotReel]:
///   • Symbol pre-burst wobble (spring scale + rotation), then fade.
///   • Particle burst — gold sparks radiate outward as the symbol fades.
///   • Drop-in from above when [path] changes (new symbol falls into place).
///
/// Used by [SlotReel] only in the static (post-drop-in) state. During the
/// initial reel spin, the column-wide drop-out / drop-in animation runs
/// instead.
class TumbleCell extends StatefulWidget {
  final String path;
  final bool isFading;
  final double itemH;
  final int speedMultiplier;
  final bool soundEnabled;

  const TumbleCell({
    super.key,
    required this.path,
    required this.isFading,
    required this.itemH,
    this.speedMultiplier = 1,
    this.soundEnabled = true,
  });

  @override
  State<TumbleCell> createState() => _TumbleCellState();
}

class _TumbleCellState extends State<TumbleCell> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _dropController;
  late final AnimationController _burstController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _imageOpacity;
  late final Animation<double> _dropAnimation;
  late final Listenable _cellAnimationListenable;

  // Regenerated on each fade event so consecutive wins on the same cell
  // get distinct burst patterns; palette refreshes when [path] changes.
  late List<_Particle> _particles;
  late _GlowPalette _palette;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1750),
    );
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1950),
    );

    // Give the player a readable "this one is about to pop" wobble before the
    // dust burst starts, then make the symbol vanish quickly as it breaks apart.
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.36, 0.52, curve: Curves.easeOut),
    );
    // Drive the fade via Image.opacity so it goes through the image
    // shader's alpha channel — no per-cell saveLayer during a cascade.
    _imageOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation);
    _dropAnimation = CurvedAnimation(
      parent: _dropController,
      curve: Curves.easeOutCubic,
    );
    _cellAnimationListenable = Listenable.merge([
      _fadeController,
      _dropAnimation,
      _burstController,
    ]);

    _particles = _generateParticles();
    _palette = _GlowPalette.forPath(widget.path);

    _dropController.value = 1.0;

    // If the cell is created already in fading state (first tumble after spin),
    // animate the fade instead of snapping to fully transparent — the player
    // needs to see the symbol + glow before it disappears.
    if (widget.isFading) {
      _playPopSound();
      _fadeController.forward(from: 0.0);
      _burstController.forward(from: 0.0);
    } else {
      _fadeController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(TumbleCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.path != oldWidget.path) {
      _fadeController.value = 0.0;
      _dropController.forward(from: 0.0);
      _palette = _GlowPalette.forPath(widget.path);
      return;
    }

    if (widget.isFading != oldWidget.isFading) {
      if (widget.isFading) {
        _particles = _generateParticles();
        _playPopSound();
        _fadeController.forward(from: 0.0);
        _burstController.forward(from: 0.0);
      } else {
        _fadeController.value = 0.0;
        _burstController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dropController.dispose();
    _burstController.dispose();
    super.dispose();
  }

  List<_Particle> _generateParticles() {
    final rng = math.Random();
    return List.generate(90, (_) => _Particle.random(rng));
  }

  void _playPopSound() {
    if (!widget.soundEnabled) return;
    unawaited(_ItemExplosionPopSound.play());
  }

  double _preBurstScale(double t) {
    if (t < 0.10) return _lerp(1.0, 1.18, t / 0.10);
    if (t < 0.20) return _lerp(1.18, 0.94, (t - 0.10) / 0.10);
    if (t < 0.32) return _lerp(0.94, 1.10, (t - 0.20) / 0.12);
    if (t < 0.42) return _lerp(1.10, 1.0, (t - 0.32) / 0.10);
    return 1.0;
  }

  double _preBurstRotation(double t) {
    if (t < 0.10) return _lerp(0.0, -0.08, t / 0.10);
    if (t < 0.20) return _lerp(-0.08, 0.09, (t - 0.10) / 0.10);
    if (t < 0.32) return _lerp(0.09, -0.045, (t - 0.20) / 0.12);
    if (t < 0.42) return _lerp(-0.045, 0.0, (t - 0.32) / 0.10);
    return 0.0;
  }

  double _lerp(double begin, double end, double t) {
    final eased = Curves.easeInOut.transform(t.clamp(0.0, 1.0));
    return begin + (end - begin) * eased;
  }

  @override
  Widget build(BuildContext context) {
    final symbol = SymbolRegistry.byPath(widget.path);
    final perSymbolScale = symbol?.displayScale ?? 1.0;
    final isMultiplier = symbol?.tier == SymbolTier.multiplier;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _cellAnimationListenable,
        builder: (context, child) {
          final dy = (1.0 - _dropAnimation.value) * -widget.itemH;
          final scale = _preBurstScale(_fadeController.value) * perSymbolScale;
          final rotation = _preBurstRotation(_fadeController.value);
          // Particles begin as the original item disappears so the symbol
          // reads as dissolving into dust rather than fading under an effect.
          final particleProgress = ((_fadeController.value - 0.34) / 0.66)
              .clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              // Allow particles to fly past the cell bounds without being
              // clipped — the burst feels far more dramatic if sparks escape
              // the cell box and trail through the gap to the next column.
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (particleProgress > 0 && !isMultiplier)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _ParticleBurstPainter(
                        progress: particleProgress,
                        particles: _particles,
                        palette: _palette,
                      ),
                    ),
                  ),
                Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(scale: scale, child: child),
                ),
              ],
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Center(
            child: isMultiplier
                ? _FrozenBomb(
                    opacity: _imageOpacity,
                    itemH: widget.itemH,
                    multiplierValue: symbol?.multiplierValue ?? 5,
                  )
                : Image.asset(
                    widget.path,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.low,
                    gaplessPlayback: true,
                    cacheWidth: 256,
                    opacity: _imageOpacity,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ItemExplosionPopSound {
  static const _assetPath = 'audio/Items/Item_Explosion_Pop.wav';
  static const _popSpacing = Duration(milliseconds: 42);
  static const _maxQueuedPops = 6;
  static const _volume = 0.38;

  static Future<AudioPool>? _poolFuture;
  static int _queuedPops = 0;
  static bool _isDraining = false;

  static Future<void> play() {
    _queuedPops = math.min(_queuedPops + 1, _maxQueuedPops);
    if (!_isDraining) {
      _isDraining = true;
      unawaited(_drainQueue());
    }
    return Future.value();
  }

  static Future<void> _drainQueue() async {
    while (_queuedPops > 0) {
      _queuedPops--;
      await _playOne();
      if (_queuedPops > 0) {
        await Future.delayed(_popSpacing);
      }
    }
    _isDraining = false;
    if (_queuedPops > 0) {
      _isDraining = true;
      unawaited(_drainQueue());
    }
  }

  static Future<void> _playOne() async {
    try {
      final pool = await (_poolFuture ??= AudioPool.create(
        source: AssetSource(_assetPath),
        minPlayers: 3,
        maxPlayers: 8,
        playerMode: PlayerMode.lowLatency,
        audioContext: AppAudioContext.game,
      ));
      await pool.start(volume: _volume);
    } catch (_) {
      // Item pop audio should never interrupt the tumble animation.
    }
  }
}

/// Bomb sprite shown frozen on frame 0 in place of the multiplier face.
/// The animated detonation runs in [MultiplierBombAnimation] as a root
/// overlay when the win presentation reaches this cell, so this widget
/// only needs to render the static bomb body. Wrapped in [Opacity] so
/// the cell's existing fade-out path keeps working.
class _FrozenBomb extends StatelessWidget {
  final Animation<double> opacity;
  final double itemH;
  final int multiplierValue;
  const _FrozenBomb({
    required this.opacity,
    required this.itemH,
    required this.multiplierValue,
  });

  @override
  Widget build(BuildContext context) {
    // Static PNG snapshot of the bomb body — drops the per-frame Skia
    // path-replay cost of the full Lottie composition. The animated
    // detonation runs in [MultiplierBombAnimation] overlay; this cell's
    // PNG is hidden via [GameViewModel.clearedPositions] the moment that
    // overlay starts, so there is no overlap during the fuse phase.
    return AnimatedBuilder(
      animation: opacity,
      builder: (context, child) =>
          Opacity(opacity: opacity.value, child: child),
      // Render the Lottie in a 1.3x cell-sized box so the rope can
      // overflow into the row above (Clip.none lets it spill). The
      // bomb's own scale was counter-shrunk in the composition so the
      // visible bomb body stays the same size as before.
      child: Center(
        child: SizedBox(
          width: itemH * 1.3,
          height: itemH * 1.3,
          child: RepaintBoundary(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                Transform.scale(
                  scale: MultiplierLabel.bombScaleFor(multiplierValue),
                  child: Lottie.asset(
                    MultiplierBombAnimation.assetPath,
                    fit: BoxFit.contain,
                    animate: false,
                  ),
                ),
                // The bomb body sits ~22% below the Lottie box's
                // geometric centre. We wrap the 5x label in Align
                // (with the same y-bias) because Stack's `alignment`
                // is ignored when StackFit.expand gives non-positioned
                // children tight constraints.
                Align(
                  alignment: Alignment(
                    MultiplierLabel.labelXOffsetFor(multiplierValue),
                    0.22,
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 1.0,
                    heightFactor: 0.43,
                    child: MultiplierLabel(
                      value: multiplierValue,
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-symbol dust palette. Each symbol's sweep, sparkle, and spark
/// colours mirror its dominant on-asset hue so the win effect reads as
/// "this symbol popped" rather than as a generic tier-coloured flash.
class _GlowPalette {
  final List<Color> sweep;
  final Color sparkle;
  final Color particle;

  const _GlowPalette({
    required this.sweep,
    required this.sparkle,
    required this.particle,
  });

  static const _yellow = _GlowPalette(
    sweep: [
      Color(0xFFFFB300),
      Color(0xFFFFE082),
      Color(0xFFFFFFFF),
      Color(0xFFFFE082),
      Color(0xFFFFB300),
    ],
    sparkle: Color(0xFFFFF8E1),
    particle: Color(0xFFFFD54F),
  );

  static const _purple = _GlowPalette(
    sweep: [
      Color(0xFF6A1B9A),
      Color(0xFFCE93D8),
      Color(0xFFFFFFFF),
      Color(0xFFCE93D8),
      Color(0xFF6A1B9A),
    ],
    sparkle: Color(0xFFE1BEE7),
    particle: Color(0xFFBA68C8),
  );

  static const _green = _GlowPalette(
    sweep: [
      Color(0xFF2E7D32),
      Color(0xFFA5D6A7),
      Color(0xFFFFFFFF),
      Color(0xFFA5D6A7),
      Color(0xFF2E7D32),
    ],
    sparkle: Color(0xFFC8E6C9),
    particle: Color(0xFF66BB6A),
  );

  static const _orange = _GlowPalette(
    sweep: [
      Color(0xFFEF6C00),
      Color(0xFFFFB74D),
      Color(0xFFFFFFFF),
      Color(0xFFFFB74D),
      Color(0xFFEF6C00),
    ],
    sparkle: Color(0xFFFFE0B2),
    particle: Color(0xFFFFA726),
  );

  static const _red = _GlowPalette(
    sweep: [
      Color(0xFFB71C1C),
      Color(0xFFEF9A9A),
      Color(0xFFFFFFFF),
      Color(0xFFEF9A9A),
      Color(0xFFB71C1C),
    ],
    sparkle: Color(0xFFFFCDD2),
    particle: Color(0xFFEF5350),
  );

  static const _pink = _GlowPalette(
    sweep: [
      Color(0xFFAD1457),
      Color(0xFFF48FB1),
      Color(0xFFFFFFFF),
      Color(0xFFF48FB1),
      Color(0xFFAD1457),
    ],
    sparkle: Color(0xFFFCE4EC),
    particle: Color(0xFFF06292),
  );

  static const _cyan = _GlowPalette(
    sweep: [
      Color(0xFF006064),
      Color(0xFF80DEEA),
      Color(0xFFFFFFFF),
      Color(0xFF80DEEA),
      Color(0xFF006064),
    ],
    sparkle: Color(0xFFB2EBF2),
    particle: Color(0xFF4DD0E1),
  );

  static const _gold = _GlowPalette(
    sweep: [
      Color(0xFFFF6F00),
      Color(0xFFFFCA28),
      Color(0xFFFFFFFF),
      Color(0xFFFFCA28),
      Color(0xFFFF6F00),
    ],
    sparkle: Color(0xFFFFE082),
    particle: Color(0xFFFFB300),
  );

  static _GlowPalette forPath(String path) {
    final id = SymbolRegistry.byPath(path)?.id;
    switch (id) {
      case 'muz':
        return _yellow;
      case 'uzum':
        return _purple;
      case 'karpuz':
      case 'yesil_ayi':
        return _green;
      case 'seftali':
        return _orange;
      case 'elma':
      case 'cilek':
      case 'kalp':
        return _red;
      case 'pembe_ayi':
        return _pink;
      case 'cupcake':
        return _cyan;
      case 'multi_2x':
      case 'multi_3x':
      case 'multi_5x':
      case 'multi_10x':
      case 'multi_25x':
      case 'multi_50x':
      case 'multi_100x':
        return _gold;
      default:
        return _yellow;
    }
  }
}

/// One radiating gold spark. Direction + speed picked at construction time
/// so every cell burst has a distinct fan pattern.
class _Particle {
  final double originX;
  final double originY;
  final double angle;
  final double speed;
  final double size;
  final double startProgress;
  final double spin;
  final int colorIndex;

  const _Particle({
    required this.originX,
    required this.originY,
    required this.angle,
    required this.speed,
    required this.size,
    required this.startProgress,
    required this.spin,
    required this.colorIndex,
  });

  factory _Particle.random(math.Random rng) {
    final originAngle = rng.nextDouble() * 2 * math.pi;
    final originRadius = math.sqrt(rng.nextDouble());
    final originX = math.cos(originAngle) * originRadius;
    final originY = math.sin(originAngle) * originRadius;
    final outwardAngle = math.atan2(originY, originX);

    return _Particle(
      originX: originX,
      originY: originY,
      angle: outwardAngle + (rng.nextDouble() - 0.5) * 1.25,
      speed: 0.20 + rng.nextDouble() * 0.34,
      size: 1.1 + rng.nextDouble() * 2.2,
      startProgress: rng.nextDouble() * 0.18,
      spin: (rng.nextDouble() * 2 - 1) * math.pi * 1.7,
      colorIndex: rng.nextInt(5),
    );
  }
}

/// Paints the radiating spark burst. Each particle starts near the cell
/// centre, accelerates outward along its [angle], shrinks, and fades.
class _ParticleBurstPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;
  final _GlowPalette palette;

  _ParticleBurstPainter({
    required this.progress,
    required this.particles,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxDistance = math.max(size.width, size.height);
    final originRadius = math.min(size.width, size.height) * 0.24;

    for (final p in particles) {
      final localT = ((progress - p.startProgress) / (1.0 - p.startProgress))
          .clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final eased = Curves.easeOutCubic.transform(localT);
      final origin = Offset(
        center.dx + p.originX * originRadius,
        center.dy + p.originY * originRadius,
      );
      final distance = eased * p.speed * maxDistance * 0.58;
      final pos = Offset(
        origin.dx + math.cos(p.angle) * distance,
        origin.dy +
            math.sin(p.angle) * distance +
            eased * eased * size.height * 0.18,
      );
      final alpha = (1.0 - localT).clamp(0.0, 1.0);
      final radius = p.size * (1.0 - localT * 0.35);
      final color = _particleColor(p.colorIndex).withValues(alpha: alpha);

      final dustPaint = Paint()..color = color.withValues(alpha: alpha * 0.9);
      canvas.drawCircle(pos, radius * 0.55, dustPaint);

      if (p.colorIndex == 1 || p.colorIndex == 3) {
        final fleckPaint = Paint()
          ..color = color.withValues(alpha: alpha * 0.55);
        final offset = Offset(
          math.cos(p.angle + p.spin) * radius * 0.65,
          math.sin(p.angle + p.spin) * radius * 0.65,
        );
        canvas.drawCircle(pos + offset, radius * 0.28, fleckPaint);
      }
    }
  }

  Color _particleColor(int index) {
    if (index == 0) return palette.particle;
    if (index == 1) return palette.sparkle;
    return palette.sweep[index % palette.sweep.length];
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) =>
      old.progress != progress || old.palette != palette;
}
