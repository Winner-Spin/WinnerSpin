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
          enableLongPress: true,
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
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFE1BEE7), // Bright purple highlight
              Color(0xFFAB47BC), // Main purple
              Color(0xFF6A1B9A), // Dark purple
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          border: Border.all(
            color: const Color(0xFFF3E5F5).withValues(alpha: 0.6), // Inner reflection
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAB47BC).withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
            const BoxShadow(
              color: Color(0xFF4A148C), // Outer rim shadow
              blurRadius: 0,
              spreadRadius: 1,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Icon(widget.icon, color: Colors.white, size: 22, shadows: const [
          Shadow(color: Color(0xFF311B92), offset: Offset(0, 1), blurRadius: 1),
        ]),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFCE93D8), // Bright purple highlight
            Color(0xFF8E24AA), // Main purple
            Color(0xFF4A148C), // Dark purple
          ],
          stops: [0.0, 0.4, 1.0],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE1BEE7).withValues(alpha: 0.6), // Inner reflection
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E24AA).withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          const BoxShadow(
            color: Color(0xFF311B92), // Outer rim shadow
            blurRadius: 0,
            spreadRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'BAHİS',
            style: GoogleFonts.outfit(
              color: const Color(0xFFF3E5F5),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
              shadows: const [
                Shadow(color: Color(0xFF311B92), offset: Offset(0, 1), blurRadius: 1),
              ],
            ),
          ),
          Text(
            '₺${amount.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: const [
                Shadow(color: Color(0xFF311B92), offset: Offset(0, 1.5), blurRadius: 1),
                Shadow(color: Color(0xFF311B92), offset: Offset(0, -1), blurRadius: 1),
                Shadow(color: Color(0xFF311B92), offset: Offset(1, 0), blurRadius: 1),
                Shadow(color: Color(0xFF311B92), offset: Offset(-1, 0), blurRadius: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
