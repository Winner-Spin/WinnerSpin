import 'package:flutter/material.dart';

import '../../../../../core/format/money_format.dart';

/// Counts up to [to], smoothly re-animating from the currently
/// displayed value whenever [to] changes. Drives both the cascade's
/// live running-win read-out (target bumped per tumble) and the
/// post-cascade reveals (single fixed [to]). [from] is honoured on the
/// first build only — subsequent target changes chase from whatever
/// the counter is currently displaying, so the value never snaps back
/// to zero.
class WinAmountCounter extends StatefulWidget {
  final double from;
  final double to;
  final TextStyle style;
  final Duration duration;
  final Curve curve;

  /// When flipped true after construction, snaps the displayed value
  /// to [to] immediately and stops the running animation — used by
  /// the big-win overlay's tap-to-skip path so the player can dismiss
  /// the count-up without waiting out the full duration.
  final bool forceComplete;

  const WinAmountCounter({
    super.key,
    this.from = 0,
    required this.to,
    required this.style,
    this.duration = const Duration(milliseconds: 1100),
    this.curve = Curves.easeOut,
    this.forceComplete = false,
  });

  @override
  State<WinAmountCounter> createState() => _WinAmountCounterState();
}

class _WinAmountCounterState extends State<WinAmountCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _displayed = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: widget.from, end: widget.to).animate(
      CurvedAnimation(parent: _ctrl, curve: widget.curve),
    );
    _ctrl.addListener(_onTick);
    if (widget.forceComplete) {
      _displayed = widget.to;
    } else {
      _displayed = widget.from;
      if (widget.to != widget.from) _ctrl.forward();
    }
  }

  void _onTick() {
    setState(() {
      _displayed = _anim.value;
    });
  }

  @override
  void didUpdateWidget(covariant WinAmountCounter old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to) {
      _anim = Tween<double>(begin: _displayed, end: widget.to).animate(
        CurvedAnimation(parent: _ctrl, curve: widget.curve),
      );
      _ctrl
        ..duration = widget.duration
        ..forward(from: 0);
    }
    if (widget.forceComplete && !old.forceComplete) {
      _ctrl.stop();
      setState(() => _displayed = widget.to);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('₺${formatMoney(_displayed)}', style: widget.style);
  }
}
