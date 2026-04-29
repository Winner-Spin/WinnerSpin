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
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.grey.shade600, Colors.grey.shade600, Colors.grey.shade700],
                    stops: const [0.0, 0.4, 1.0],
                  )
                : isAuto
                    ? const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFFCC80), // Bright orange top highlight
                          Color(0xFFFF9800), // Main orange
                          Color(0xFFE65100), // Darker orange bottom
                        ],
                        stops: [0.0, 0.4, 1.0],
                      )
                    : const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFFFF8A80), // Bright red top highlight
                          Color(0xFFE53935), // Main red
                          Color(0xFFB71C1C), // Darker red bottom
                        ],
                        stops: [0.0, 0.4, 1.0],
                      ),
            border: Border.all(
              color: disabled && !isAuto
                  ? Colors.grey.shade400
                  : isAuto
                      ? const Color(0xFFFFE0B2).withValues(alpha: 0.6)
                      : const Color(0xFFFFCDD2).withValues(alpha: 0.6), // Inner red reflection
              width: 1.5,
            ),
            boxShadow: disabled && !isAuto
                ? []
                : [
                    BoxShadow(
                      color: isAuto
                          ? const Color(0xFFFF9800).withValues(alpha: 0.5)
                          : const Color(0xFFE53935).withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: isAuto
                          ? const Color(0xFFBF360C)
                          : const Color(0xFF880E4F), // Outer darker rim shadow
                      blurRadius: 0,
                      spreadRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Center(
            child: Icon(
              Icons.loop, // Döngü simgesi
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}
