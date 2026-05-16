import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../domain/models/cluster_win.dart';
import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../audio/ui_click_sound.dart';
import '../controllers/big_win_overlay_controller.dart';
import '../controllers/flying_tumble_overlay_controller.dart';
import '../controllers/free_spin_overlay_controller.dart';
import '../models/big_win_presentation_rules.dart';
import '../models/cluster_presentation_rules.dart';
import '../models/free_spin_award_presentation_state.dart';
import '../models/free_spin_presentation_state.dart';
import '../models/game_presentation_guards.dart';
import '../models/game_presentation_timings.dart';
import '../models/game_screen_listener_registry.dart';
import '../models/game_screen_listenables.dart';
import '../models/game_stage_metrics.dart';
import '../models/game_screen_text_styles.dart';
import '../models/pending_free_spin_award.dart';
import '../models/scatter_cell.dart';
import '../models/spin_result_presentation_rules.dart';
import '../navigation/game_screen_navigation.dart';
import '../services/game_asset_precache_service.dart';
import '../services/game_screen_startup_service.dart';
import '../services/scatter_cell_finder.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/slot_reel.dart';
import 'widgets/game_utility_buttons.dart';
import 'widgets/game_feature_controls.dart';
import 'widgets/free_spin_scatter_transition.dart';
import 'widgets/game_background.dart';
import 'widgets/game_bottom_info_slot.dart';
import 'widgets/game_free_spin_info_slot.dart';
import 'widgets/game_spin_controls_slot.dart';
import 'widgets/game_status_bands.dart';
import 'widgets/game_status_text.dart';
import 'widgets/game_tumble_win_slot.dart';
import 'widgets/win_presentation_controller.dart';
import 'widgets/slot_grid_view.dart';
import 'widgets/slot_playfield.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameViewModel _viewModel = GameViewModel();
  final FirstLaunchDisclaimerRepository _firstLaunchDisclaimerRepository =
      LocalFirstLaunchDisclaimerRepository();

  final WinPresentationController _winCtrl = WinPresentationController();
  final BigWinOverlayController _bigWinOverlayController =
      BigWinOverlayController();
  final FreeSpinOverlayController _freeSpinOverlayController =
      FreeSpinOverlayController();
  final FlyingTumbleOverlayController _flyingTumbleOverlayController =
      FlyingTumbleOverlayController();
  final GameAssetPrecacheService _assetPrecacheService =
      GameAssetPrecacheService();
  final GameScreenStartupService _startupService =
      const GameScreenStartupService();

  final GlobalKey _tumbleWinAnchorKey = GlobalKey();

  ClusterWin? _lingeringCluster;
  bool _wasBusy = false;

  bool _wasTumbling = false;
  Timer? _lingeringClusterTimer;

  Timer? _celebrationLockWatchdog;

  final FreeSpinPresentationState _freeSpinPresentation =
      FreeSpinPresentationState();
  WinPresentationPhase _lastWinCtrlPhase = WinPresentationPhase.idle;

  final GlobalKey _kazancAnchorKey = GlobalKey();

  final GlobalKey<OverlayState> _stageOverlayKey = GlobalKey<OverlayState>();

  late final List<SlotReelController> _reelControllers;

  final FreeSpinAwardPresentationState _freeSpinAwardPresentation =
      FreeSpinAwardPresentationState();
  Timer? _freeSpinTransitionTimer;
  Timer? _scatterPulseTimer;

  bool _isFlyingTumble = false;

  double _lastSeenLastWinNormal = 0;

  bool _bigWinShownThisSpin = false;
  bool _isBigWinShowing = false;

  bool get _isFreeSpinVisualMode =>
      _freeSpinAwardPresentation.isVisualMode(_viewModel.isInFreeSpins);

  bool _celebrationLocked = false;

  bool get _isCelebrationActive {
    final phase = _winCtrl.phase;
    final winPresentationActive =
        phase != WinPresentationPhase.idle &&
        phase != WinPresentationPhase.done;
    return winPresentationActive ||
        _bigWinOverlayController.hasActiveOverlay ||
        _celebrationLocked;
  }

  late final GameScreenTextStyles _styles;
  late final GameScreenListenables _listenables;
  late final GameScreenListenerRegistry _listenerRegistry;

  @override
  void initState() {
    super.initState();
    _reelControllers = List.generate(
      GameViewModel.columns,
      (_) => SlotReelController(),
    );
    _styles = GameScreenTextStyles.create();
    _listenables = GameScreenListenables(
      viewModel: _viewModel,
      winController: _winCtrl,
    );
    _listenerRegistry = GameScreenListenerRegistry(
      viewModel: _viewModel,
      winController: _winCtrl,
      onViewModelChange: _onViewModelChange,
      onFreeSpinStateChange: _onFreeSpinStateChange,
      onWinControllerChange: _onWinCtrlChange,
    );
    WidgetsBinding.instance.addObserver(this);
    _listenerRegistry.attach();
    _startupService.start(
      context: context,
      viewModel: _viewModel,
      assetPrecacheService: _assetPrecacheService,
      disclaimerRepository: _firstLaunchDisclaimerRepository,
      isMounted: () => mounted,
    );
  }

  void _onViewModelChange() {
    UiClickSound.enabled = _viewModel.soundEffects;
    GameScreenNavigation.handleLogout(
      context: context,
      viewModel: _viewModel,
      isMounted: mounted,
    );
    _trackSpinTransitions();
    _trackLingeringCluster();
    _trackFsAccumulator();
    _trackNormalBigWin();
  }

  void _onFreeSpinStateChange() {
    final isInFreeSpins = _viewModel.isInFreeSpins;
    final pending = _freeSpinAwardPresentation.takeAwardForFreeSpinState(
      isInFreeSpins: isInFreeSpins,
      result: _viewModel.lastSpinResult,
    );
    if (pending != null) {
      _startFreeSpinAwardTransition(pending);
    }
    _freeSpinAwardPresentation.updateFreeSpinMode(isInFreeSpins);
  }

  void _startFreeSpinAwardTransition(PendingFreeSpinAward pending) {
    _freeSpinTransitionTimer?.cancel();
    _freeSpinPresentation.recordAward(
      pending.value,
      isRetrigger: pending.isRetrigger,
    );

    setState(() {
      _freeSpinAwardPresentation.startAward(pending);
    });
  }

  void _quickStopReels() {
    if (!_viewModel.isSpinning || _viewModel.isTumbling) return;
    for (final controller in _reelControllers) {
      controller.quickStop();
    }
  }

  void _showFreeSpinWinPopup({
    required int value,
    required bool isRetrigger,
    required double winAmount,
  }) {
    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) return;

    _freeSpinOverlayController.showWinPopup(
      overlay: overlay,
      value: value,
      isRetrigger: isRetrigger,
      winAmount: winAmount,
      cacheWidth: GameAssetPrecacheService.freeSpinPopupCacheWidth,
      onDismiss: () {
        _freeSpinAwardPresentation.endSequence();
        _continueAutoSpinIfPresentationIdle();
      },
    );
  }

  void _showPendingFreeSpinAwardPopup() {
    if (!_freeSpinAwardPresentation.hasPendingPopup ||
        _freeSpinOverlayController.hasActiveOverlay) {
      return;
    }
    final pending = _freeSpinAwardPresentation.takePendingPopup();
    if (pending == null) return;
    _showFreeSpinAwardSequence(pending);
  }

  void _showFreeSpinAwardSequence(PendingFreeSpinAward pending) {
    _freeSpinAwardPresentation.beginSequence();
    if (pending.isRetrigger) {
      _showScatterPulse(
        minScatterCount: 3,
        onComplete: () => _showFreeSpinWinPopup(
          value: pending.value,
          isRetrigger: pending.isRetrigger,
          winAmount: pending.winAmount,
        ),
      );
      return;
    }

    _showScatterPulse(
      minScatterCount: 4,
      onComplete: () => _startInitialFreeSpinVisualTransition(pending),
    );
  }

  void _startInitialFreeSpinVisualTransition(PendingFreeSpinAward pending) {
    if (!mounted) return;
    setState(_freeSpinAwardPresentation.showTransitionOverlay);
    Future.delayed(GamePresentationTimings.freeSpinVisualRevealDelay, () {
      if (!mounted || !_freeSpinAwardPresentation.showTransition) return;
      setState(_freeSpinAwardPresentation.revealVisualMode);
    });
    _freeSpinTransitionTimer = Timer(
      GamePresentationTimings.freeSpinTransitionDuration,
      () {
        if (!mounted) return;
        setState(_freeSpinAwardPresentation.hideTransitionOverlay);
        _showFreeSpinWinPopup(
          value: pending.value,
          isRetrigger: pending.isRetrigger,
          winAmount: pending.winAmount,
        );
      },
    );
  }

  void _showScatterPulse({
    required int minScatterCount,
    required VoidCallback onComplete,
  }) {
    final scatterCells = _currentScatterCells();
    if (scatterCells.length < minScatterCount) {
      onComplete();
      return;
    }

    _scatterPulseTimer?.cancel();
    setState(_freeSpinAwardPresentation.triggerScatterPulse);
    _scatterPulseTimer = Timer(
      GamePresentationTimings.scatterPulseDuration,
      () {
        if (!mounted) return;
        setState(_freeSpinAwardPresentation.clearScatterPulse);
        onComplete();
      },
    );
  }

  List<ScatterCell> _currentScatterCells() {
    return ScatterCellFinder.findInGrid(_viewModel.grid);
  }

  void _showFreeSpinSummaryPopup() {
    if (_freeSpinAwardPresentation.summaryPopupVisible) return;
    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) {
      _playFreeSpinExitTransitionThenRelease();
      return;
    }

    _freeSpinOverlayController.clear();
    _freeSpinAwardPresentation.clearPendingPopup();

    setState(_freeSpinAwardPresentation.beginSummary);
    _freeSpinOverlayController.showSummaryPopup(
      overlay: overlay,
      totalWin: _freeSpinPresentation.accumulatedWin,
      totalFreeSpins: _freeSpinPresentation.awardedThisRound,
      cacheWidth: GameAssetPrecacheService.freeSpinPopupCacheWidth,
      onDismiss: () {
        if (!mounted) return;
        setState(_freeSpinAwardPresentation.endSummary);
        _playFreeSpinExitTransitionThenRelease();
        _continueAutoSpinIfPresentationIdle();
      },
    );
  }

  void _playFreeSpinExitTransitionThenRelease() {
    _freeSpinTransitionTimer?.cancel();
    setState(_freeSpinAwardPresentation.showTransitionOverlay);
    Future.delayed(GamePresentationTimings.freeSpinVisualRevealDelay, () {
      if (!mounted || !_freeSpinAwardPresentation.showTransition) return;
      _viewModel.releaseFsRoundHold();
    });
    _freeSpinTransitionTimer = Timer(
      GamePresentationTimings.freeSpinTransitionDuration,
      () {
        if (!mounted) return;
        setState(_freeSpinAwardPresentation.hideTransitionOverlay);
        _continueAutoSpinIfPresentationIdle();
      },
    );
  }

  void _showAutoPlaySettings() {
    GameScreenNavigation.showAutoPlaySettings(
      context: context,
      viewModel: _viewModel,
    );
  }

  void _showGameRules() {
    GameScreenNavigation.showGameRules(
      context: context,
      betAmount: _viewModel.betAmount,
    );
  }

  void _showSystemSettings() {
    GameScreenNavigation.showSystemSettings(
      context: context,
      viewModel: _viewModel,
    );
  }

  void _trackNormalBigWin() {
    if (_viewModel.isInFreeSpins) return;
    final lastWin = _viewModel.lastWin;
    if (lastWin > 0 && _lastSeenLastWinNormal == 0) {
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence = SpinResultPresentationRules.hasMultiplierSequence(
          result,
        );
        if (!hasSequence) {
          Future.delayed(GamePresentationTimings.normalBigWinDelay, () {
            if (mounted) _maybeShowBigWin(lastWin);
          });
        }
      });
    }
    _lastSeenLastWinNormal = lastWin;
  }

  Future<void> _promptBuyFreeSpinsConfirm() async {
    final canPrompt = GamePresentationGuards.canPromptBuyFreeSpins(
      anteBetActive: _viewModel.anteBetActive,
      bigWinShowing: _isBigWinShowing,
      isBusy: _viewModel.isBusy,
      celebrationActive: _isCelebrationActive,
      canBuyFreeSpinsForUi: _viewModel.canBuyFreeSpinsForUi,
    );
    if (!canPrompt) {
      return;
    }
    final confirmed = await GameScreenNavigation.promptBuyFreeSpinsConfirm(
      context: context,
      spinCount: 10,
      price: _viewModel.buyFeaturePrice,
    );
    if (!mounted || !confirmed) return;
    await _viewModel.buyFreeSpins();
  }

  void _maybeShowBigWin(double amount) {
    if (!mounted) return;
    if (_bigWinShownThisSpin || _bigWinOverlayController.hasActiveOverlay) {
      return;
    }
    if (_viewModel.isBusy) return;
    final bet = _viewModel.betAmount;
    final tier = BigWinPresentationRules.tierForWin(
      amount: amount,
      betAmount: bet,
    );
    if (tier == null) return;

    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) return;

    setState(() {
      _bigWinShownThisSpin = true;
      _isBigWinShowing = true;
    });

    _bigWinOverlayController.show(
      overlay: overlay,
      amount: amount,
      tier: tier,
      instantAmount: _viewModel.speedMultiplier >= 3,
      soundEnabled: _viewModel.soundEffects,
      vibrationEnabled: _viewModel.vibration,
      onComplete: () {
        if (!mounted) return;
        setState(() => _isBigWinShowing = false);
        _releaseCelebrationLock();
      },
    );
  }

  void _trackSpinTransitions() {
    final isBusy = _viewModel.isBusy;
    if (isBusy && !_wasBusy) {
      _commitPendingFsWin();
      _winCtrl.reset();
      _bigWinShownThisSpin = false;
      if (_celebrationLocked) {
        setState(() => _celebrationLocked = false);
      }
      _celebrationLockWatchdog?.cancel();
      _celebrationLockWatchdog = null;
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = null;
      if (_lingeringCluster != null) {
        setState(() => _lingeringCluster = null);
      }
    }
    if (!isBusy && _wasBusy) {
      setState(() => _celebrationLocked = true);
      _celebrationLockWatchdog?.cancel();
      _celebrationLockWatchdog = Timer(
        GamePresentationTimings.celebrationLockMaxHold,
        () {
          if (!mounted) return;
          if (_celebrationLocked) {
            _releaseCelebrationLock();
          }
        },
      );
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence = SpinResultPresentationRules.hasMultiplierSequence(
          result,
        );
        final hasBigWin = BigWinPresentationRules.hasEligibleBigWin(
          result: result,
          isCurrentSpinFromBuy: _viewModel.isCurrentSpinFromBuy,
          betAmount: _viewModel.betAmount,
        );
        final hasFsFlight = SpinResultPresentationRules.hasFreeSpinWinFlight(
          isInFreeSpins: _viewModel.isInFreeSpins,
          isCurrentSpinFromBuy: _viewModel.isCurrentSpinFromBuy,
          result: result,
        );
        if (GamePresentationGuards.shouldReleaseCelebrationLock(
          hasMultiplierSequence: hasSequence,
          hasBigWin: hasBigWin,
          hasFreeSpinWinFlight: hasFsFlight,
        )) {
          _releaseCelebrationLock();
        }
      });
    }
    _wasBusy = isBusy;
  }

  void _trackFsAccumulator() {
    final isInFs = _viewModel.isInFreeSpins;
    if (_freeSpinPresentation.shouldResetRound(isInFs)) {
      setState(() {
        _freeSpinPresentation.resetRound();
        _freeSpinAwardPresentation.endSummary();
      });
    }
    _freeSpinPresentation.updateFreeSpinMode(isInFs);

    if (!isInFs) return;

    final lastWin = _viewModel.lastWin;
    if (_freeSpinPresentation.shouldCaptureLastWin(lastWin)) {
      if (_viewModel.isCurrentSpinFromBuy) {
        setState(() => _freeSpinPresentation.captureBuySpinWin(lastWin));
      } else {
        setState(() => _freeSpinPresentation.capturePendingSpinWin(lastWin));
        Future.microtask(() {
          if (!mounted) return;
          final result = _viewModel.lastSpinResult;
          final hasSequence = SpinResultPresentationRules.hasMultiplierSequence(
            result,
          );
          if (!hasSequence) {
            Future.delayed(
              GamePresentationTimings.freeSpinNoSequenceWinDelay,
              () {
                if (mounted) {
                  _maybeShowBigWin(lastWin);
                  _commitPendingFsWin();
                }
              },
            );
          }
        });
      }
    }
    _freeSpinPresentation.updateLastSeenWin(lastWin);
  }

  void _trackLingeringCluster() {
    final activeExplosions = _viewModel.activeExplosions;
    final isTumbling = _viewModel.isTumbling;

    if (activeExplosions.isNotEmpty) {
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = null;
      final best = ClusterPresentationRules.highestAmount(activeExplosions);
      if (!identical(_lingeringCluster, best)) {
        setState(() => _lingeringCluster = best);
      }
    } else if (_wasTumbling && !isTumbling && _lingeringCluster != null) {
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = Timer(
        GamePresentationTimings.lingeringClusterHold,
        () {
          if (!mounted) return;
          setState(() => _lingeringCluster = null);
        },
      );
    }
    _wasTumbling = isTumbling;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
    _bigWinOverlayController.dispose();
    _freeSpinOverlayController.dispose();
    _flyingTumbleOverlayController.dispose();
    _isBigWinShowing = false;
    _freeSpinTransitionTimer?.cancel();
    _scatterPulseTimer?.cancel();
    _assetPrecacheService.dispose();
    _lingeringClusterTimer?.cancel();
    _celebrationLockWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _listenerRegistry.detach();
    _winCtrl.dispose();
    super.dispose();
  }

  void _onWinCtrlChange() {
    final phase = _winCtrl.phase;
    if (phase == WinPresentationPhase.finalCounting &&
        _lastWinCtrlPhase != WinPresentationPhase.finalCounting) {
      _maybeShowBigWin(_viewModel.lastWin);
    }
    if (phase == WinPresentationPhase.done &&
        _lastWinCtrlPhase != WinPresentationPhase.done) {
      if (_viewModel.isInFreeSpins) {
        if (_viewModel.isCurrentSpinFromBuy) {
          _releaseCelebrationLock();
        } else {
          Future.delayed(
            GamePresentationTimings.freeSpinNoSequenceWinDelay,
            () {
              if (mounted) _commitPendingFsWin();
            },
          );
        }
      } else {
        _releaseCelebrationLock();
      }
    }
    _lastWinCtrlPhase = phase;
  }

  void _commitPendingFsWin() {
    if (!_freeSpinPresentation.hasPendingSpinWin) return;
    final amount = _freeSpinPresentation.pendingSpinWin;

    if (_bigWinShownThisSpin) {
      setState(_freeSpinPresentation.commitPendingSpinWin);
      return;
    }

    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) {
      setState(_freeSpinPresentation.commitPendingSpinWin);
      _releaseLockAfterFsCountUp();
      return;
    }

    final startedFlight = _flyingTumbleOverlayController.showFromAnchors(
      overlay: overlay,
      startKey: _tumbleWinAnchorKey,
      endKey: _kazancAnchorKey,
      amount: amount,
      style: _styles.statusBase,
      duration: GamePresentationTimings.flyingTumbleDuration,
      onComplete: () {
        if (!mounted) return;
        setState(() {
          _isFlyingTumble = false;
          _freeSpinPresentation.addToAccumulatedWin(amount);
        });
        Future.delayed(GamePresentationTimings.flyingTumbleReleaseDelay, () {
          if (!mounted) return;
          _releaseCelebrationLock();
        });
      },
    );
    if (startedFlight) {
      setState(() {
        _isFlyingTumble = true;
        _freeSpinPresentation.clearPendingSpinWin();
      });
      return;
    }

    setState(_freeSpinPresentation.commitPendingSpinWin);
    _releaseLockAfterFsCountUp();
  }

  void _releaseLockAfterFsCountUp() {
    Future.delayed(GamePresentationTimings.flyingTumbleReleaseDelay, () {
      if (!mounted) return;
      _releaseCelebrationLock();
    });
  }

  void _releaseCelebrationLock() {
    _celebrationLockWatchdog?.cancel();
    _celebrationLockWatchdog = null;
    if (_celebrationLocked) {
      setState(() => _celebrationLocked = false);
    }
    if (_bigWinOverlayController.hasActiveOverlay) {
      return;
    }
    _viewModel.commitPendingFsConsume();
    if (_viewModel.isInFreeSpins && _viewModel.freeSpinsRemaining == 0) {
      _showFreeSpinSummaryPopup();
      return;
    }
    _viewModel.releaseFsRoundHold();
    _showPendingFreeSpinAwardPopup();
    _continueAutoSpinIfPresentationIdle();
  }

  void _continueAutoSpinIfPresentationIdle() {
    if (!mounted) return;
    final canContinue = GamePresentationGuards.shouldContinueAutoSpin(
      celebrationActive: _isCelebrationActive,
      freeSpinAwardSequenceActive: _freeSpinAwardPresentation.sequenceActive,
      hasPendingFreeSpinAward: _freeSpinAwardPresentation.hasPendingPopup,
      scatterPulseActive: _scatterPulseTimer?.isActive == true,
      hasActiveFreeSpinOverlay: _freeSpinOverlayController.hasActiveOverlay,
      showFreeSpinTransition: _freeSpinAwardPresentation.showTransition,
      fsSummaryPopupVisible: _freeSpinAwardPresentation.summaryPopupVisible,
    );
    if (!canContinue) {
      return;
    }
    _viewModel.continueAutoSpinIfReady();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _quickStopReels(),
        child: Overlay(
          key: _stageOverlayKey,
          initialEntries: [OverlayEntry(builder: (context) => _buildStage())],
        ),
      ),
    );
  }

  Widget _buildStage() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = GameStageMetrics.fromConstraints(constraints);

        return AbsorbPointer(
          absorbing: _isBigWinShowing,
          child: Stack(
            children: [
              Positioned.fill(
                child: GameBackground(
                  listenable: _listenables.freeSpinVisual,
                  isFreeSpinVisualMode: () => _isFreeSpinVisualMode,
                ),
              ),
              SlotPlayfield(
                screenH: metrics.screenH,
                screenW: metrics.screenW,
                gridLeft: metrics.gridLeft,
                gridRight: metrics.gridRight,
                gridListenable: _listenables.gridVisual,
                floatingWinListenable: _viewModel.gridCtrl,
                activeExplosions: () => _viewModel.activeExplosions,
                speedMultiplier: () => _viewModel.speedMultiplier,
                buildSlotGrid: _buildSlotGrid,
              ),
              GameStatusBands(
                screenH: metrics.screenH,
                freeSpinVisualListenable: _listenables.freeSpinVisual,
                balanceStatusListenable: _listenables.balanceStatus,
                isFreeSpinVisualMode: () => _isFreeSpinVisualMode,
                buildStatusText: () => _buildStatusText(
                  screenH: metrics.screenH,
                  gridLeft: metrics.gridLeft,
                  gridRight: metrics.gridRight,
                  screenW: metrics.screenW,
                ),
                buildTumbleWinSlot: () => _buildTumbleWinSlot(
                  screenH: metrics.screenH,
                  screenW: metrics.screenW,
                  gridLeft: metrics.gridLeft,
                  gridRight: metrics.gridRight,
                ),
                freeSpinInfoLine: GameFreeSpinInfoSlot(
                  listenable: _listenables.fsInfo,
                  activeExplosions: () => _viewModel.activeExplosions,
                  lingeringCluster: () => _lingeringCluster,
                  freeSpinsRemaining: () => _viewModel.freeSpinsRemaining,
                  style: _styles.statusBase.copyWith(fontSize: 16),
                ),
              ),
              GameFeatureControls(
                screenH: metrics.screenH,
                screenW: metrics.screenW,
                buyFeatureListenable: _listenables.buyFeature,
                anteToggleListenable: _listenables.anteToggle,
                isFreeSpinVisualMode: () => _isFreeSpinVisualMode,
                isBigWinShowing: () => _isBigWinShowing,
                isBusy: () => _viewModel.isBusy,
                isCelebrationActive: () => _isCelebrationActive,
                anteBetActive: () => _viewModel.anteBetActive,
                canBuyFreeSpinsForUi: () => _viewModel.canBuyFreeSpinsForUi,
                isAutoSpinning: () => _viewModel.isAutoSpinning,
                isInFreeSpins: () => _viewModel.isInFreeSpins,
                vibrationEnabled: () => _viewModel.vibration,
                buyFeaturePrice: () => _viewModel.buyFeaturePrice,
                anteCost: () => _viewModel.anteCost,
                onBuyFeatureTap: _promptBuyFreeSpinsConfirm,
                onAnteTap: _viewModel.toggleAnteBet,
              ),
              GameSpinControlsSlot(
                screenH: metrics.screenH,
                listenable: _listenables.spinControls,
                autoSpinActive: () => _viewModel.isAutoSpinning,
                bigWinShowing: () => _isBigWinShowing,
                spinning: () => _viewModel.isBusy || _isCelebrationActive,
                canDecreaseBet: () => _viewModel.canDecreaseBet,
                canIncreaseBet: () => _viewModel.canIncreaseBet,
                isInFreeSpins: () => _viewModel.isInFreeSpins,
                autoSpinsRemaining: () => _viewModel.autoSpinsRemaining,
                onDecreaseBet: _viewModel.decreaseBet,
                onIncreaseBet: _viewModel.increaseBet,
                onSpin: _viewModel.spin,
                onStopAutoSpin: _viewModel.stopAutoSpin,
              ),
              GameUtilityButtons(
                screenH: metrics.screenH,
                screenW: metrics.screenW,
                listenable: _viewModel,
                bigWinShowing: () => _isBigWinShowing,
                autoSpinning: () => _viewModel.isAutoSpinning,
                betAmount: () => _viewModel.betAmount,
                speedMultiplier: () => _viewModel.speedMultiplier,
                onInfoTap: _showGameRules,
                onSettingsTap: _showSystemSettings,
                onAutoSpinTap: _showAutoPlaySettings,
                onSpeedTap: _viewModel.toggleSpeed,
              ),
              GameBottomInfoSlot(
                balanceListenable: _viewModel.balanceCtrl,
                balance: () => _viewModel.balance,
                betAmount: () => _viewModel.betAmount,
                labelStyle: _styles.bottomLabel,
                valueStyle: _styles.bottomValue,
                clockStyle: _styles.bottomClock,
              ),
              if (_freeSpinAwardPresentation.showTransition)
                const Positioned.fill(child: FreeSpinScatterTransition()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSlotGrid() {
    return SlotGridView(
      columns: GameViewModel.columns,
      reelControllers: _reelControllers,
      previousGrid: _viewModel.previousGrid,
      grid: _viewModel.grid,
      isSpinning: _viewModel.isSpinning,
      fadingPaths: _viewModel.fadingPaths,
      clearedPositions: _viewModel.clearedPositions,
      speedMultiplier: _viewModel.speedMultiplier,
      soundEffectsEnabled: _viewModel.soundEffects,
      pulseScattersOnLanding: _viewModel.shouldPulseLandingScatters,
      scatterPulseTrigger: _freeSpinAwardPresentation.scatterPulseTrigger,
      onSpinComplete: _viewModel.onSpinComplete,
      onFirstDropInStart: _viewModel.clearMultiplierResidues,
    );
  }

  Widget _buildStatusText({
    required double screenH,
    required double screenW,
    required double gridLeft,
    required double gridRight,
  }) {
    return GameStatusText(
      showInsufficientFundsHint: _viewModel.showInsufficientFundsHint,
      isFreeSpinVisualMode: _isFreeSpinVisualMode,
      isTumbling: _viewModel.isTumbling,
      isBusy: _viewModel.isBusy,
      isAutoSpinning: _viewModel.isAutoSpinning,
      lastSpinWasFreeSpin: _viewModel.lastSpinWasFreeSpin,
      freeSpinAccumulatedWin: _freeSpinPresentation.accumulatedWin,
      liveTumbleWin: _viewModel.liveTumbleWin,
      lastWin: _viewModel.lastWin,
      result: _viewModel.lastSpinResult,
      winController: _winCtrl,
      screenH: screenH,
      screenW: screenW,
      gridLeft: gridLeft,
      gridRight: gridRight,
      baseStyle: _styles.statusBase,
      accentStyle: _styles.statusAccent,
      insufficientStyle: _styles.statusInsufficient,
      soundEnabled: _viewModel.soundEffects,
      vibrationEnabled: _viewModel.vibration,
      speedMultiplier: _viewModel.speedMultiplier,
      kazancAnchorKey: _kazancAnchorKey,
      onMultiplierLifted: _viewModel.gridCtrl.clearMultiplierPosition,
    );
  }

  Widget _buildTumbleWinSlot({
    required double screenH,
    required double screenW,
    required double gridLeft,
    required double gridRight,
  }) {
    return GameTumbleWinSlot(
      listenable: _listenables.tumbleWin,
      isFlyingTumble: () => _isFlyingTumble,
      isBusy: () => _viewModel.isBusy,
      liveTumbleWin: () => _viewModel.liveTumbleWin,
      lastWin: () => _viewModel.lastWin,
      result: () => _viewModel.lastSpinResult,
      controller: _winCtrl,
      anchorKey: _tumbleWinAnchorKey,
      labelStyle: _styles.statusAccent,
      valueStyle: _styles.statusBase,
      vibrationEnabled: () => _viewModel.vibration,
      soundEnabled: () => _viewModel.soundEffects,
      speedMultiplier: () => _viewModel.speedMultiplier,
      screenH: screenH,
      screenW: screenW,
      gridLeft: gridLeft,
      gridRight: gridRight,
      onMultiplierLifted: _viewModel.gridCtrl.clearMultiplierPosition,
    );
  }
}
