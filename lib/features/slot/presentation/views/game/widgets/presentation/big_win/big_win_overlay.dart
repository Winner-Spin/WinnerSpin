import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../../../../../core/audio/app_audio_context.dart';
import '../../../../../models/win_tier.dart';
import 'big_win_amount_banner.dart';
import 'big_win_coin_rain.dart';
import 'big_win_headline.dart';

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
  late final List<BigWinCoin> _coins;

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
          ((i + rng.nextDouble()) / 80) * bigWinCoinRainCycleProgress;
      return BigWinCoin(
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
                    painter: BigWinCoinsPainter(
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
                          child: BigWinHeadline(
                            tier: widget.tier,
                            cacheWidth: BigWinOverlay.headlineCacheWidth,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _amountPopScale,
                          builder: (ctx, child) => Transform.scale(
                            scale: _amountPopScale.value,
                            child: child,
                          ),
                          child: BigWinAmountBanner(
                            amount: widget.amount,
                            duration: _countDuration,
                            bannerAssetPath:
                                BigWinOverlay.amountBannerAssetPath,
                            bannerCacheWidth:
                                BigWinOverlay.amountBannerCacheWidth,
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
