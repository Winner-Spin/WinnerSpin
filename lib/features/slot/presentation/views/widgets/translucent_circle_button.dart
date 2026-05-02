import 'package:flutter/material.dart';

/// Shared visual chrome for the small translucent circle buttons used in
/// the slot game (minus, plus, respin). Provides the press-scale gesture,
/// shadow, radial-gradient face, top-left specular highlight, and the
/// RepaintBoundary that isolates the cached layer from neighbour repaints.
///
/// The caller supplies the icon — fitted into a centered square sized at
/// 74% of the button's diameter to match the original button proportions.
class TranslucentCircleButton extends StatefulWidget {
  /// Outer diameter (also the hit-test area).
  final double size;

  /// Icon content placed in a centered square at 74% of [size].
  final Widget child;

  final VoidCallback? onTap;

  /// Drives the radial gradient's alpha range. Default 0.5 produces a
  /// translucent face (~45–56% alpha across the gradient stops).
  final double opacity;

  const TranslucentCircleButton({
    super.key,
    required this.size,
    required this.child,
    this.onTap,
    this.opacity = 0.5,
  });

  @override
  State<TranslucentCircleButton> createState() =>
      _TranslucentCircleButtonState();
}

class _TranslucentCircleButtonState extends State<TranslucentCircleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _press, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final op = widget.opacity.clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        // Layer-cache the heavy decoration (shadow blur + radial gradient
        // + highlight) so neighbour repaints in the parent Stack don't
        // re-rasterize this tree.
        child: RepaintBoundary(
          child: SizedBox(
            width: s,
            height: s,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: s,
                  height: s,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x661A1310),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF2B211B).withValues(alpha: op - 0.17),
                        const Color(0xFF120C09).withValues(alpha: op - 0.13),
                        Colors.black.withValues(alpha: op - 0.29),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: s * 0.20,
                  top: s * 0.16,
                  child: IgnorePointer(
                    child: Container(
                      width: s * 0.38,
                      height: s * 0.28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: s * 0.74,
                  height: s * 0.74,
                  child: widget.child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
