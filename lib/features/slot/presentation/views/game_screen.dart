import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../domain/models/cluster_win.dart';
import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../audio/ui_click_sound.dart';
import '../controllers/big_win_overlay_controller.dart';
import '../controllers/free_spin_overlay_controller.dart';
import '../models/game_screen_listenables.dart';
import '../models/game_stage_metrics.dart';
import '../models/game_screen_text_styles.dart';
import '../models/pending_free_spin_award.dart';
import '../models/scatter_cell.dart';
import '../navigation/game_screen_navigation.dart';
import '../services/game_asset_precache_service.dart';
import '../services/scatter_cell_finder.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/slot_reel.dart';
import 'widgets/game_utility_buttons.dart';
import 'widgets/game_feature_controls.dart';
import 'widgets/big_win_overlay.dart';
import 'widgets/free_spin_scatter_transition.dart';
import 'widgets/flying_tumble_sprite.dart';
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
  final GameAssetPrecacheService _assetPrecacheService =
      GameAssetPrecacheService();

  final GlobalKey _tumbleWinAnchorKey = GlobalKey();

  ClusterWin? _lingeringCluster;
  bool _wasBusy = false;

  bool _wasTumbling = false;
  Timer? _lingeringClusterTimer;

  Timer? _celebrationLockWatchdog;
  static const Duration _celebrationLockMaxHold = Duration(seconds: 20);

  double _fsAccumulatedWin = 0;
  double _lastSeenLastWin = 0;
  bool _wasInFs = false;

  double _pendingFsSpinWin = 0;
  WinPresentationPhase _lastWinCtrlPhase = WinPresentationPhase.idle;

  final GlobalKey _kazancAnchorKey = GlobalKey();

  final GlobalKey<OverlayState> _stageOverlayKey = GlobalKey<OverlayState>();

  late final List<SlotReelController> _reelControllers;

  bool _wasInFreeSpins = false;
  bool _showFreeSpinTransition = false;
  Object? _lastFreeSpinAwardPopupResult;
  Timer? _freeSpinTransitionTimer;
  int _fsAwardedThisRound = 0;
  PendingFreeSpinAward? _pendingFreeSpinAwardPopup;
  bool _freeSpinAwardSequenceActive = false;
  bool _fsSummaryPopupVisible = false;
  bool _deferInitialFreeSpinVisualMode = false;
  int _scatterPulseTrigger = 0;
  Timer? _scatterPulseTimer;

  bool _isFlyingTumble = false;

  double _lastSeenLastWinNormal = 0;

  bool _bigWinShownThisSpin = false;
  bool _isBigWinShowing = false;

  bool get _isFreeSpinVisualMode =>
      _viewModel.isInFreeSpins && !_deferInitialFreeSpinVisualMode;

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
    WidgetsBinding.instance.addObserver(this);
    UiClickSound.enabled = _viewModel.soundEffects;
    unawaited(UiClickSound.preload());
    _viewModel.addListener(_onViewModelChange);
    _viewModel.balanceCtrl.addListener(_onViewModelChange);
    _viewModel.gridCtrl.addListener(_onViewModelChange);
    _viewModel.fsCtrl.addListener(_onViewModelChange);
    _viewModel.fsCtrl.addListener(_onFreeSpinStateChange);
    _viewModel.addListener(_onFreeSpinStateChange);
    _winCtrl.addListener(_onWinCtrlChange);
    _viewModel.fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _assetPrecacheService.precacheInitialAssets(
        context: context,
        openingGrid: _viewModel.grid,
        isMounted: () => mounted,
      );
      unawaited(
        GameScreenNavigation.maybeShowFirstLaunchDisclaimer(
          context: context,
          repository: _firstLaunchDisclaimerRepository,
        ),
      );
    });
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
    final result = _viewModel.lastSpinResult;
    final isNewAward =
        result != null &&
        result.freeSpinsTriggered &&
        !identical(result, _lastFreeSpinAwardPopupResult);

    if (isInFreeSpins && !_wasInFreeSpins) {
      _lastFreeSpinAwardPopupResult = result;
      final isRetrigger = result?.isRetrigger == true;
      _startFreeSpinAwardTransition(
        isRetrigger ? 5 : 10,
        isRetrigger: isRetrigger,
        winAmount: result?.totalWin ?? 0,
      );
    } else if (isInFreeSpins && isNewAward && result.isRetrigger) {
      _lastFreeSpinAwardPopupResult = result;
      _startFreeSpinAwardTransition(
        5,
        isRetrigger: true,
        winAmount: result.totalWin,
      );
    }
    _wasInFreeSpins = isInFreeSpins;
  }

  void _startFreeSpinAwardTransition(
    int popupValue, {
    required bool isRetrigger,
    double winAmount = 0,
  }) {
    _freeSpinTransitionTimer?.cancel();
    _fsAwardedThisRound = isRetrigger
        ? _fsAwardedThisRound + popupValue
        : popupValue;

    setState(() {
      if (isRetrigger) {
        _showFreeSpinTransition = false;
      } else {
        _deferInitialFreeSpinVisualMode = true;
      }
    });
    _pendingFreeSpinAwardPopup = PendingFreeSpinAward(
      value: popupValue,
      isRetrigger: isRetrigger,
      winAmount: winAmount,
    );
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
        _freeSpinAwardSequenceActive = false;
        _continueAutoSpinIfPresentationIdle();
      },
    );
  }

  void _showPendingFreeSpinAwardPopup() {
    final pending = _pendingFreeSpinAwardPopup;
    if (pending == null || _freeSpinOverlayController.hasActiveOverlay) return;
    _pendingFreeSpinAwardPopup = null;
    _showFreeSpinAwardSequence(pending);
  }

  void _showFreeSpinAwardSequence(PendingFreeSpinAward pending) {
    _freeSpinAwardSequenceActive = true;
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
    setState(() => _showFreeSpinTransition = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !_showFreeSpinTransition) return;
      setState(() => _deferInitialFreeSpinVisualMode = false);
    });
    _freeSpinTransitionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showFreeSpinTransition = false);
      _showFreeSpinWinPopup(
        value: pending.value,
        isRetrigger: pending.isRetrigger,
        winAmount: pending.winAmount,
      );
    });
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
    setState(() => _scatterPulseTrigger++);
    _scatterPulseTimer = Timer(const Duration(milliseconds: 1050), () {
      if (!mounted) return;
      setState(() => _scatterPulseTrigger = 0);
      onComplete();
    });
  }

  List<ScatterCell> _currentScatterCells() {
    return ScatterCellFinder.findInGrid(_viewModel.grid);
  }

  void _showFreeSpinSummaryPopup() {
    if (_fsSummaryPopupVisible) return;
    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) {
      _playFreeSpinExitTransitionThenRelease();
      return;
    }

    _freeSpinOverlayController.clear();
    _pendingFreeSpinAwardPopup = null;

    setState(() => _fsSummaryPopupVisible = true);
    _freeSpinOverlayController.showSummaryPopup(
      overlay: overlay,
      totalWin: _fsAccumulatedWin,
      totalFreeSpins: _fsAwardedThisRound,
      cacheWidth: GameAssetPrecacheService.freeSpinPopupCacheWidth,
      onDismiss: () {
        if (!mounted) return;
        setState(() => _fsSummaryPopupVisible = false);
        _playFreeSpinExitTransitionThenRelease();
        _continueAutoSpinIfPresentationIdle();
      },
    );
  }

  void _playFreeSpinExitTransitionThenRelease() {
    _freeSpinTransitionTimer?.cancel();
    setState(() => _showFreeSpinTransition = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted || !_showFreeSpinTransition) return;
      _viewModel.releaseFsRoundHold();
    });
    _freeSpinTransitionTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _showFreeSpinTransition = false);
      _continueAutoSpinIfPresentationIdle();
    });
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
        final hasSequence =
            result != null &&
            result.baseWin > 0 &&
            result.finalMultipliers.isNotEmpty;
        if (!hasSequence) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) _maybeShowBigWin(lastWin);
          });
        }
      });
    }
    _lastSeenLastWinNormal = lastWin;
  }

  Future<void> _promptBuyFreeSpinsConfirm() async {
    if (_viewModel.anteBetActive ||
        _isBigWinShowing ||
        _viewModel.isBusy ||
        _isCelebrationActive ||
        !_viewModel.canBuyFreeSpinsForUi) {
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
    if (bet <= 0) return;
    final tier = WinTier.forMultiplier(amount / bet);
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
      _celebrationLockWatchdog = Timer(_celebrationLockMaxHold, () {
        if (!mounted) return;
        if (_celebrationLocked) {
          _releaseCelebrationLock();
        }
      });
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence =
            result != null &&
            result.baseWin > 0 &&
            result.finalMultipliers.isNotEmpty;
        final hasBigWin =
            result != null &&
            !_viewModel.isCurrentSpinFromBuy &&
            result.totalWin > 0 &&
            _viewModel.betAmount > 0 &&
            WinTier.forMultiplier(result.totalWin / _viewModel.betAmount) !=
                null;
        final hasFsFlight =
            _viewModel.isInFreeSpins &&
            !_viewModel.isCurrentSpinFromBuy &&
            result != null &&
            result.totalWin > 0;
        if (!hasSequence && !hasBigWin && !hasFsFlight) {
          _releaseCelebrationLock();
        }
      });
    }
    _wasBusy = isBusy;
  }

  void _trackFsAccumulator() {
    final isInFs = _viewModel.isInFreeSpins;
    if (isInFs && !_wasInFs) {
      setState(() {
        _fsAccumulatedWin = 0;
        _pendingFsSpinWin = 0;
        _fsAwardedThisRound = 0;
        _fsSummaryPopupVisible = false;
      });
    }
    _wasInFs = isInFs;

    if (!isInFs) return;

    final lastWin = _viewModel.lastWin;
    if (lastWin > 0 && _lastSeenLastWin == 0) {
      if (_viewModel.isCurrentSpinFromBuy) {
        setState(() => _fsAccumulatedWin = lastWin);
      } else {
        setState(() => _pendingFsSpinWin = lastWin);
        Future.microtask(() {
          if (!mounted) return;
          final result = _viewModel.lastSpinResult;
          final hasSequence =
              result != null &&
              result.baseWin > 0 &&
              result.finalMultipliers.isNotEmpty;
          if (!hasSequence) {
            Future.delayed(const Duration(milliseconds: 600), () {
              if (mounted) {
                _maybeShowBigWin(lastWin);
                _commitPendingFsWin();
              }
            });
          }
        });
      }
    }
    _lastSeenLastWin = lastWin;
  }

  void _trackLingeringCluster() {
    final activeExplosions = _viewModel.activeExplosions;
    final isTumbling = _viewModel.isTumbling;

    if (activeExplosions.isNotEmpty) {
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = null;
      final best = activeExplosions.reduce(
        (a, b) => a.amount >= b.amount ? a : b,
      );
      if (!identical(_lingeringCluster, best)) {
        setState(() => _lingeringCluster = best);
      }
    } else if (_wasTumbling && !isTumbling && _lingeringCluster != null) {
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _lingeringCluster = null);
      });
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
    _isBigWinShowing = false;
    _freeSpinTransitionTimer?.cancel();
    _scatterPulseTimer?.cancel();
    _assetPrecacheService.dispose();
    _lingeringClusterTimer?.cancel();
    _celebrationLockWatchdog?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChange);
    _viewModel.balanceCtrl.removeListener(_onViewModelChange);
    _viewModel.gridCtrl.removeListener(_onViewModelChange);
    _viewModel.fsCtrl.removeListener(_onViewModelChange);
    _viewModel.fsCtrl.removeListener(_onFreeSpinStateChange);
    _viewModel.removeListener(_onFreeSpinStateChange);
    _winCtrl.removeListener(_onWinCtrlChange);
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
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _commitPendingFsWin();
          });
        }
      } else {
        _releaseCelebrationLock();
      }
    }
    _lastWinCtrlPhase = phase;
  }

  void _commitPendingFsWin() {
    if (_pendingFsSpinWin <= 0) return;
    final amount = _pendingFsSpinWin;

    if (_bigWinShownThisSpin) {
      setState(() {
        _fsAccumulatedWin += amount;
        _pendingFsSpinWin = 0;
      });
      return;
    }

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
        _releaseLockAfterFsCountUp();
        return;
      }
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) => FlyingTumbleSprite(
          amount: amount,
          start: startCenter,
          end: endCenter,
          style: _styles.statusBase,
          duration: const Duration(milliseconds: 700),
          onComplete: () {
            entry.remove();
            if (!mounted) return;
            setState(() {
              _isFlyingTumble = false;
              _fsAccumulatedWin += amount;
            });
            Future.delayed(const Duration(milliseconds: 700), () {
              if (!mounted) return;
              _releaseCelebrationLock();
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
      setState(() {
        _fsAccumulatedWin += amount;
        _pendingFsSpinWin = 0;
      });
      _releaseLockAfterFsCountUp();
    }
  }

  void _releaseLockAfterFsCountUp() {
    Future.delayed(const Duration(milliseconds: 700), () {
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
    if (_isCelebrationActive ||
        _freeSpinAwardSequenceActive ||
        _pendingFreeSpinAwardPopup != null ||
        _scatterPulseTimer?.isActive == true ||
        _freeSpinOverlayController.hasActiveOverlay ||
        _showFreeSpinTransition ||
        _fsSummaryPopupVisible) {
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
              if (_showFreeSpinTransition)
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
      scatterPulseTrigger: _scatterPulseTrigger,
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
      freeSpinAccumulatedWin: _fsAccumulatedWin,
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


