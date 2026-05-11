import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/audio/app_audio_context.dart';
import 'win_amount_counter.dart';

const double _coinRainCycleProgress = 0.78;

/// Tiers of celebratory overlay, ordered from lightest threshold to
/// the game's theoretical max. Each tier carries its own headline
/// artwork and the bet-multiplier at which it kicks in.
enum WinTier {
  bigWin(
    threshold: 10,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/BIGWIN.png',
  ),
  megaWin(
    threshold: 25,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/MEGAWIN.png',
  ),
  superWin(
    threshold: 50,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/SUPERWIN.png',
  ),
  epicWin(
    threshold: 100,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/EPICWIN.png',
  ),
  sensationalWin(
    threshold: 250,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/SENSATIONALWIN.png',
  ),
  maxWin(
    threshold: 500,
    assetPath: 'lib/images/slot_main_screen/WIN_ARTICLES/MAXWIN.png',
  );

  const WinTier({required this.threshold, required this.assetPath});

  /// Bet multiplier at which the tier's overlay starts triggering.
  final double threshold;

  /// PNG asset of the tier's stylized headline artwork.
  final String assetPath;

  /// Highest tier the spin's bet-multiplier qualifies for, or null
  /// if the win didn't even clear the lowest tier.
  static WinTier? forMultiplier(double multiplier) {
    if (multiplier >= maxWin.threshold) return maxWin;
    if (multiplier >= sensationalWin.threshold) return sensationalWin;
    if (multiplier >= epicWin.threshold) return epicWin;
    if (multiplier >= superWin.threshold) return superWin;
    if (multiplier >= megaWin.threshold) return megaWin;
    if (multiplier >= bigWin.threshold) return bigWin;
    return null;
  }
}

/// Celebratory overlay that pops in once a spin clears the big-win
/// threshold. Renders 4 stars + the tier's headline artwork, a
/// WINBOX amount panel, and a field of drifting yellow sparkles.
/// Plays elastic-pop → hold → fade and self-removes via [onComplete].
class BigWinOverlay extends StatefulWidget {
  final double amount;
  final WinTier tier;
  final Duration duration;
  final bool soundEnabled;
  final VoidCallback onComplete;

  /// When true, the overlay opens with the count-up already settled at
  /// [amount] and runs the same shortened dismissal flow the tap path
  /// uses — added for the turbo speed level so big-win presentations
  /// stay compact when the player has chosen the fastest pacing.
  final bool instantAmount;

  const BigWinOverlay({
    super.key,
    required this.amount,
    required this.tier,
    required this.soundEnabled,
    required this.onComplete,
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

  // Drives the amount-banner pop sequence that fires once the count-up
  // settles — independent from the main timeline so a tap-driven skip
  // can run the pop immediately without disturbing the coin shower,
  // star pulse, or headline breathing.
  late final AnimationController _amountPopCtrl;
  late final Animation<double> _amountPopScale;
  bool _amountPopStarted = false;

  // Flipped true the moment the player taps anywhere on the overlay.
  // The amount banner snaps to the final value while the coin shower,
  // star pulse, headline breathing, and fade stay on their original
  // schedule — the tap only short-circuits the count-up readout.
  bool _amountSkipped = false;

  // Guards against [widget.onComplete] firing twice — once from the
  // tap-driven shortcut and once when the main controller's natural
  // forward run finishes.
  bool _completed = false;

  // Count-up duration the [_AmountBanner] runs for. The natural
  // post-count pop is scheduled against this value so it always
  // fires the instant the counter lands.
  static const Duration _countDuration = Duration(seconds: 10);

  // Hold the overlay sits after the count-up settles (or after a
  // tap-driven skip) before tearing itself down — gives the player a
  // beat to read the final amount and watch the banner pop.
  static const Duration _postCountHold = Duration(milliseconds: 2000);

  @override
  void initState() {
    super.initState();
    _celebrationPlayer = AudioPlayer();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    // Keep the original pop and breathing speed; the longer overlay
    // breathing cycles (1.0 ↔ 1.08) so the headline pulses gently
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

    // Jeton-style coins drop from above the screen and fall through.
    // Density now matches the reference shower — each coin's start
    // progress is spread across the bulk of the timeline so a fresh
    // wave is always entering as earlier ones leave the bottom.
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

    // Post-count pop runs whether the player waits the count-up out
    // or skips it via tap. Schedule the natural-flow trigger now so
    // the banner pops the instant the counter lands.
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
      // Turbo path: opening straight at the final amount, with the
      // same post-count hold the tap-to-skip flow uses so the
      // celebration still has a beat to read before tearing down.
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
    } catch (_) {
      // Audio failures should not interrupt the win celebration.
    }
  }

  Future<void> _stopCelebrationSound() async {
    try {
      await _celebrationPlayer.stop();
    } catch (_) {
      // The player may already be torn down while the overlay exits.
    }
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
                  // Soft dimming layer so the headline + amount panel
                  // read crisply against the candy backdrop without
                  // hiding the grid completely.
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
                        // Only the stars + headline pulse together;
                        // the amount panel below stays at a fixed
                        // size so the running counter stays steady.
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
    // Same vertical footprint for every tier so the surrounding
    // stars + amount banner stay at the same gaps. SENSATIONAL gets
    // a wider box because its single-line script would otherwise
    // read tiny next to the two-line tiers.
    final image = Image.asset(
      tier.assetPath,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    // Box stays at the same footprint for every tier so the
    // surrounding stars and amount banner keep their original gaps —
    // only the rendered output is scaled. BIG WIN and the wide-and-
    // short SENSATIONAL get the strongest boost; the mid-ladder tiers
    // get a softer 1.3x bump.
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

  const _AmountBanner({
    required this.amount,
    required this.duration,
    this.skipCountUp = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          'lib/images/slot_main_screen/WIN_ARTICLES/WINBOX.png',
          width: 340,
          filterQuality: FilterQuality.medium,
        ),
        Padding(
          // Inset clears the candy-stripe rounded ends of the panel
          // so the amount sits within the flat purple field.
          padding: const EdgeInsets.symmetric(horizontal: 56),
          child: WinAmountCounter(
            from: 0,
            to: amount,
            duration: duration,
            forceComplete: skipCountUp,
            style: GoogleFonts.outfit(
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
            ),
          ),
        ),
      ],
    );
  }
}

class _Coin {
  /// Horizontal column the coin falls in, normalized 0..1.
  final double x;

