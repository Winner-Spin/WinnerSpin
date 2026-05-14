import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Renders the multiplier badge (e.g. "2x", "10x", "50x") as a sprite,
/// choosing the asset based on the multiplier's actual value. Used both
/// on the resting bomb in the grid and on the bomb overlay during the
/// fuse + blast.
class MultiplierLabel extends StatelessWidget {
  final int value;
  final BoxFit fit;

  const MultiplierLabel({
    super.key,
    required this.value,
    this.fit = BoxFit.contain,
  });

  static const _basePath = 'lib/images/slot_main_screen/Items/';

  static const Map<int, String> _assets = {
    2: '${_basePath}2x.png',
    3: '${_basePath}3x.png',
    5: '${_basePath}5x.png',
    10: '${_basePath}10x.png',
    25: '${_basePath}25x.png',
    50: '${_basePath}50x.png',
    100: '${_basePath}100x.png',
  };

  static String assetPathFor(int value) => _assets[value] ?? _assets[5]!;

  static const Map<int, Size> _intrinsicSizes = {
    2: Size(1448, 929),
    3: Size(1161, 859),
    5: Size(724, 520),
    10: Size(724, 396),
    25: Size(724, 382),
    50: Size(1448, 847),
    100: Size(1448, 1086),
  };

  static const double _decodeOversample = 1.25;
  static const int _minCacheWidth = 96;

  /// Per-value bomb body scale. Higher multipliers get a slightly bigger
  /// bomb to telegraph their weight without changing the badge in front.
  static const Map<int, double> _bombScales = {
    2: 1.00,
    3: 1.04,
    5: 1.08,
    10: 1.14,
    25: 1.22,
    50: 1.30,
    100: 1.40,
  };

  static double bombScaleFor(int value) => _bombScales[value] ?? 1.0;

  /// Per-value extra label scale to compensate for sprite art that reads
  /// visually smaller than its peers.
  static const Map<int, double> _labelExtraScale = {
    2: 1.13,
    50: 1.42,
    100: 2.00,
  };

  static double labelScaleFor(int value) => _labelExtraScale[value] ?? 1.0;

  /// Per-value horizontal/vertical offset used by callers and the paint
  /// transform to nudge sprites whose visual centre doesn't sit at the
  /// canvas centre.
  static const double _defaultLabelXOffset = -0.12;
  static const double _defaultLabelYOffset = -0.04;

  static const Map<int, double> _labelXOffset = {2: _defaultLabelXOffset};

  static double labelXOffsetFor(int value) =>
      _labelXOffset[value] ?? _defaultLabelXOffset;

  static int? _cacheWidthFor({
    required int value,
    required double height,
    required double extraScale,
    required double devicePixelRatio,
  }) {
    final intrinsic = _intrinsicSizes[value];
    if (intrinsic == null || !height.isFinite || height <= 0) return null;

    final displayWidth = height * (intrinsic.width / intrinsic.height);
    final targetWidth =
        (displayWidth * extraScale * devicePixelRatio * _decodeOversample)
            .ceil();
    final minWidth = math.min(_minCacheWidth, intrinsic.width.toInt());

    return targetWidth.clamp(minWidth, intrinsic.width.toInt()).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final extra = labelScaleFor(value);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : constraints.biggest.shortestSide;
        final dx = height * labelXOffsetFor(value);
        final dy = height * _defaultLabelYOffset;
        final cacheWidth = _cacheWidthFor(
          value: value,
          height: height,
          extraScale: extra,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        );
        final image = Image.asset(
          assetPathFor(value),
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          cacheWidth: cacheWidth,
        );
        final scaled = extra == 1.0
            ? image
            : Transform.scale(scale: extra, child: image);
        return Transform.translate(offset: Offset(dx, dy), child: scaled);
      },
    );
  }
}
