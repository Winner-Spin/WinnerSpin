import 'package:flutter/material.dart';

class GameBottomGradientPanel extends StatelessWidget {
  const GameBottomGradientPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: 0.45),
            Colors.transparent,
          ],
          stops: const [0.0, 0.22, 0.78, 1.0],
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: child,
    );
  }
}