  /// Overlay-progress at which the coin enters the screen — staggers
  /// the field so coins arrive in waves rather than a single batch.
  final double startProgress;

  /// Fraction of overlay duration the coin spends crossing the
  /// screen — shorter values land it faster.
  final double fallDuration;

  /// On-screen radius in logical pixels.
  final double size;

  /// Horizontal sway amplitude in pixels — gives each coin a slight
  /// drift so the field isn't a rigid column rain.
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

  // Layered palette so each coin reads as a stamped jeton — outer
  // dark rim, brighter face, embossed centre symbol, soft highlight.
  static const _rimDark = Color(0xFF8B5A00);
  static const _faceTop = Color(0xFFFFEB99);
  static const _faceBottom = Color(0xFFFFB627);
  static const _innerRing = Color(0xFFC8902B);
  static const _shineColor = Color(0xFFFFFDF0);
  // Stamp sits in the same warm-gold family as the face, so the ₺
  // reads as embossed metal rather than a dark cut-out.
  static const _stampColor = Color(0xFFC8902B);

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in coins) {
      final cycleT = (progress + c.startProgress) % _coinRainCycleProgress;
      final localT = cycleT / c.fallDuration;
      if (localT > 1) continue;

      // Drop from above the top edge to below the bottom edge so
      // the entry / exit happen off-screen.
      final cx = c.x * size.width + sin(localT * pi * 2) * c.sway;
      final cy = (-0.08 + 1.2 * localT) * size.height;

      // Quick fade-in at the start, gentle fade-out near the end.
      final fadeIn = (localT * 6).clamp(0.0, 1.0);
      final fadeOut = ((1.0 - localT) * 5).clamp(0.0, 1.0);
      final alpha = (fadeIn * fadeOut).clamp(0.0, 1.0);

      final r = c.size;
      final centre = Offset(cx, cy);

      // Outer dark rim (the coin's edge).
      canvas.drawCircle(
        centre,
        r,
        Paint()..color = _rimDark.withValues(alpha: alpha),
      );

      // Inner face — gradient from cream-top to gold-bottom for a
      // subtle 3D feel.
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

      // Inner ring etched into the face for the stamped look.
      canvas.drawCircle(
        centre,
        r * 0.74,
        Paint()
          ..color = _innerRing.withValues(alpha: alpha * 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06,
      );

      // ₺ stamp at the centre. The TextPainter is rebuilt per coin
      // because each varies in radius — overhead is fine for the
      // BIG WIN scene's short lifetime.
      final tp = TextPainter(
        text: TextSpan(
          text: '₺',
          style: TextStyle(
            color: _stampColor.withValues(alpha: alpha * 0.9),
            fontSize: r * 1.25,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

      // Top-left specular highlight to read as a 3D coin.
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
