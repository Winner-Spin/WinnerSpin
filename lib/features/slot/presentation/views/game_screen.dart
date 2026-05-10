import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';

import '../../domain/models/cluster_win.dart';
import '../../domain/models/symbol_registry.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/buy_feature_button.dart';
import 'widgets/double_chance_button.dart';
import 'widgets/slot_reel.dart';
import 'widgets/respin_button.dart';
import 'widgets/minus_button.dart';
import 'widgets/plus_button.dart';
import 'widgets/auto_spin_button.dart';
import 'widgets/info_button.dart';
import 'widgets/settings_button.dart';
import 'widgets/speed_button.dart';
import 'widgets/big_win_overlay.dart';
import 'widgets/floating_win_overlay.dart';
import 'widgets/win_amount_counter.dart';
import 'widgets/win_presentation.dart';
import 'widgets/win_presentation_controller.dart';
import '../../../auth/presentation/views/login_screen.dart';
import 'system_settings_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameViewModel _viewModel = GameViewModel();

  // Drives the multiplier collect sequence. Lifted into the screen
  // state so the FS-mode strip can split the presentation across the
  // top Kazanç readout and the middle tumble-win counter.
  final WinPresentationController _winCtrl = WinPresentationController();

  // Flight target for multiplier collect animations — bombs land on
  // the middle "TUMBLE WIN" counter rather than on a formula bar.
  final GlobalKey _tumbleWinAnchorKey = GlobalKey();

  // Last-popped cluster shown on the FS-mode bottom info band. Held
  // across empty windows between tumbles so the cluster line keeps
  // reading until the next reel kicks off; cleared the moment a new
  // spin starts.
  ClusterWin? _lingeringCluster;
  bool _wasBusy = false;

  // FS-round running total. Accumulates each spin's awarded win so
  // the top Kazanç readout climbs through the round instead of
  // resetting to zero on every new reel.
  double _fsAccumulatedWin = 0;
  double _lastSeenLastWin = 0;
  bool _wasInFs = false;

  // Spin total awaiting the visual hand-off into the top Kazanç. We
  // hold this through the multiplier collect so the round total only
  // climbs after the middle TUMBLE WIN has fully resolved at its
  // final amount.
  double _pendingFsSpinWin = 0;
  WinPresentationPhase _lastWinCtrlPhase = WinPresentationPhase.idle;

  // Anchor for the running Kazanç readout — the flying tumble sprite
  // aims here so the value lands on top of the round total.
  final GlobalKey _kazancAnchorKey = GlobalKey();

  // Page-local overlay that hosts cinematic effects (bomb explosions,
  // multiplier flights, big-win celebration). Routes pushed by
  // `showGeneralDialog` go to the root navigator above this layer, so
  // panels like Settings sit on top of any in-flight animation.
  final GlobalKey<OverlayState> _stageOverlayKey = GlobalKey<OverlayState>();

  // True while the tumble-win sprite is in flight toward the Kazanç
  // readout. The middle band drops to ₺0 for the duration so the
  // value visually leaves TUMBLE WIN as it arrives at Kazanç. Once
  // the sprite lands the flag flips back, restoring the multiplied
  // total in the middle so the player still sees the spin's win
  // sitting there.
  bool _isFlyingTumble = false;

  // Normal-mode lastWin snapshot — used to detect 0 → positive
  // transitions for the big-win trigger when FS isn't active.
  double _lastSeenLastWinNormal = 0;

  // True after [_maybeShowBigWin] has actually mounted the overlay
  // for the current spin — the FS hand-off skips the flying sprite
  // when this is set so the celebration carries the win to Kazanç
  // on its own. Resets at the start of every spin.
  bool _bigWinShownThisSpin = false;
  OverlayEntry? _bigWinEntry;

  // Hot-path text styles resolved once — Google Fonts lookups inside
  // the status text and bottom panel rebuilds were repeating per spin.
  late final TextStyle _statusBaseStyle;
  late final TextStyle _statusKazancStyle;
  late final TextStyle _statusInsufficientStyle;
  late final TextStyle _bottomLabelStyle;
  late final TextStyle _bottomValueStyle;
  late final TextStyle _bottomClockStyle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModelChange);
    // The ViewModel itself doesn't notify after `awardWin` — that
    // path only fires on the balance controller. Listen there too so
    // the lastWin → FS-accumulator hand-off doesn't get missed.
    _viewModel.balanceCtrl.addListener(_onViewModelChange);
    _viewModel.gridCtrl.addListener(_onViewModelChange);
    _winCtrl.addListener(_onWinCtrlChange);
    _viewModel.fetchUserData();

    // Pre-decode symbol assets at the cell-sized cache width so the
    // first appearance of each symbol doesn't block the main thread.
    // The free-spin backdrop is also pre-decoded so the first FS trigger
    // doesn't stall the swap.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final sym in SymbolRegistry.all) {
        precacheImage(
          ResizeImage(AssetImage(sym.assetPath), width: 256),
          context,
        );
      }
      precacheImage(
        const AssetImage('lib/images/slot_main_screen/freespin arka plan.png'),
        context,
      );
    });

    final softShadow = [
      Shadow(
        color: Colors.black.withValues(alpha: 0.60),
        offset: const Offset(0, 1),
        blurRadius: 1.2,
      ),
    ];

    _statusBaseStyle = GoogleFonts.anton(
      color: Colors.white.withValues(alpha: 0.97),
      fontSize: 20,
      letterSpacing: 0.8,
      height: 1.0,
      decoration: TextDecoration.none,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.70),
          offset: const Offset(0, 1),
          blurRadius: 1.6,
        ),
      ],
    );
    _statusKazancStyle = _statusBaseStyle.copyWith(
      color: const Color(0xFFFFD13B),
    );
    _statusInsufficientStyle = _statusBaseStyle.copyWith(
      color: const Color(0xFFFF6A6A),
    );

    _bottomLabelStyle = GoogleFonts.barlowCondensed(
      color: const Color(0xFFFFD13B),
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.4,
      height: 1.0,
      shadows: softShadow,
    );
    _bottomValueStyle = GoogleFonts.barlowCondensed(
      color: Colors.white.withValues(alpha: 0.98),
      fontSize: 18,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.1,
      height: 1.0,
      shadows: softShadow,
    );
    _bottomClockStyle = GoogleFonts.barlowCondensed(
      color: Colors.white.withValues(alpha: 0.62),
      fontSize: 9.2,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.3,
      height: 1.0,
    );
  }

  void _onViewModelChange() {
    _handleLogout(context);
    _trackSpinTransitions();
    _trackLingeringCluster();
    _trackFsAccumulator();
    _trackNormalBigWin();
  }

  void _trackNormalBigWin() {
    if (_viewModel.isInFreeSpins) return;
    final lastWin = _viewModel.lastWin;
    if (lastWin > 0 && _lastSeenLastWinNormal == 0) {
      // The viewmodel sets `_lastSpinResult` a couple of lines after
      // the awardWin notify, so defer the multiplier-sequence check
      // until that assignment has run.
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence = result != null &&
            result.baseWin > 0 &&
            result.finalMultipliers.isNotEmpty;
        if (!hasSequence) {
          // No multiplier collect to wait on — let the player read
          // the new total briefly, then pop the celebration.
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _maybeShowBigWin(lastWin);
          });
        }
        // Multiplier spins instead trigger the overlay from the
        // win-presentation controller's `done` phase, after the
        // collect scene has settled at its final amount.
      });
    }
    _lastSeenLastWinNormal = lastWin;
  }

  void _maybeShowBigWin(double amount) {
    if (!mounted) return;
    if (_bigWinShownThisSpin || _bigWinEntry != null) return;
    if (_viewModel.isBusy) return;
    final bet = _viewModel.betAmount;
    if (bet <= 0) return;
    final tier = WinTier.forMultiplier(amount / bet);
    if (tier == null) return;

    _bigWinShownThisSpin = true;

    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => BigWinOverlay(
        amount: amount,
        tier: tier,
        onComplete: () {
          if (_bigWinEntry == entry) _bigWinEntry = null;
          entry.remove();
        },
      ),
    );
    _bigWinEntry = entry;
    overlay.insert(entry);
  }

  void _trackSpinTransitions() {
    final isBusy = _viewModel.isBusy;
    if (isBusy && !_wasBusy) {
      // New reel kicked off — drop the lingering cluster so the bottom
      // info band falls back to FREE SPINS LEFT, and reset the
      // multiplier controller so the middle tumble-win readout starts
      // the round at zero rather than carrying the previous spin's
      // final state. Any FS spin total still waiting for its visual
      // hand-off is committed now so it isn't lost when the
      // controller resets back to idle.
      _commitPendingFsWin();
      _winCtrl.reset();
      _bigWinShownThisSpin = false;
      if (_lingeringCluster != null) {
        setState(() => _lingeringCluster = null);
      }
    }
    _wasBusy = isBusy;
  }

  void _trackFsAccumulator() {
    final isInFs = _viewModel.isInFreeSpins;
    if (isInFs && !_wasInFs) {
      // Fresh free-spin round — start the accumulator from scratch.
      setState(() {
        _fsAccumulatedWin = 0;
        _pendingFsSpinWin = 0;
      });
    }
    _wasInFs = isInFs;

    if (!isInFs) return;

    final lastWin = _viewModel.lastWin;
    if (lastWin > 0 && _lastSeenLastWin == 0) {
      setState(() => _pendingFsSpinWin = lastWin);
      // The viewmodel notifies via balanceCtrl from inside awardWin,
      // but the new `lastSpinResult` is assigned a couple of lines
      // later — reading it synchronously here would still see the
      // previous spin's data. A microtask defers the hasSequence
      // check until that assignment has run.
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence = result != null &&
            result.baseWin > 0 &&
            result.finalMultipliers.isNotEmpty;
        if (!hasSequence) {
          // No multiplier collect to wait on — give the player a
          // brief beat to read the TUMBLE WIN value, then fly it
          // up. Multiplier spins instead wait for phase=done from
          // [_onWinCtrlChange] before triggering the flight. The
          // big-win overlay pops alongside the flight kick-off so
          // the celebration starts the moment the value visibly
          // begins moving.
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) {
              _maybeShowBigWin(lastWin);
              _commitPendingFsWin();
            }
          });
        }
      });
    }
    _lastSeenLastWin = lastWin;
  }

  void _trackLingeringCluster() {
    final activeExplosions = _viewModel.activeExplosions;
    if (activeExplosions.isEmpty) return;
    final best = activeExplosions.reduce(
      (a, b) => a.amount >= b.amount ? a : b,
    );
    if (!identical(_lingeringCluster, best)) {
      setState(() => _lingeringCluster = best);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Force-save on every "leaving" lifecycle so balance + pool always reach
    // Firestore — covers background, system task switch, OS hide, and the
    // app being killed by the user or low-memory pressure.
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _viewModel.onAppLifecycleEvent();
      case AppLifecycleState.resumed:
        _viewModel.onAppResumed();
        break;
    }
  }

  @override
  void dispose() {
    _bigWinEntry?.remove();
    _bigWinEntry = null;
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.balanceCtrl.removeListener(_onViewModelChange);
    _viewModel.gridCtrl.removeListener(_onViewModelChange);
    _winCtrl.removeListener(_onWinCtrlChange);
    _winCtrl.dispose();
    super.dispose();
  }

  void _onWinCtrlChange() {
    final phase = _winCtrl.phase;
    // Pop the big-win overlay the instant the multiplied total
    // starts climbing in TUMBLE WIN, so the celebration runs in
    // sync with the count-up rather than waiting for it to settle.
    if (phase == WinPresentationPhase.finalCounting &&
        _lastWinCtrlPhase != WinPresentationPhase.finalCounting) {
      _maybeShowBigWin(_viewModel.lastWin);
    }
    if (phase == WinPresentationPhase.done &&
        _lastWinCtrlPhase != WinPresentationPhase.done) {
      if (_viewModel.isInFreeSpins) {
        // Brief hold so the player can read the multiplied total in
        // TUMBLE WIN before it lifts off toward the Kazanç row.
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) _commitPendingFsWin();
        });
      }
    }
    _lastWinCtrlPhase = phase;
  }

  void _commitPendingFsWin() {
    if (_pendingFsSpinWin <= 0) return;
    final amount = _pendingFsSpinWin;

    // The big-win celebration carries the value to Kazanç on its
    // own — skip the flying sprite when the overlay is on screen so
    // the two effects don't fight for attention.
    if (_bigWinShownThisSpin) {
      setState(() {
        _fsAccumulatedWin += amount;
        _pendingFsSpinWin = 0;
      });
      return;
    }

    // Capture the start (TUMBLE WIN) and end (Kazanç) screen
    // positions before the layout flips — once the band drops to ₺0
    // the anchor's render rect would describe the shrunken text.
    final startBox =
        _tumbleWinAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final endBox =
        _kazancAnchorKey.currentContext?.findRenderObject() as RenderBox?;

    if (startBox != null && endBox != null) {
      final startCenter = startBox.localToGlobal(
        Offset(startBox.size.width / 2, startBox.size.height / 2),
      );
      final endCenter = endBox.localToGlobal(
        Offset(endBox.size.width / 2, endBox.size.height / 2),
      );

      final overlay = _stageOverlayKey.currentState;
      if (overlay == null) {
        setState(() {
          _fsAccumulatedWin += amount;
          _pendingFsSpinWin = 0;
        });
        return;
      }
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => _FlyingTumbleSprite(
          amount: amount,
          start: startCenter,
          end: endCenter,
          style: _statusBaseStyle,
          duration: const Duration(milliseconds: 700),
          onComplete: () {
            entry.remove();
            if (!mounted) return;
            // Sprite has landed at the Kazanç readout — fold the
            // amount into the round accumulator now so the top
            // counter starts climbing the moment the value arrives.
            // Flipping [_isFlyingTumble] back also restores the
            // multiplied total in the middle band. The big-win
            // overlay (if any) was already popped at phase=
            // finalCounting, so no trigger here.
            setState(() {
              _isFlyingTumble = false;
              _fsAccumulatedWin += amount;
            });
          },
        ),
      );
      overlay.insert(entry);

      setState(() {
        _isFlyingTumble = true;
        _pendingFsSpinWin = 0;
      });
    } else {
      // Layout missing — fall back to a plain accumulator commit so
      // the spin's value isn't lost if the anchors haven't laid out.
      setState(() {
        _fsAccumulatedWin += amount;
        _pendingFsSpinWin = 0;
      });
    }
  }

  void _handleLogout(BuildContext context) {
    if (!mounted) return;
    if (_viewModel.loggedOut) {
      _viewModel.resetLoggedOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Overlay(
        key: _stageOverlayKey,
        initialEntries: [
          OverlayEntry(builder: (context) => _buildStage()),
        ],
      ),
    );
  }

  Widget _buildStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenH = constraints.maxHeight;
        final double screenW = constraints.maxWidth;

          // The backdrop is BoxFit.cover'd — when the screen aspect
          // doesn't match the source aspect, the image gets horizontally
          // cropped/extended. Compute the inner grid frame's actual
          // on-screen position so the slot grid lands on the bg's own
          // cell boundaries regardless of device aspect.
          const double bgAspect = 1408 / 3040;
          const double bgInnerLeftRatio = 88 / 1408; // bg's inner-frame left edge
          const double bgInnerRightRatio = 1319 / 1408; // bg's inner-frame right edge

          final double screenAspect = screenW / screenH;
          final double bgDisplayW;
          final double bgLeftOnScreen;
          if (screenAspect >= bgAspect) {
            bgDisplayW = screenW;
            bgLeftOnScreen = 0;
          } else {
            bgDisplayW = screenH * bgAspect;
            bgLeftOnScreen = (screenW - bgDisplayW) / 2;
          }
          final double gridLeftPx =
              bgLeftOnScreen + bgDisplayW * bgInnerLeftRatio;
          final double gridRightPx =
              screenW - (bgLeftOnScreen + bgDisplayW * bgInnerRightRatio);

          return Stack(
            children: [
              Positioned.fill(
                // Backdrop swaps to the FS-mode artwork while a free-spin
                // round is active, so the round's distinct atmosphere is
                // visible the moment FS starts.
                child: ListenableBuilder(
                  listenable: _viewModel.fsCtrl,
                  builder: (context, _) {
                    final bgPath = _viewModel.isInFreeSpins
                        ? 'lib/images/slot_main_screen/freespin arka plan.png'
                        : 'lib/images/slot_main_screen/nihai arka plan.png';
                    return RepaintBoundary(
                      child: Image.asset(
                        bgPath,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.low,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.195,
                left: gridLeftPx,
                right: gridRightPx,
                height: screenH * 0.32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _viewModel,
                          _viewModel.gridCtrl,
                        ]),
                        builder: (context, _) => _buildSlotGrid(),
                      ),
                    ),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _viewModel,
                          _viewModel.gridCtrl,
                        ]),
                        builder: (context, _) {
                          return RepaintBoundary(
                            child: FloatingWinOverlay(
                              activeExplosions: _viewModel.activeExplosions,
                              gridWidth: screenW * 0.87,
                              gridHeight: screenH * 0.32,
                              speedMultiplier: _viewModel.speedMultiplier,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: Listenable.merge([
                  _viewModel,
                  _viewModel.fsCtrl,
                ]),
                builder: (context, _) {
                  // In free-spin rounds the strip splits into three
                  // black bands of the original height: top hosts the
                  // per-spin TUMBLE WIN counter, the FREE SPINS LEFT
                  // / cluster info line sits flush beneath it, and
                  // the round Kazanç readout sits at the bottom past
                  // a transparent gap.
                  final isFs = _viewModel.isInFreeSpins;
                  const bandHeight = 31.0;
                  const wideGap = 31.0;
                  // Tumble + info share one continuous black panel,
                  // separated from Kazanç by [wideGap] of background.
                  const infoTop = bandHeight;
                  const kazancTop = infoTop + bandHeight + wideGap;
                  const fsTotalHeight = kazancTop + bandHeight;
                  final totalHeight = isFs ? fsTotalHeight : bandHeight;
                  final kazancBand = _buildStatusBand(
                    child: ListenableBuilder(
                      listenable: Listenable.merge([
                        _viewModel,
                        _viewModel.balanceCtrl,
                      ]),
                      builder: (context, _) => _buildStatusText(
                        screenH: screenH,
                        gridLeft: gridLeftPx,
                        gridRight: gridRightPx,
                        screenW: screenW,
                      ),
                    ),
                  );
                  return Positioned(
                    top: screenH * 0.5185,
                    left: 0,
                    right: 0,
                    height: totalHeight,
                    child: Stack(
                      children: [
                        if (isFs) ...[
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: bandHeight,
                            child: _buildStatusBand(
                              child: _buildTumbleWinSlot(
                                screenH: screenH,
                                screenW: screenW,
                                gridLeft: gridLeftPx,
                                gridRight: gridRightPx,
                              ),
                            ),
                          ),
                          Positioned(
                            top: infoTop,
                            left: 0,
                            right: 0,
                            height: bandHeight,
                            child: _buildStatusBand(
                              child: ListenableBuilder(
                                listenable: Listenable.merge([
                                  _viewModel,
                                  _viewModel.fsCtrl,
                                  _viewModel.gridCtrl,
                                ]),
                                builder: (context, _) => _buildFsInfoLine(),
                              ),
                            ),
                          ),
                          Positioned(
                            top: kazancTop,
                            left: 0,
                            right: 0,
                            height: bandHeight,
                            child: kazancBand,
                          ),
                        ] else
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: bandHeight,
                            child: kazancBand,
                          ),
                      ],
                    ),
                  );
                },
              ),
              Positioned(
                top: screenH * 0.55,
                left: screenW * 0.08,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                    _viewModel.anteCtrl,
                    _viewModel.fsCtrl,
                  ]),
                  builder: (context, _) {
                    if (_viewModel.isInFreeSpins) return const SizedBox.shrink();
                    return RepaintBoundary(
                      child: BuyFeatureButton(
                        price: _viewModel.buyFeaturePrice,
                        disabled: !_viewModel.canBuyFreeSpinsForUi ||
                            _viewModel.anteBetActive,
                        onTap: _viewModel.buyFreeSpins,
                        width: screenW * 0.39,
                        height: screenW * 0.22,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.55,
                right: screenW * 0.08,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.anteCtrl,
                    _viewModel.balanceCtrl,
                    _viewModel.fsCtrl,
                  ]),
                  builder: (context, _) {
                    if (_viewModel.isInFreeSpins) return const SizedBox.shrink();
                    return RepaintBoundary(
                      child: DoubleChanceButton(
                        betAmount: _viewModel.anteCost,
                        isOn: _viewModel.anteBetActive,
                        disabled: _viewModel.isBusy || _viewModel.isInFreeSpins,
                        onTap: _viewModel.toggleAnteBet,
                        width: screenW * 0.39,
                        height: screenW * 0.22,
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.72,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _viewModel.balanceCtrl,
                        _viewModel.fsCtrl,
                      ]),
                      builder: (context, _) => RepaintBoundary(
                        child: MinusButton(
                          size: 42,
                          onTap: _viewModel.decreaseBet,
                          disabled: !_viewModel.canDecreaseBet ||
                              _viewModel.isInFreeSpins,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _viewModel,
                        _viewModel.balanceCtrl,
                        _viewModel.fsCtrl,
                      ]),
                      builder: (context, _) => RepaintBoundary(
                        child: RespinButton(
                          size: 84,
                          onTap: _viewModel.spin,
                          spinning: _viewModel.isBusy,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _viewModel.balanceCtrl,
                        _viewModel.fsCtrl,
                      ]),
                      builder: (context, _) => RepaintBoundary(
                        child: PlusButton(
                          size: 42,
                          onTap: _viewModel.increaseBet,
                          disabled: !_viewModel.canIncreaseBet ||
                              _viewModel.isInFreeSpins,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: 0,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => InfoButton(
                    betAmount: _viewModel.betAmount,
                  ),
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                right: 0,
                child: SettingsButton(
                  onTap: () {
                    showGeneralDialog(
                      context: context,
                      barrierColor: Colors.transparent,
                      barrierDismissible: true,
                      barrierLabel: 'Settings',
                      transitionDuration: const Duration(milliseconds: 250),
                      pageBuilder: (context, _, __) =>
                          SystemSettingsScreen(viewModel: _viewModel),
                      transitionBuilder: (context, anim, _, child) {
                        return FadeTransition(opacity: anim, child: child);
                      },
                    );
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: screenW * 0.30,
                child: const AutoSpinButton(),
              ),
              Positioned(
                top: screenH * 0.90,
                left: screenW * 0.5 + 42,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => SpeedButton(
                    level: _viewModel.speedMultiplier,
                    onTap: _viewModel.toggleSpeed,
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.22, 0.78, 1.0],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  // Bottom panel only reads balance + bet — no need to
                  // rebuild on unrelated _viewModel notifications.
                  child: ListenableBuilder(
                    listenable: _viewModel.balanceCtrl,
                    builder: (context, _) => _buildBottomPanel(screenW),
                  ),
                ),
              ),
            ],
          );
        },
    );
  }

  Widget _buildSlotGrid() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: List.generate(GameViewModel.columns, (col) {
            return Expanded(
              // Per-column RepaintBoundary so a reel's drop animation
              // doesn't invalidate sibling columns or the grid frame.
              child: RepaintBoundary(
                child: SlotReel(
                  columnIndex: col,
                  // Pass column lists by reference; List.generate
                  // here was producing fresh refs every rebuild.
                  previousItems: _viewModel.previousGrid[col],
                  targetItems: _viewModel.grid[col],
                  spinning: _viewModel.isSpinning,
                  fadingPaths: _viewModel.fadingPaths,
                  clearedPositions: _viewModel.clearedPositions,
                  speedMultiplier: _viewModel.speedMultiplier,
                  onComplete: col == GameViewModel.columns - 1
                      ? () => _viewModel.onSpinComplete()
                      : null,
                  // Only the first column triggers the residue wipe; the
                  // grid controller no-ops if it's already empty so the
                  // other columns calling later is harmless either way.
                  onDropInStart: col == 0
                      ? () => _viewModel.clearMultiplierResidues()
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusText({
    required double screenH,
    required double screenW,
    required double gridLeft,
    required double gridRight,
  }) {
    final lastWin = _viewModel.lastWin;
    final liveWin = _viewModel.liveTumbleWin;
    final isBusy = _viewModel.isBusy;
    final isTumbling = _viewModel.isTumbling;
    final isFs = _viewModel.isInFreeSpins;

    if (_viewModel.showInsufficientFundsHint) {
      return Text('PLEASE DEPOSIT MONEY!', style: _statusInsufficientStyle);
    }

    if (isFs) {
      // FS mode top is the round-running Kazanç total — every spin's
      // awarded win folds into the accumulator so the value keeps
      // climbing across the round instead of dropping back to zero on
      // each new reel. The chase counter animates each fold-in so the
      // value visibly grows as the tumble sprite lands.
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('KAZANÇ', style: _statusKazancStyle),
          const SizedBox(width: 6),
          Container(
            key: _kazancAnchorKey,
            child: WinAmountCounter(
              to: _fsAccumulatedWin,
              style: _statusBaseStyle,
              duration: const Duration(milliseconds: 700),
            ),
          ),
        ],
      );
    }

    // Live counter — visible whenever cluster wins are accumulating
    // mid-cascade. The chase counter inside [WinAmountCounter] tracks
    // every tumble bump without resetting, so the value climbs as the
    // symbols pop, not after.
    if (isTumbling && liveWin > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('KAZANÇ', style: _statusKazancStyle),
          const SizedBox(width: 6),
          WinAmountCounter(
            to: liveWin,
            style: _statusBaseStyle,
            duration: const Duration(milliseconds: 900),
          ),
        ],
      );
    }

    if (lastWin > 0 && !isBusy) {
      final result = _viewModel.lastSpinResult;
      final hasMultiplierSequence =
          result != null &&
          result.baseWin > 0 &&
          result.finalMultipliers.isNotEmpty;

      if (hasMultiplierSequence) {
        return WinPresentation(
          key: ValueKey<double>(lastWin),
          controller: _winCtrl,
          spinResult: result,
          gridLeft: gridLeft,
          gridTop: screenH * 0.195,
          gridWidth: screenW - gridLeft - gridRight,
          gridHeight: screenH * 0.32,
          baseStyle: _statusBaseStyle,
          accentStyle: _statusKazancStyle,
          onMultiplierLifted: (col, row) {
            _viewModel.gridCtrl.clearMultiplierPosition(col, row);
          },
        );
      }

      // Non-multiplier win — value already showed live during the
      // cascade, so the counter just holds at [lastWin] without
      // re-animating from zero.
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('KAZANÇ', style: _statusKazancStyle),
          const SizedBox(width: 6),
          Text('₺${formatMoney(lastWin)}', style: _statusBaseStyle),
        ],
      );
    }

    if (isBusy) {
      return Text('GOOD LUCK!', style: _statusBaseStyle);
    }

    return Text('PLACE YOUR BETS!', style: _statusBaseStyle);
  }

  Widget _buildStatusBand({required Widget child}) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.58),
                    Colors.black.withValues(alpha: 0.58),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.22, 0.78, 1.0],
                ),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildTumbleWinSlot({
    required double screenH,
    required double screenW,
    required double gridLeft,
    required double gridRight,
  }) {
    final result = _viewModel.lastSpinResult;
    final hasMultiplierSequence =
        result != null &&
        result.baseWin > 0 &&
        result.finalMultipliers.isNotEmpty;
    // While a multiplier sequence is live, mount the orchestrator on
    // top of the counter so bombs fire and collect flights aim at the
    // tumble-win anchor. The widget itself is silent — it stays
    // mounted only to drive the controller and the overlays.
    final showOrchestrator = hasMultiplierSequence &&
        !_viewModel.isBusy &&
        _winCtrl.phase != WinPresentationPhase.done;

    return Stack(
      children: [
        Center(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              _viewModel,
              _viewModel.balanceCtrl,
              _viewModel.gridCtrl,
              _winCtrl,
            ]),
            builder: (context, _) => _buildTumbleWinLine(),
          ),
        ),
        if (showOrchestrator)
          WinPresentation(
            key: ValueKey<Object?>(result),
            controller: _winCtrl,
            formulaOnly: true,
            flightTargetKey: _tumbleWinAnchorKey,
            spinResult: result,
            gridLeft: gridLeft,
            gridTop: screenH * 0.195,
            gridWidth: screenW - gridLeft - gridRight,
            gridHeight: screenH * 0.32,
            baseStyle: _statusBaseStyle,
            accentStyle: _statusKazancStyle,
            onMultiplierLifted: (col, row) {
              _viewModel.gridCtrl.clearMultiplierPosition(col, row);
            },
          ),
      ],
    );
  }

  Widget _buildTumbleWinLine() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text('TUMBLE WIN', style: _statusKazancStyle),
        const SizedBox(width: 6),
        _buildTumbleWinValue(),
      ],
    );
  }

  Widget _buildTumbleWinValue() {
    // While the spin's win is mid-flight up to the Kazanç readout the
    // middle band drops to ₺0 — once the sprite lands the flag flips
    // back and the multiplied total restores in place.
    if (_isFlyingTumble) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: Text('₺${formatMoney(0)}', style: _statusBaseStyle),
      );
    }

    // During a live spin (reels turning, cascade popping) the value
    // chases the running cluster total so the player sees the bar
    // climb in lock-step with each tumble pop.
    if (_viewModel.isBusy) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: WinAmountCounter(
          to: _viewModel.liveTumbleWin,
          style: _statusBaseStyle,
          duration: const Duration(milliseconds: 350),
        ),
      );
    }

    final result = _viewModel.lastSpinResult;
    if (result == null) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: Text(
          '₺${formatMoney(_viewModel.lastWin)}',
          style: _statusBaseStyle,
        ),
      );
    }

    final hasSequence =
        result.baseWin > 0 && result.finalMultipliers.isNotEmpty;
    if (!hasSequence) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: Text(
          '₺${formatMoney(result.totalWin)}',
          style: _statusBaseStyle,
        ),
      );
    }

    switch (_winCtrl.phase) {
      case WinPresentationPhase.idle:
      case WinPresentationPhase.baseCounting:
        // Hold at the cluster total while the multiplier collect is
        // about to start — the formula appears once the first sprite
        // lifts off.
        return Container(
          key: _tumbleWinAnchorKey,
          child: Text(
            '₺${formatMoney(result.baseWin)}',
            style: _statusBaseStyle,
          ),
        );

      case WinPresentationPhase.multiplierCollecting:
        // Live formula — `₺base × runningSum`. Multipliers fly into
        // the running-sum slot and the integer pops on each landing,
        // matching the previous Kazanç-bar behaviour.
        final sum = _winCtrl.runningSum;
        final showMultiplySign = _winCtrl.multiplierFlightStarted;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '₺${formatMoney(result.baseWin)}',
              style: _statusBaseStyle,
            ),
            if (showMultiplySign) ...[
              const SizedBox(width: 8),
              Text('×', style: _statusBaseStyle),
              const SizedBox(width: 6),
              Container(
                key: _tumbleWinAnchorKey,
                child: sum > 0
                    ? _PulsingMultiplierSum(
                        value: sum,
                        style: _statusKazancStyle,
                      )
                    : Text(
                        '0',
                        style: _statusKazancStyle.copyWith(
                          color: const Color(0x00000000),
                        ),
                      ),
              ),
            ],
          ],
        );

      case WinPresentationPhase.finalCounting:
        // Formula collapses — the multiplied total reels up next to
        // the TUMBLE WIN label, climbing from the base to the final
        // amount before the sprite lifts off toward the Kazanç row.
        return Container(
          key: _tumbleWinAnchorKey,
          child: WinAmountCounter(
            from: _winCtrl.baseWin,
            to: result.totalWin,
            style: _statusBaseStyle,
            duration: WinPresentationController.finalCountUpDuration,
          ),
        );

      case WinPresentationPhase.done:
        // Multiplied total parks here statically — also what the
        // middle band falls back to after the flight lands so the
        // value isn't wiped out.
        return Container(
          key: _tumbleWinAnchorKey,
          child: Text(
            '₺${formatMoney(result.totalWin)}',
            style: _statusBaseStyle,
          ),
        );
    }
  }

  Widget _buildFsInfoLine() {
    // Bottom line sits a touch smaller than the Kazanç / TUMBLE WIN
    // readouts so the two stacked bands read as a primary-secondary
    // pair rather than competing at the same weight.
    final infoStyle = _statusBaseStyle.copyWith(fontSize: 16);
    final activeExplosions = _viewModel.activeExplosions;
    final ClusterWin? clusterToShow = activeExplosions.isNotEmpty
        ? activeExplosions.reduce((a, b) => a.amount >= b.amount ? a : b)
        : _lingeringCluster;

    if (clusterToShow != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${clusterToShow.positions.length}X',
            style: infoStyle,
          ),
          const SizedBox(width: 6),
          Image.asset(
            clusterToShow.assetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text(
            'PAYS ₺${formatMoney(clusterToShow.amount)}',
            style: infoStyle,
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('FREE SPINS LEFT', style: infoStyle),
        const SizedBox(width: 6),
        Text(
          '${_viewModel.freeSpinsRemaining}',
          style: infoStyle,
        ),
      ],
    );
  }

  Widget _buildBottomPanel(double screenW) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('CREDIT', style: _bottomLabelStyle),
              const SizedBox(width: 4),
              Text(
                '₺${formatMoney(_viewModel.balance)}',
                style: _bottomValueStyle,
              ),
              const SizedBox(width: 16),
              Text('BET', style: _bottomLabelStyle),
              const SizedBox(width: 4),
              Text(
                '₺${formatMoney(_viewModel.betAmount)}',
                style: _bottomValueStyle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        _ClockText(style: _bottomClockStyle),
      ],
    );
  }
}

