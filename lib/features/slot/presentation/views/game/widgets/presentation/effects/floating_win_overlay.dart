import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../../../../../core/widgets/money_text.dart';
import '../../../../../../domain/models/cluster_win.dart';

class FloatingWinOverlay extends StatefulWidget {
  final List<ClusterWin> activeExplosions;
  final double gridWidth;
  final double gridHeight;
  final int speedMultiplier;

  const FloatingWinOverlay({
    super.key,
    required this.activeExplosions,
    required this.gridWidth,
    required this.gridHeight,
    this.speedMultiplier = 1,
  });

  @override
  State<FloatingWinOverlay> createState() => _FloatingWinOverlayState();
}

class _FloatingWinOverlayState extends State<FloatingWinOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  final List<_WinEffect> _effects = [];
  final Random _rng = Random();

  static final TextStyle _baseTextStyle = GoogleFonts.outfit(
    color: const Color(0xFFFFD54F),
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.5,
  );
  static final RegExp _trailingZeroPattern = RegExp(r'\.0$');

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
  }

  @override
  void didUpdateWidget(FloatingWinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.activeExplosions.isNotEmpty &&
        oldWidget.activeExplosions.isEmpty) {
      final int delayMs = (300 ~/ widget.speedMultiplier).clamp(80, 300);
      final explosions = List.of(widget.activeExplosions);
      final gridW = widget.gridWidth;
      final gridH = widget.gridHeight;
      final speed = widget.speedMultiplier;

      Future.delayed(Duration(milliseconds: delayMs), () {
        if (!mounted) return;
        _spawnEffects(explosions, gridW, gridH, speed);
      });
    }
  }

  void _spawnEffects(
    List<ClusterWin> wins,
    double gridW,
    double gridH,
    int speed,
  ) {
    for (final win in wins) {
      double sumC = 0, sumR = 0;
      for (final pos in win.positions) {
        sumC += pos ~/ 100;
        sumR += pos % 100;
      }
      final avgC = sumC / win.positions.length;
      final avgR = sumR / win.positions.length;

      final colWidth = gridW / 6;
      final rowHeight = gridH / 5;
      final cx = (avgC * colWidth) + (colWidth / 2);
      final cy = (avgR * rowHeight) + (rowHeight / 2);

      final particles = <_Particle>[];
      for (int i = 0; i < 30; i++) {
        final angle = _rng.nextDouble() * 2 * pi;
        final v = (_rng.nextDouble() * 2.5 + 0.8) * speed;
        particles.add(
          _Particle(
            vx: cos(angle) * v,
            vy: sin(angle) * v,
            size: _rng.nextDouble() * 5 + 2,
            color: _rng.nextBool()
                ? const Color(0xFFFFFF00)
                : const Color(0xFFFFAB40),
          ),
        );
      }

      final durationMs = (1200 ~/ speed).clamp(350, 1200);
      _effects.add(
        _WinEffect(
          cx: cx,
          cy: cy,
          amountText: _formatAmount(win.amount),
          particles: particles,
          totalMs: durationMs,
          startMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    if (!_ticker.isAnimating) _ticker.repeat();
  }

  void _tick() {
    if (_effects.isEmpty) {
      _ticker.stop();
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _effects.removeWhere((e) {
      final elapsed = nowMs - e.startMs;
      return elapsed > e.totalMs;
    });
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(1).replaceAll(_trailingZeroPattern, '');
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        if (_effects.isEmpty) return const SizedBox.shrink();
        return CustomPaint(
          size: Size(widget.gridWidth, widget.gridHeight),
          painter: _EffectPainter(effects: _effects, style: _baseTextStyle),
        );
      },
    );
  }
}

class _Particle {
  final double vx, vy, size;
  final Color color;
  const _Particle({
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
  });
}

class _WinEffect {
  final double cx, cy;
  final String amountText;
  final List<_Particle> particles;
  final int totalMs;
  final int startMs;

  const _WinEffect({
    required this.cx,
    required this.cy,
    required this.amountText,
    required this.particles,
    required this.totalMs,
    required this.startMs,
  });
}

class _EffectPainter extends CustomPainter {
  final List<_WinEffect> effects;
  final TextStyle style;

  _EffectPainter({required this.effects, required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    for (final e in effects) {
      final elapsed = nowMs - e.startMs;
      final t = (elapsed / e.totalMs).clamp(0.0, 1.0);
      final life = 1.0 - t;

      final pt = Curves.easeOutCubic.transform(t);
      for (final p in e.particles) {
        final px = e.cx + p.vx * pt * 14;
        final py = e.cy + p.vy * pt * 14 + pt * pt * 30;

        final alpha = (life * 0.9).clamp(0.0, 1.0);
        final paint = Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), p.size * life, paint);

        final glow = Paint()
          ..color = p.color.withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(px, py), p.size * 2 * life, glow);
      }

      final textT = Curves.easeOutCubic.transform(t);
      final textY = e.cy - 20 - textT * 60; // float upward
      final textOpacity = life.clamp(0.0, 1.0);

      // Scale pop: 0.5 → 1.2 → 1.0
      double scale;
      if (t < 0.1) {
        scale = 0.5 + (t / 0.1) * 0.7; // 0.5 → 1.2
      } else if (t < 0.2) {
        scale = 1.2 - ((t - 0.1) / 0.1) * 0.2; // 1.2 → 1.0
      } else {
        scale = 1.0;
      }

      final fontSize = (style.fontSize ?? 28) * scale;
      final symbolSize = Size(fontSize * 0.74, fontSize * 1.04);
      final symbolSpacing = 1.5 * scale;

      final strokeStyle = style.copyWith(
        fontSize: fontSize,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0
          ..strokeJoin = StrokeJoin.round
          ..color = Colors.black.withValues(alpha: textOpacity * 0.85),
      );

      final fillStyle = style.copyWith(
        fontSize: fontSize,
        color: style.color?.withValues(alpha: textOpacity),
        shadows: [
          Shadow(
            color: Colors.orange.shade900.withValues(alpha: textOpacity * 0.7),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      );

      final strokeTp = TextPainter(
        text: TextSpan(text: e.amountText, style: strokeStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final fillTp = TextPainter(
        text: TextSpan(text: e.amountText, style: fillStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final contentWidth = symbolSize.width + symbolSpacing + strokeTp.width;
      final startX = e.cx - contentWidth / 2;
      final symbolY = textY + (strokeTp.height - symbolSize.height) / 2 + 1.1;
      final textX = startX + symbolSize.width + symbolSpacing;

      canvas.save();
      canvas.translate(startX, symbolY);
      MoneySymbolPainter(
        style: strokeStyle,
        lineYOffset: 1.45,
        lineTopExtend: 0.9,
      ).paint(canvas, symbolSize);
      canvas.restore();

      canvas.save();
      canvas.translate(startX, symbolY);
      MoneySymbolPainter(
        style: fillStyle.copyWith(shadows: const []),
        lineYOffset: 1.45,
        lineTopExtend: 0.9,
      ).paint(canvas, symbolSize);
      canvas.restore();

      strokeTp.paint(canvas, Offset(textX, textY));
      fillTp.paint(canvas, Offset(textX, textY));
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter old) => true;
}
