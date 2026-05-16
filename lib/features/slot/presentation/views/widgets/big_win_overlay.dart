import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/audio/app_audio_context.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../models/win_tier.dart';
import 'win_amount_counter.dart';

const double _coinRainCycleProgress = 0.78;

class BigWinOverlay extends StatefulWidget {
  static const amountBannerAssetPath =
      'lib/images/slot_main_screen/WIN_ARTICLES/WINBOX.png';
  static const headlineCacheWidth = 1280;
  static const amountBannerCacheWidth = 1024;

  final double amount;
  final WinTier tier;
  final Duration duration;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final VoidCallback onComplete;

  final bool instantAmount;

  const BigWinOverlay({
    super.key,
    required this.amount,
    required this.tier,
    required this.soundEnabled,
    required this.onComplete,
    this.vibrationEnabled = false,
    this.duration = const Duration(seconds: 12),
    this.instantAmount = false,
  });

  @override
  State<BigWinOverlay> createState() => _BigWinOverlayState();
}

class _BigWinOverlayState extends State<BigWinOverlay>
    with TickerProviderStateMixin {
  static const _celebrationSound = 'audio/Items/Win_Sounds.wav';

  late final AnimationController _ctrl;
  late final AudioPlayer _celebrationPlayer;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final List<_Coin> _coins;

  late final AnimationController _amountPopCtrl;
  late final Animation<double> _amountPopScale;
  bool _amountPopStarted = false;

  bool _amountSkipped = false;

  bool _completed = false;

  static const Duration _countDuration = Duration(seconds: 10);

  static const Duration _postCountHold = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _celebrationPlayer = AudioPlayer();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    const popInMs = 384.0;
    const breathPhaseMs = 576.0;
    final totalMs = widget.duration.inMilliseconds.toDouble();
    final breathPhaseCount = max(
      0,
      ((totalMs - popInMs) / breathPhaseMs).floor(),
    );
    final scaleItems = <TweenSequenceItem<double>>[
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: popInMs,
      ),
    ];
    for (var i = 0; i < breathPhaseCount; i++) {
      final grows = i.isEven;
      scaleItems.add(
        TweenSequenceItem(
          tween: Tween<double>(
            begin: grows ? 1.0 : 1.08,
            end: grows ? 1.08 : 1.0,
          ).chain(CurveTween(curve: Curves.easeInOut)),
          weight: breathPhaseMs,
        ),
      );
    }
    final scaleUsedMs = popInMs + breathPhaseCount * breathPhaseMs;
    final scaleRemainderMs = max(0.0, totalMs - scaleUsedMs);
    if (scaleRemainderMs > 0) {
      scaleItems.add(
        TweenSequenceItem(
          tween: ConstantTween<double>(breathPhaseCount.isEven ? 1.0 : 1.08),
          weight: scaleRemainderMs,
        ),
      );
    }
    _scaleAnim = TweenSequence<double>(scaleItems).animate(_ctrl);

    const fadeInMs = 256.0;
    const fadeOutMs = 480.0;
    final fadeHoldMs = max(0.0, totalMs - fadeInMs - fadeOutMs);
    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: fadeInMs,
      ),
      TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: fadeHoldMs),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: fadeOutMs,
      ),
    ]).animate(_ctrl);

    final rng = Random();

    _coins = List.generate(80, (i) {
      final startProgress =
          ((i + rng.nextDouble()) / 80) * _coinRainCycleProgress;
      return _Coin(
        x: rng.nextDouble(),
        startProgress: startProgress,
        fallDuration: 0.30 + rng.nextDouble() * 0.24,
        size: 14.0 + rng.nextDouble() * 10.0,
        sway: rng.nextDouble() * 30 - 15,
      );
    });

    if (widget.soundEnabled) {
      unawaited(_startCelebrationSound());
    }

    _ctrl.forward().then((_) {
      if (mounted) _completeOnce();
    });

    _amountPopCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _amountPopScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.18,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 13,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 30,
      ),
    ]).animate(_amountPopCtrl);

    Future.delayed(_countDuration, () {
      if (mounted) _startAmountPop();
    });

    if (widget.instantAmount) {
      _amountSkipped = true;
      _startAmountPop();
      Future.delayed(_postCountHold, () {
        if (mounted) _completeOnce();
      });
    }
  }

  void _startAmountPop() {
    if (_amountPopStarted) return;
    _amountPopStarted = true;
    _amountPopCtrl.forward();
  }

  void _completeOnce() {
    if (_completed) return;
    _completed = true;
    unawaited(_stopCelebrationSound());
    widget.onComplete();
  }

  void _handleTap() {
    if (_amountSkipped || _completed) return;
    setState(() => _amountSkipped = true);
    unawaited(_stopCelebrationSound());
    _startAmountPop();
    Future.delayed(_postCountHold, () {
      if (mounted) _completeOnce();
    });
  }

  @override
  void didUpdateWidget(BigWinOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.soundEnabled == oldWidget.soundEnabled) return;
    if (widget.soundEnabled) {
      unawaited(_startCelebrationSound());
    } else {
      unawaited(_stopCelebrationSound());
    }
  }

  Future<void> _startCelebrationSound() async {
    try {
      await _celebrationPlayer.setAudioContext(AppAudioContext.game);
      await _celebrationPlayer.setReleaseMode(ReleaseMode.stop);
      await _celebrationPlayer.play(AssetSource(_celebrationSound));
    } catch (_) {}
  }

  Future<void> _stopCelebrationSound() async {
    try {
      await _celebrationPlayer.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    unawaited(_stopCelebrationSound());
    unawaited(_celebrationPlayer.dispose());
    _ctrl.dispose();
    _amountPopCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => _handleTap(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, _) {
            return Opacity(
              opacity: _fadeAnim.value.clamp(0.0, 1.0),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.45)),
                  CustomPaint(
                    painter: _CoinsPainter(
                      coins: _coins,
                      progress:
                          _ctrl.value * widget.duration.inMilliseconds / 3200.0,
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.scale(
                          scale: _scaleAnim.value,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _StarsRow(),
                              const SizedBox(height: 8),
                              _TierHeadline(tier: widget.tier),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _amountPopScale,
                          builder: (ctx, child) => Transform.scale(
                            scale: _amountPopScale.value,
                            child: child,
                          ),
                          child: _AmountBanner(
                            amount: widget.amount,
                            duration: _countDuration,
                            skipCountUp: _amountSkipped,
                            vibrationEnabled: widget.vibrationEnabled,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StarsRow extends StatelessWidget {
  const _StarsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(
            Icons.star_rounded,
            size: 52,
            color: const Color(0xFFFFD700),
            shadows: [
              Shadow(
                color: const Color(0xFFFFA500).withValues(alpha: 0.7),
                blurRadius: 14,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _TierHeadline extends StatelessWidget {
  final WinTier tier;
  const _TierHeadline({required this.tier});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      tier.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      cacheWidth: BigWinOverlay.headlineCacheWidth,
    );
    final scale = (tier == WinTier.bigWin || tier == WinTier.sensationalWin)
        ? 1.7
        : 1.3;
    return SizedBox(
      width: 320,
      height: 170,
      child: Transform.scale(scale: scale, child: image),
    );
  }
}

class _AmountBanner extends StatelessWidget {
  final double amount;
  final Duration duration;
  final bool skipCountUp;
  final bool vibrationEnabled;

  static final TextStyle _amountStyle = GoogleFonts.outfit(
    color: Colors.white,
    fontSize: 38,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    decoration: TextDecoration.none,
    shadows: [
      Shadow(
        color: Colors.black.withValues(alpha: 0.45),
        offset: const Offset(0, 3),
        blurRadius: 6,
      ),
    ],
  );

  const _AmountBanner({
    required this.amount,
    required this.duration,
    this.skipCountUp = false,
    this.vibrationEnabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          BigWinOverlay.amountBannerAssetPath,
          width: 340,
          filterQuality: FilterQuality.medium,
          cacheWidth: BigWinOverlay.amountBannerCacheWidth,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: WinAmountCounter(
            from: 0,
            to: amount,
            duration: duration,
            forceComplete: skipCountUp,
            vibrationEnabled: vibrationEnabled,
            style: _amountStyle,
          ),
        ),
      ],
    );
  }
}

class _Coin {
  final double x;

  final double startProgress;

  final double fallDuration;

  final double size;

  final double sway;

  const _Coin({
    required this.x,
    required this.startProgress,
    required this.fallDuration,
    required this.size,
    required this.sway,
  });
}

class _CoinsPainter extends CustomPainter {
  final List<_Coin> coins;
  final double progress;

  _CoinsPainter({required this.coins, required this.progress});

  static const _rimDark = Color(0xFF8B5A00);
  static const _faceTop = Color(0xFFFFEB99);
  static const _faceBottom = Color(0xFFFFB627);
  static const _innerRing = Color(0xFFC8902B);
  static const _shineColor = Color(0xFFFFFDF0);
  static const _stampColor = Color(0xFFC8902B);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final cycleT = (progress + c.startProgress) % _coinRainCycleProgress;
      final localT = cycleT / c.fallDuration;
      if (localT > 1) continue;

      final cx = c.x * size.width + sin(localT * pi * 2) * c.sway;
      final cy = (-0.08 + 1.2 * localT) * size.height;

      final fadeIn = (localT * 6).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - localT) * 5).clamp(0.0, 1.0);
      final alpha = (fadeIn * fadeOut).clamp(0.0, 1.0);

      final r = c.size;
      final centre = Offset(cx, cy);

      canvas.drawCircle(
        centre,
        r,
        Paint()..color = _rimDark.withValues(alpha: alpha),
      );

      canvas.drawCircle(
        centre,
        r * 0.86,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _faceTop.withValues(alpha: alpha),
              _faceBottom.withValues(alpha: alpha),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: r * 0.86)),
      );

      canvas.drawCircle(
        centre,
        r * 0.74,
        Paint()
          ..color = _innerRing.withValues(alpha: alpha * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06,
      );

      final stampStyle = TextStyle(
        color: _stampColor.withValues(alpha: alpha * 0.9),
        fontSize: r * 1.25,
        fontWeight: FontWeight.w900,
        height: 1.0,
      );
      final stampSize = Size(r * 0.92, r * 1.30);
      canvas.save();
      canvas.translate(
        cx - stampSize.width / 2,
        cy - stampSize.height / 2 + 1.1,
      );
      MoneySymbolPainter(
        style: stampStyle,
        lineYOffset: 1.45,
        lineTopExtend: 0.9,
      ).paint(canvas, stampSize);
      canvas.restore();

      canvas.drawCircle(
        Offset(cx - r * 0.32, cy - r * 0.32),
        r * 0.22,
        Paint()..color = _shineColor.withValues(alpha: alpha * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CoinsPainter old) => old.progress != progress;
}
