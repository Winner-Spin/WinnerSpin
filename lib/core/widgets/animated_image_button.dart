import 'package:flutter/material.dart';

/// Custom Image Button with Scale Animation
class AnimatedImageButton extends StatefulWidget {
  final VoidCallback onTap;
  final String imagePath;
  final double width;
  final bool isStrikeThrough;

  const AnimatedImageButton({
    super.key,
    required this.onTap,
    required this.imagePath,
    required this.width,
    this.isStrikeThrough = false,
  });

  @override
  State<AnimatedImageButton> createState() => _AnimatedImageButtonState();
}

class _AnimatedImageButtonState extends State<AnimatedImageButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.90).animate(
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            Image.asset(
              widget.imagePath,
              width: widget.width,
              fit: BoxFit.contain,
            ),
            if (widget.isStrikeThrough)
              Transform.rotate(
                angle: -0.785, // -45 degrees
                child: Container(
                  width: widget.width * 0.8,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
