import 'package:flutter/material.dart';

import '../../../../services/game_background_image_provider.dart';

class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.listenable,
    required this.isFreeSpinVisualMode,
  });

  final Listenable listenable;
  final bool Function() isFreeSpinVisualMode;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final imageProvider = GameBackgroundImageProvider.resolve(
          context,
          isFreeSpin: isFreeSpinVisualMode(),
        );
        return RepaintBoundary(
          child: Image(
            image: imageProvider,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.4),
            filterQuality: FilterQuality.medium,
          ),
        );
      },
    );
  }
}
