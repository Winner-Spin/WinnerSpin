import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../audio/item_explosion_pop_sound.dart';
import '../../../../../domain/enums/symbol_tier.dart';
import '../../../../../domain/models/symbol_registry.dart';
import 'tumble_frozen_multiplier_bomb.dart';
import 'tumble_glow_palette.dart';
import 'tumble_particle_burst.dart';

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

  late List<TumbleParticle> _particles;
  late TumbleGlowPalette _palette;

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

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.36, 0.52, curve: Curves.easeOut),
    );
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
    _palette = TumbleGlowPalette.forPath(widget.path);

    _dropController.value = 1.0;

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
      _palette = TumbleGlowPalette.forPath(widget.path);
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

  List<TumbleParticle> _generateParticles() {
    final rng = math.Random();
    return List.generate(90, (_) => TumbleParticle.random(rng));
  }

  void _playPopSound() {
    if (!widget.soundEnabled) return;
    unawaited(ItemExplosionPopSound.play());
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
          final particleProgress = ((_fadeController.value - 0.34) / 0.66)
              .clamp(0.0, 1.0);

          return Transform.translate(
            offset: Offset(0, dy),
            child: Stack(
              clipBehavior: Clip.none,
              fit: StackFit.expand,
              children: [
                if (particleProgress > 0 && !isMultiplier)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: TumbleParticleBurstPainter(
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
                ? TumbleFrozenMultiplierBomb(
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
