import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../domain/models/cluster_win.dart';
import 'symbol_explosion_effect.dart';

class FloatingWinOverlay extends StatefulWidget {
  final List<ClusterWin> activeExplosions;
  final double gridWidth;
  final double gridHeight;

  const FloatingWinOverlay({
    super.key,
    required this.activeExplosions,
    required this.gridWidth,
    required this.gridHeight,
  });

  @override
  State<FloatingWinOverlay> createState() => _FloatingWinOverlayState();
}

class _FloatingWinOverlayState extends State<FloatingWinOverlay> {
  final List<_FloatingWinItem> _items = [];

  @override
  void didUpdateWidget(FloatingWinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if new explosions arrived (transition from empty to not empty means a new tumble step fade started)
    if (widget.activeExplosions.isNotEmpty && oldWidget.activeExplosions.isEmpty) {
      for (final win in widget.activeExplosions) {
        // Calculate center of the exploding cluster
        double sumC = 0;
        double sumR = 0;
        for (final pos in win.positions) {
          sumC += pos ~/ 100;
          sumR += pos % 100;
        }
        double avgC = sumC / win.positions.length;
        double avgR = sumR / win.positions.length;

        // Convert to absolute coordinates relative to the grid overlay
        double colWidth = widget.gridWidth / 6; // 6 columns
        double rowHeight = widget.gridHeight / 5; // 5 rows

        double centerX = (avgC * colWidth) + (colWidth / 2);
        double centerY = (avgR * rowHeight) + (rowHeight / 2);

        _items.add(_FloatingWinItem(
          winAmount: win.amount,
          startX: centerX,
          startY: centerY,
          key: UniqueKey(),
          onComplete: (item) {
            if (mounted) {
              setState(() {
                _items.remove(item);
              });
            }
          },
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: _items.map((item) => _FloatingWinWidget(item: item, key: item.key)).toList(),
    );
  }
}

class _FloatingWinItem {
  final double winAmount;
  final double startX;
  final double startY;
  final Key key;
  final void Function(_FloatingWinItem) onComplete;

  _FloatingWinItem({
    required this.winAmount,
    required this.startX,
    required this.startY,
    required this.key,
    required this.onComplete,
  });
}

class _FloatingWinWidget extends StatefulWidget {
  final _FloatingWinItem item;

  const _FloatingWinWidget({super.key, required this.item});

  @override
  State<_FloatingWinWidget> createState() => _FloatingWinWidgetState();
}

class _FloatingWinWidgetState extends State<_FloatingWinWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _yOffset;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    // 1.5 seconds for the entire float-up and fade-out effect
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _yOffset = Tween<double>(begin: 0, end: -100).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10), // Quick fade in
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50), // Hold
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40), // Fade out
    ]).animate(_controller);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 1.3), weight: 15), // Pop up
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 15), // Settle down
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 70), // Hold scale
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward().then((_) {
      widget.item.onComplete(widget.item);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Particle Explosion Burst
        Positioned(
          left: widget.item.startX - 100, // 200x200 explosion bounding box
          top: widget.item.startY - 100,
          child: SymbolExplosionEffect(
            active: true,
            size: 200,
          ),
        ),
        // Floating Win Text
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Positioned(
              left: widget.item.startX - 100, // Width 200, center is 100
              top: widget.item.startY - 30 + _yOffset.value, // Height ~60
              child: Opacity(
                opacity: _opacity.value,
                child: Transform.scale(
                  scale: _scale.value,
                  child: SizedBox(
                    width: 200,
                    child: Center(
                      child: Text(
                        '₺${widget.item.winAmount.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFFD54F), // Gates of Olympus Gold
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            // Thick dark outline
                            const Shadow(color: Colors.black87, offset: Offset(0, 3), blurRadius: 2),
                            const Shadow(color: Colors.black87, offset: Offset(0, -3), blurRadius: 2),
                            const Shadow(color: Colors.black87, offset: Offset(3, 0), blurRadius: 2),
                            const Shadow(color: Colors.black87, offset: Offset(-3, 0), blurRadius: 2),
                            const Shadow(color: Colors.black87, offset: Offset(2, 2), blurRadius: 2),
                            const Shadow(color: Colors.black87, offset: Offset(-2, -2), blurRadius: 2),
                            // Golden glow
                            Shadow(color: Colors.orange.shade900, offset: const Offset(0, 6), blurRadius: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
