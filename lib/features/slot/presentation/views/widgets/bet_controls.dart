import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Row of [+ / current bet / -] controls.
class BetControls extends StatelessWidget {
  final double betAmount;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  const BetControls({
    super.key,
    required this.betAmount,
    required this.onIncrease,
    required this.onDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _BetCircleButton(
          icon: Icons.remove,
          onTap: onDecrease,
          enableLongPress: true,
        ),
        const SizedBox(width: 12),
        _BetDisplay(amount: betAmount),
        const SizedBox(width: 12),
        _BetCircleButton(
          icon: Icons.add,
          onTap: onIncrease,
          enableLongPress: false,
        ),
      ],
    );
  }
}

class _BetCircleButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enableLongPress;

  const _BetCircleButton({
    required this.icon,
    required this.onTap,
    this.enableLongPress = false,
  });

  @override
  State<_BetCircleButton> createState() => _BetCircleButtonState();
}

class _BetCircleButtonState extends State<_BetCircleButton> {
  Timer? _initialDelayTimer;
  Timer? _periodicTimer;

  void _startTimer() {
    widget.onTap(); // Tetiklemeyi anında yap
    if (!widget.enableLongPress) return;

    _initialDelayTimer = Timer(const Duration(milliseconds: 400), () {
      _periodicTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
        widget.onTap();
      });
    });
  }

  void _stopTimer() {
    _initialDelayTimer?.cancel();
    _periodicTimer?.cancel();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _startTimer(),
      onTapUp: (_) => _stopTimer(),
      onTapCancel: () => _stopTimer(),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.purple.shade400, Colors.deepPurple.shade600],
          ),
          border: Border.all(
            color: Colors.purple.shade200.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 22),
      ),
    );
  }
}

class _BetDisplay extends StatelessWidget {
  final double amount;

  const _BetDisplay({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.shade600.withValues(alpha: 0.85),
            Colors.deepPurple.shade800.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.purple.shade300.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            'BAHİS',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
