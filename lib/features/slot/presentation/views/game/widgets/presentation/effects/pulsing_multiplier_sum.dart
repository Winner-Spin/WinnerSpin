import 'package:flutter/material.dart';

class PulsingMultiplierSum extends StatefulWidget {
  final int value;
  final TextStyle style;

  const PulsingMultiplierSum({
    super.key,
    required this.value,
    required this.style,
  });

  @override
  State<PulsingMultiplierSum> createState() => _PulsingMultiplierSumState();
}

class _PulsingMultiplierSumState extends State<PulsingMultiplierSum>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 380);

  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: _pulseDuration);
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant PulsingMultiplierSum old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) => Transform.scale(
        scale: _scale.value,
        alignment: Alignment.center,
        child: Text('${widget.value}', style: widget.style),
      ),
    );
  }
}
