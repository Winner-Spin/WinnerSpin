import 'package:flutter/material.dart';

import '../../../../../models/win_tier.dart';

class BigWinHeadline extends StatelessWidget {
  const BigWinHeadline({
    super.key,
    required this.tier,
    required this.imageProvider,
  });

  final WinTier tier;
  final ImageProvider imageProvider;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BigWinStarsRow(),
        const SizedBox(height: 8),
        BigWinTierHeadline(imageProvider: imageProvider, tier: tier),
      ],
    );
  }
}

class BigWinStarsRow extends StatelessWidget {
  const BigWinStarsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: BigWinStar(index: i),
        );
      }),
    );
  }
}

class BigWinStar extends StatelessWidget {
  const BigWinStar({super.key, required this.index});

  static const color = Color(0xFFFFD700);

  final int index;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: 52,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.star_rounded,
              size: 52,
              color: Colors.transparent,
              shadows: [
                Shadow(
                  color: const Color(0xFFFFA500).withValues(alpha: 0.7),
                  blurRadius: 14,
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
            Icon(
              Icons.star_rounded,
              key: ValueKey('big-win-star-foreground-$index'),
              size: 52,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class BigWinTierHeadline extends StatelessWidget {
  const BigWinTierHeadline({
    super.key,
    required this.tier,
    required this.imageProvider,
  });

  final WinTier tier;
  final ImageProvider imageProvider;

  @override
  Widget build(BuildContext context) {
    final image = Image(
      image: imageProvider,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    final scale = (tier == WinTier.bigWin || tier == WinTier.sensationalWin)
        ? 1.7
        : 1.3;
    return SizedBox(
      width: 320,
      height: 170,
      child: Transform.scale(scale: scale, child: image),
    );
  }
}
