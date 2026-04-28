import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The big SPIN call-to-action. Stateful so it owns its own press-down
/// scale animation. Disabled visual is shown when [busy] is true or when
/// [affordable] is false.
class SpinButton extends StatefulWidget {
  final bool busy;
  final bool affordable;
  final double width;
  final VoidCallback onPressed;

  const SpinButton({
    super.key,
    required this.busy,
    required this.affordable,
    required this.width,
    required this.onPressed,
  });

  @override
  State<SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<SpinButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _disabled => widget.busy || !widget.affordable;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: _disabled
                ? LinearGradient(
                    colors: [Colors.grey.shade600, Colors.grey.shade700],
                  )
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green.shade400,
                      Colors.green.shade600,
                      Colors.green.shade800,
                    ],
                  ),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: widget.busy
                  ? Colors.grey.shade400
                  : Colors.greenAccent.shade200.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.busy ? Colors.grey : Colors.green)
                    .withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: (widget.busy ? Colors.grey : Colors.greenAccent)
                    .withValues(alpha: 0.2),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(child: _label()),
        ),
      ),
    );
  }

  Widget _label() {
    if (widget.busy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white.withValues(alpha: 0.8),
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Dönüyor...',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }
    return Text(
      '🎰  SPIN',
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: 3,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.4),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
