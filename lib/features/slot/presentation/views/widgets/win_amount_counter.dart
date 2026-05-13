import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';

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
  final bool vibrationEnabled;

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
    this.vibrationEnabled = false,
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
  double _lastHapticValue = 0;
  DateTime _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(
      begin: widget.from,
      end: widget.to,
    ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
    _ctrl.addListener(_onTick);
    if (widget.forceComplete) {
      _displayed = widget.to;
    } else {
      _displayed = widget.from;
      if (widget.to != widget.from) _ctrl.forward();
    }
  }

  void _onTick() {
    final next = _anim.value;
    _maybeHapticTick(next);
    setState(() {
      _displayed = next;
    });
  }

  void _maybeHapticTick(double next) {
    if (!widget.vibrationEnabled || next <= _lastHapticValue) return;
    final now = DateTime.now();
    if (now.difference(_lastHapticAt) < const Duration(milliseconds: 120)) {
      return;
    }
    _lastHapticAt = now;
    _lastHapticValue = next;
    HapticFeedback.selectionClick();
  }

  @override
  void didUpdateWidget(covariant WinAmountCounter old) {
    super.didUpdateWidget(old);
    if (old.to != widget.to) {
      _lastHapticValue = _displayed;
      _lastHapticAt = DateTime.fromMillisecondsSinceEpoch(0);
      _anim = Tween<double>(
        begin: _displayed,
        end: widget.to,
      ).animate(CurvedAnimation(parent: _ctrl, curve: widget.curve));
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
    return MoneyText(
      text: formatMoney(_displayed),
      style: widget.style,
      symbolOffset: const Offset(0, 1.5),
      lineYOffset: 0.75,
      lineLengthScale: 0.94,
      lineTopExtend: 0.9,
    );
  }
}
