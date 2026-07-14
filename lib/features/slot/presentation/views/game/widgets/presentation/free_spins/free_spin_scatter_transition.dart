import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FreeSpinScatterTransition extends StatefulWidget {
  const FreeSpinScatterTransition({super.key});

  static Future<ui.Image> precacheCupcakeImage() {
    return _FreeSpinScatterTransitionState.precacheCupcakeImage();
  }

  @override
  State<FreeSpinScatterTransition> createState() =>
      _FreeSpinScatterTransitionState();
}

class _FreeSpinScatterTransitionState extends State<FreeSpinScatterTransition>
    with SingleTickerProviderStateMixin {
  static const _cupcakeAssetPath =
      'lib/images/slot_main_screen/Items/cupCake.png';
  static const double _cupcakeCellSize = 0.255;
  static const double _cupcakeSizeVariation = 0.065;
  static const double _cupcakeHorizontalSpacing = 0.27;
  static const double _cupcakeVerticalSpacing = 0.245;
  static const double _cupcakeRowShift = 0.25;
  static const double _cupcakeEntranceDelay = 0.28;
  static ui.Image? _cachedCupcakeImage;
  static Future<ui.Image>? _cupcakeImageFuture;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  Size? _burstLayoutSize;
  late List<_CupcakeBurstParticle> _cupcakeParticles = const [];
  ui.Image? _cupcakeImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 27),
    ]).animate(_controller);
    _scale = Tween<double>(
      begin: 0.25,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _rotation = Tween<double>(
      begin: -0.16,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    unawaited(_resolveCupcakeImage());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static Future<ui.Image> precacheCupcakeImage() {
    final cached = _cachedCupcakeImage;
    if (cached != null) return Future.value(cached);
    return _cupcakeImageFuture ??= _loadCupcakeImage().then((image) {
      _cachedCupcakeImage = image;
      return image;
    });
  }

  static Future<ui.Image> _loadCupcakeImage() async {
    final data = await rootBundle.load(_cupcakeAssetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> _resolveCupcakeImage() async {
    final image = await precacheCupcakeImage();
    if (!mounted) return;
    setState(() => _cupcakeImage = image);
  }

  void _ensureCupcakeBurstLayout(Size size) {
    if (_burstLayoutSize == size) return;
    double noise(int seed) {
      final raw = math.sin(seed * 12.9898) * 43758.5453;
      return raw - raw.floorToDouble();
    }

    final particles = <_CupcakeBurstParticle>[];
    final horizontalSpacing = size.width * _cupcakeHorizontalSpacing;
    final verticalSpacing = size.width * _cupcakeVerticalSpacing;
    final columnCount = (size.width / horizontalSpacing).ceil() + 1;
    final rowCount = (size.height / verticalSpacing).ceil() + 1;
    final horizontalStart =
        (size.width - (columnCount - 1) * horizontalSpacing) / 2;
    final verticalStart = (size.height - (rowCount - 1) * verticalSpacing) / 2;

    var index = 0;
    for (var row = 0; row < rowCount; row++) {
      final rowShift =
          (row.isEven ? -_cupcakeRowShift : _cupcakeRowShift) *
          horizontalSpacing;
      final centerY = verticalStart + row * verticalSpacing;

      for (var column = 0; column < columnCount; column++) {
        final centerX = horizontalStart + column * horizontalSpacing + rowShift;
        final sizeVar =
            _cupcakeCellSize + noise(index * 19 + 11) * _cupcakeSizeVariation;
        final rotation = (noise(index * 23 + 13) - 0.5) * 1.8;
        final width = size.width * sizeVar;

        particles.add(
          _CupcakeBurstParticle(
            left: centerX - width / 2,
            top: centerY - width / 2,
            driftX: (noise(index * 31 + 17) - 0.5) * 95,
            driftY: -85 - noise(index * 37 + 19) * 95,
            rotation: rotation,
            delay: _cupcakeEntranceDelay,
            width: width,
          ),
        );
        index++;
      }
    }

    _burstLayoutSize = size;
    _cupcakeParticles = particles;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size =
              constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? constraints.biggest
              : MediaQuery.sizeOf(context);
          _ensureCupcakeBurstLayout(size);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _fade.value,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.38),
                  child: CustomPaint(
                    size: size,
                    painter: _CupcakeBurstPainter(
                      particles: _cupcakeParticles,
                      image: _cupcakeImage,
                      progress: _controller.value,
                      scale: _scale.value.clamp(0.9, 1.22),
                      rotation: _rotation.value,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CupcakeBurstParticle {
  final double left;
  final double top;
  final double driftX;
  final double driftY;
  final double rotation;
  final double delay;
  final double width;

  const _CupcakeBurstParticle({
    required this.left,
    required this.top,
    required this.driftX,
    required this.driftY,
    required this.rotation,
    required this.delay,
    required this.width,
  });
}

class _CupcakeBurstPainter extends CustomPainter {
  final List<_CupcakeBurstParticle> particles;
  final ui.Image? image;
  final double progress;
  final double scale;
  final double rotation;

  const _CupcakeBurstPainter({
    required this.particles,
    required this.image,
    required this.progress,
    required this.scale,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cupcake = image;
    if (cupcake == null) return;

    final source = Rect.fromLTWH(
      0,
      0,
      cupcake.width.toDouble(),
      cupcake.height.toDouble(),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    for (final particle in particles) {
      final localProgress = ((progress - particle.delay) / 0.52).clamp(
        0.0,
        1.0,
      );
      final pop = Curves.easeOutBack.transform(localProgress);
      final drift = Curves.easeOutCubic.transform(localProgress);
      final drawScale = (0.34 + pop * 0.84) * scale;
      final center = Offset(
        particle.left + particle.width / 2 + particle.driftX * (1 - drift),
        particle.top + particle.width / 2 + particle.driftY * (1 - drift),
      );
      final target = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.width,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.rotation + rotation);
      canvas.scale(drawScale);
      canvas.drawImageRect(cupcake, source, target, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CupcakeBurstPainter oldDelegate) {
    return oldDelegate.particles != particles ||
        oldDelegate.image != image ||
        oldDelegate.progress != progress ||
        oldDelegate.scale != scale ||
        oldDelegate.rotation != rotation;
  }
}
