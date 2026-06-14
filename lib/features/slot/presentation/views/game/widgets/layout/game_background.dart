import 'package:flutter/material.dart';

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
        final bgPath = isFreeSpinVisualMode()
            ? 'lib/images/slot_main_screen/freespin arka plan.png'
            : 'lib/images/slot_main_screen/nihai arka plan.png';
        return RepaintBoundary(
          child: Image.asset(
            bgPath,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.4),
            filterQuality: FilterQuality.low,
            cacheWidth: 1080,
          ),
        );
      },
    );
  }
}