class _FlyingTumbleSprite extends StatefulWidget {
  final double amount;
  final Offset start;
  final Offset end;
  final TextStyle style;
  final Duration duration;
  final VoidCallback onComplete;

  const _FlyingTumbleSprite({
    required this.amount,
    required this.start,
    required this.end,
    required this.style,
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_FlyingTumbleSprite> createState() => _FlyingTumbleSpriteState();
}

class _FlyingTumbleSpriteState extends State<_FlyingTumbleSprite>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _ctrl.forward().then((_) {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final raw = _ctrl.value;
        final t = Curves.easeInOutCubic.transform(raw);
        final pos = Offset.lerp(widget.start, widget.end, t)!;
        // Slight shrink and tail-fade so the sprite "absorbs" into
        // the Kazanç readout instead of stopping abruptly.
        final scale = 1.0 - 0.25 * t;
        final opacity = raw < 0.85 ? 1.0 : (1.0 - raw) / 0.15;
        // Positioned directly — the OverlayEntry's parent Stack
        // (Overlay's own) supplies the screen-space frame.
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: IgnorePointer(
            child: FractionalTranslation(
              translation: const Offset(-0.5, -0.5),
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: scale,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Text(
                      '₺${formatMoney(widget.amount)}',
                      style: widget.style,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PulsingMultiplierSum extends StatefulWidget {
  final int value;
  final TextStyle style;

  const _PulsingMultiplierSum({
    required this.value,
    required this.style,
  });

  @override
  State<_PulsingMultiplierSum> createState() => _PulsingMultiplierSumState();
}

class _PulsingMultiplierSumState extends State<_PulsingMultiplierSum>
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
        tween: Tween<double>(begin: 1.0, end: 1.5)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.5, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 55,
      ),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _PulsingMultiplierSum old) {
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

class _ClockText extends StatelessWidget {
  final TextStyle style;

  const _ClockText({required this.style});

  static final Stream<DateTime> _ticker = Stream<DateTime>.periodic(
    const Duration(seconds: 10),
    (_) => DateTime.now().toUtc().add(const Duration(hours: 3)),
  ).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _ticker,
      initialData: DateTime.now().toUtc().add(const Duration(hours: 3)),
      builder: (context, snapshot) {
        final now = snapshot.data!;
        final timeString =
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        return Text(
          'WINNER SPIN · $timeString',
          textAlign: TextAlign.center,
          style: style,
        );
      },
    );
  }
}
