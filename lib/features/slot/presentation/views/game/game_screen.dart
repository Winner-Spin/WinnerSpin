import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../../audio/ui_click_sound.dart';
import '../../ui_controllers/big_win_presentation_controller.dart';
import '../../ui_controllers/flying_tumble_overlay_controller.dart';
import '../../ui_controllers/free_spin_auto_play_controller.dart';
import '../../ui_controllers/free_spin_award_sequence_controller.dart';
import '../../ui_controllers/free_spin_overlay_controller.dart';
import '../../ui_controllers/lingering_cluster_controller.dart';
import '../../models/big_win_presentation_rules.dart';
import '../../models/free_spin_award_presentation_state.dart';
import '../../models/free_spin_presentation_state.dart';
import '../../models/game_presentation_guards.dart';
import '../../models/game_presentation_timings.dart';
import '../../models/game_screen_listener_registry.dart';
import '../../models/game_screen_listenables.dart';
import '../../models/game_stage_metrics.dart';
import '../../models/game_screen_text_styles.dart';
import '../../models/spin_result_presentation_rules.dart';
import '../../navigation/game_screen_navigation.dart';
import '../../services/game_asset_precache_service.dart';
import '../../services/game_screen_startup_service.dart';
import '../../services/scatter_cell_finder.dart';
import '../../viewmodels/game_viewmodel.dart';
import '../../ui_controllers/win_presentation_controller.dart';
import 'widgets/presentation/free_spins/free_spin_scatter_transition.dart';
import 'widgets/layout/game_background.dart';
import 'widgets/layout/game_free_spin_info_slot.dart';
import 'widgets/layout/game_stage_control_overlay.dart';
import 'widgets/layout/game_status_bands.dart';
import 'widgets/presentation/win/game_status_text.dart';
import 'widgets/presentation/win/game_tumble_win_slot.dart';
import 'widgets/playfield/slot_grid_view.dart';
import 'widgets/playfield/slot_playfield.dart';
import 'widgets/playfield/slot_reel_controller.dart';

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
  final BigWinPresentationController _bigWinPresentationController =
      BigWinPresentationController();
  final FreeSpinOverlayController _freeSpinOverlayController =
      FreeSpinOverlayController();
  final FlyingTumbleOverlayController _flyingTumbleOverlayController =
      FlyingTumbleOverlayController();
  final FreeSpinAutoPlayController _freeSpinAutoPlayController =
      FreeSpinAutoPlayController();
  final FreeSpinAwardSequenceController _freeSpinAwardSequenceController =
      FreeSpinAwardSequenceController();
  final LingeringClusterController _lingeringClusterController =
      LingeringClusterController();
  final GameAssetPrecacheService _assetPrecacheService =
      GameAssetPrecacheService();
  final GameScreenStartupService _startupService =
      const GameScreenStartupService();

  final GlobalKey _tumbleWinAnchorKey = GlobalKey();

  bool _wasBusy = false;
  bool _wasLoading = true;

  Timer? _celebrationLockWatchdog;

  final FreeSpinPresentationState _freeSpinPresentation =
      FreeSpinPresentationState();
  WinPresentationPhase _lastWinCtrlPhase = WinPresentationPhase.idle;

  final GlobalKey _kazancAnchorKey = GlobalKey();

  final GlobalKey<OverlayState> _stageOverlayKey = GlobalKey<OverlayState>();

  late final List<SlotReelController> _reelControllers;

  final FreeSpinAwardPresentationState _freeSpinAwardPresentation =
      FreeSpinAwardPresentationState();

  bool _isFlyingTumble = false;

  bool get _isFreeSpinVisualMode =>
      _freeSpinAwardPresentation.isVisualMode(_viewModel.isInFreeSpins);

  int get _displayedFreeSpinsRemaining => _freeSpinAwardPresentation
      .displayedRemaining(_viewModel.freeSpinsRemaining);

  bool _celebrationLocked = false;

  bool get _isCelebrationActive {
    final phase = _winCtrl.phase;
    final winPresentationActive =
        phase != WinPresentationPhase.idle &&
        phase != WinPresentationPhase.done;
    return winPresentationActive ||
        _bigWinPresentationController.hasActiveOverlay ||
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
    final loadingCompleted = _wasLoading && !_viewModel.isLoading;
    _wasLoading = _viewModel.isLoading;
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
    if (loadingCompleted) {
      _continueAutoSpinIfPresentationIdle();
    }
  }

  void _onFreeSpinStateChange() {
    final isInFreeSpins = _viewModel.isInFreeSpins;
    final wasInFreeSpins = _freeSpinAwardPresentation.wasInFreeSpins;
    final result = _viewModel.lastSpinResult;
    final isRestoredRound = _freeSpinAwardPresentation.isRestoredRoundEntry(
      isInFreeSpins: isInFreeSpins,
      result: result,
    );
    final recoveredPending = _viewModel.takeRecoveredFreeSpinAward();
    final pending =
        recoveredPending ??
        _freeSpinAwardPresentation.takeAwardForFreeSpinState(
          isInFreeSpins: isInFreeSpins,
          result: result,
        );
    if (pending != null) {
      _freeSpinAutoPlayController.pauseForAwardAcknowledgement();
      _freeSpinAwardSequenceController.startAwardTransition(
        pending: pending,
        freeSpinPresentation: _freeSpinPresentation,
        awardPresentation: _freeSpinAwardPresentation,
        setState: setState,
        awardAlreadyApplied: recoveredPending != null,
      );
      if (recoveredPending != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showPendingFreeSpinAwardPopup();
        });
      }
    }
    if (isInFreeSpins && !wasInFreeSpins) {
      unawaited(_assetPrecacheService.precacheFreeSpinSummary(context));
    } else if (!isInFreeSpins && wasInFreeSpins) {
      _assetPrecacheService.evictFreeSpinSummary();
    }
    _freeSpinAwardPresentation.updateFreeSpinMode(isInFreeSpins);
    if (isRestoredRound) {
      _continueAutoSpinIfPresentationIdle();
    }
  }

  void _quickStopReels() {
    if (!_viewModel.isSpinning || _viewModel.isTumbling) return;
    for (final controller in _reelControllers) {
      controller.quickStop();
    }
  }

  void _showPendingFreeSpinAwardPopup() {
    _freeSpinAwardSequenceController.showPendingAwardPopup(
      awardPresentation: _freeSpinAwardPresentation,
      overlayController: _freeSpinOverlayController,
      overlay: _stageOverlayKey.currentState,
      scatterCells: ScatterCellFinder.findInGrid(_viewModel.grid),
      isMounted: () => mounted,
      setState: setState,
      continueAutoSpinIfIdle: _onFreeSpinAwardAcknowledged,
    );
  }

  void _onFreeSpinAwardAcknowledged() {
    _viewModel.acknowledgePendingFreeSpinAward();
    _freeSpinAutoPlayController.acknowledgeAward();
    _continueAutoSpinIfPresentationIdle();
  }

  void _showFreeSpinSummaryPopup() {
    _freeSpinAwardSequenceController.showSummaryPopup(
      freeSpinPresentation: _freeSpinPresentation,
      awardPresentation: _freeSpinAwardPresentation,
      overlayController: _freeSpinOverlayController,
      overlay: _stageOverlayKey.currentState,
      isMounted: () => mounted,
      setState: setState,
      releaseFsRoundHold: _viewModel.releaseFsRoundHold,
      continueAutoSpinIfIdle: _continueAutoSpinIfPresentationIdle,
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
    _bigWinPresentationController.trackNormalWin(
      isInFreeSpins: _viewModel.isInFreeSpins,
      lastWin: _viewModel.lastWin,
      result: () => _viewModel.lastSpinResult,
      isMounted: () => mounted,
      showBigWin: _maybeShowBigWin,
    );
  }

  Future<void> _promptBuyFreeSpinsConfirm() async {
    final canPrompt = GamePresentationGuards.canPromptBuyFreeSpins(
      anteBetActive: _viewModel.anteBetActive,
      bigWinShowing: _bigWinPresentationController.isShowing,
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
    _bigWinPresentationController.maybeShow(
      amount: amount,
      betAmount: _viewModel.betAmount,
      isBusy: _viewModel.isBusy,
      overlay: _stageOverlayKey.currentState,
      speedMultiplier: _viewModel.speedMultiplier,
      soundEnabled: _viewModel.soundEffects,
      vibrationEnabled: _viewModel.vibration,
      isMounted: () => mounted,
      setState: setState,
      onComplete: _releaseCelebrationLock,
    );
  }

  void _trackSpinTransitions() {
    final isBusy = _viewModel.isBusy;
    if (isBusy && !_wasBusy) {
      _commitPendingFsWin();
      _winCtrl.reset();
      _bigWinPresentationController.resetForNewSpin();
      if (_celebrationLocked) {
        setState(() => _celebrationLocked = false);
      }
      _celebrationLockWatchdog?.cancel();
      _celebrationLockWatchdog = null;
      _lingeringClusterController.clearForNewSpin(
        isMounted: () => mounted,
        setState: setState,
      );
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
        if (_viewModel.lastSpinResult == null) {
          _freeSpinPresentation.restoreRound(
            accumulatedWin: _viewModel.freeSpinAccumulatedWin,
            awarded: _viewModel.freeSpinsAwardedThisRound,
          );
          _freeSpinPresentation.updateLastSeenWin(_viewModel.lastWin);
        } else {
          _freeSpinPresentation.resetRound();
        }
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
    _lingeringClusterController.track(
      activeExplosions: _viewModel.activeExplosions,
      isTumbling: _viewModel.isTumbling,
      isMounted: () => mounted,
      setState: setState,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _freeSpinAutoPlayController.cancelPending();
        _viewModel.onAppLifecycleEvent();
      case AppLifecycleState.resumed:
        _viewModel.onAppResumed();
        unawaited(_validateSessionAfterResume());
        break;
    }
  }

  Future<void> _validateSessionAfterResume() async {
    final isSessionActive = await _viewModel.validateSessionOnResume();
    if (!mounted || !isSessionActive) return;
    _continueAutoSpinIfPresentationIdle();
  }

  @override
  void dispose() {
    _bigWinPresentationController.dispose();
    _freeSpinOverlayController.dispose();
    _flyingTumbleOverlayController.dispose();
    _freeSpinAutoPlayController.dispose();
    _freeSpinAwardSequenceController.dispose();
    _lingeringClusterController.dispose();
    _assetPrecacheService.dispose();
    _celebrationLockWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _listenerRegistry.detach();
    _winCtrl.dispose();
    _viewModel.dispose();
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

    if (_bigWinPresentationController.shownThisSpin) {
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
    if (_bigWinPresentationController.hasActiveOverlay) {
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
    if (_viewModel.isLoading) return;
    if (!_isSpinPresentationIdle()) return;

    if (_viewModel.isInFreeSpins) {
      if (_viewModel.freeSpinsRemaining <= 0) return;
      _freeSpinAutoPlayController.continueIfReady(
        canStart: _canStartAutomaticFreeSpin,
        spin: () => unawaited(_viewModel.spin()),
      );
      return;
    }

    _freeSpinAutoPlayController.cancelPending();
    _viewModel.continueAutoSpinIfReady();
  }

  bool _canStartAutomaticFreeSpin() {
    return mounted &&
        !_viewModel.isLoading &&
        _viewModel.isInFreeSpins &&
        _viewModel.freeSpinsRemaining > 0 &&
        !_viewModel.isBusy &&
        _isSpinPresentationIdle();
  }

  bool _isSpinPresentationIdle() {
    return GamePresentationGuards.shouldContinueAutoSpin(
      celebrationActive: _isCelebrationActive,
      freeSpinAwardSequenceActive: _freeSpinAwardPresentation.sequenceActive,
      hasPendingFreeSpinAward: _freeSpinAwardPresentation.hasPendingPopup,
      scatterPulseActive: _freeSpinAwardSequenceController.scatterPulseActive,
      hasActiveFreeSpinOverlay: _freeSpinOverlayController.hasActiveOverlay,
      showFreeSpinTransition: _freeSpinAwardPresentation.showTransition,
      fsSummaryPopupVisible: _freeSpinAwardPresentation.summaryPopupVisible,
    );
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
          absorbing: _bigWinPresentationController.isShowing,
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
                  lingeringCluster: () => _lingeringClusterController.cluster,
                  freeSpinsRemaining: () => _displayedFreeSpinsRemaining,
                  style: _styles.statusBase.copyWith(fontSize: 16),
                ),
              ),
              GameStageControlOverlay(
                metrics: metrics,
                viewModel: _viewModel,
                listenables: _listenables,
                styles: _styles,
                isFreeSpinVisualMode: () => _isFreeSpinVisualMode,
                displayedFreeSpinsRemaining: () => _displayedFreeSpinsRemaining,
                isBigWinShowing: () => _bigWinPresentationController.isShowing,
                isCelebrationActive: () => _isCelebrationActive,
                onBuyFeatureTap: _promptBuyFreeSpinsConfirm,
                onInfoTap: _showGameRules,
                onSettingsTap: _showSystemSettings,
                onAutoSpinTap: _showAutoPlaySettings,
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
