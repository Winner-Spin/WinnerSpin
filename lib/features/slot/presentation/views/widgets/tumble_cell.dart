import 'package:flutter/material.dart';

/// A single grid cell that supports two cascade-tumble effects independently
/// of the column-wide spin in [SlotReel]:
///   • Fade-out when [isFading] flips to true (matched symbol disappears).
///   • Drop-in from above when [path] changes (new symbol falls into place).
///
/// Used by [SlotReel] only in the static (post-drop-in) state. During the
/// initial reel spin, the column-wide drop-out / drop-in animation runs
/// instead.
class TumbleCell extends StatefulWidget {
  final String path;
  final bool isFading;
  final double itemH;

  const TumbleCell({
    super.key,
    required this.path,
    required this.isFading,
    required this.itemH,
  });

  @override
  State<TumbleCell> createState() => _TumbleCellState();
}

class _TumbleCellState extends State<TumbleCell>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _dropController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _dropAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _dropAnimation =
        CurvedAnimation(parent: _dropController, curve: Curves.easeOutCubic);

    // Settle in the resting state — no entry animation on first build,
    // because the column-level drop-in already covered initial display.
    _dropController.value = 1.0;
    _fadeController.value = widget.isFading ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(TumbleCell oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Path changed → new symbol falls in from above.
    // Also clear any leftover fade so the incoming symbol is fully opaque.
    if (widget.path != oldWidget.path) {
      _fadeController.value = 0.0;
      _dropController.forward(from: 0.0);
      return;
    }

    // Path unchanged: just toggle fade state.
    if (widget.isFading != oldWidget.isFading) {
      if (widget.isFading) {
        _fadeController.forward(from: 0.0);
      } else {
        _fadeController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _dropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_fadeAnimation, _dropAnimation]),
      builder: (context, child) {
        final dy = (1.0 - _dropAnimation.value) * -widget.itemH;
        final opacity = (1.0 - _fadeAnimation.value).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Opacity(
            opacity: opacity,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Image.asset(
          widget.path,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
