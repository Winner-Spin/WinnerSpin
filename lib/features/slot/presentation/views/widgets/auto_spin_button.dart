import 'package:flutter/material.dart';

/// A button that toggles auto-spin mode. It enlarges when held down
/// and has a loop design to indicate infinite spins.
class AutoSpinButton extends StatefulWidget {
  final bool isActive;
  final bool disabled;
  final VoidCallback onPressed;

  const AutoSpinButton({
    super.key,
    required this.isActive,
    required this.disabled,
    required this.onPressed,
  });

  @override
  State<AutoSpinButton> createState() => _AutoSpinButtonState();
}

class _AutoSpinButtonState extends State<AutoSpinButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    // Büyüme animasyonu: 1.0'dan 1.1'e
    _scale = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isAuto = widget.isActive;
    final bool disabled = widget.disabled;

    return GestureDetector(
      onTapDown: (_) {
        if (!disabled || isAuto) _controller.forward();
      },
      onTapUp: (_) {
        if (!disabled || isAuto) {
          _controller.reverse();
          widget.onPressed();
        }
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: disabled && !isAuto
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isAuto
                        ? [Colors.orange.shade400, Colors.deepOrange.shade600]
                        : [
                            Colors.redAccent.shade200,
                            Colors.red.shade700,
                          ],
                  ),
            border: Border.all(
              color: disabled && !isAuto
                  ? Colors.grey.shade400
                  : isAuto
                      ? Colors.orangeAccent.shade200.withValues(alpha: 0.8)
                      : Colors.redAccent.shade100.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: disabled && !isAuto
                ? []
                : isAuto 
                    ? [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
          ),
          child: Center(
            child: Icon(
              Icons.autorenew, // Döngü simgesi
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
