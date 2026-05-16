import 'package:flutter/material.dart';

class StatusBand extends StatelessWidget {
  final Widget child;

  const StatusBand({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.58),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.22, 0.78, 1.0],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
