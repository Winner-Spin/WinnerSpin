import 'package:flutter/material.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';

class FlyingTumbleSprite extends StatefulWidget {
  final double amount;
  final Offset start;
  final Offset end;
  final TextStyle style;
  final Duration duration;
  final VoidCallback onComplete;

  const FlyingTumbleSprite({
    super.key,
    required this.amount,
    required this.start,
    required this.end,
    required this.style,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<FlyingTumbleSprite> createState() => _FlyingTumbleSpriteState();
}

class _FlyingTumbleSpriteState extends State<FlyingTumbleSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final raw = _ctrl.value;
        final t = Curves.easeInOutCubic.transform(raw);
        final pos = Offset.lerp(widget.start, widget.end, t)!;
        final scale = 1.0 - 0.25 * t;
        final opacity = raw < 0.85 ? 1.0 : (1.0 - raw) / 0.15;
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: IgnorePointer(
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Material(
                    type: MaterialType.transparency,
                    child: MoneyText(
                      text: formatMoney(widget.amount),
                      style: widget.style,
                      symbolOffset: const Offset(0, 1.5),
                      lineYOffset: 0.75,
                      lineLengthScale: 0.94,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
