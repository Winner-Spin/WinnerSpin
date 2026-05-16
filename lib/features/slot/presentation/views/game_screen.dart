import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';

import '../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../domain/models/cluster_win.dart';
import '../../domain/models/symbol_registry.dart';
import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../audio/ui_click_sound.dart';
import '../controllers/big_win_overlay_controller.dart';
import '../controllers/free_spin_overlay_controller.dart';
import '../models/pending_free_spin_award.dart';
import '../models/scatter_cell.dart';
import '../services/game_asset_precache_service.dart';
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
import 'widgets/spring_popup_card.dart';
import 'widgets/spring_popup_transition.dart';
import 'widgets/status_band.dart';
import 'widgets/big_win_overlay.dart';
import 'widgets/floating_win_overlay.dart';
import 'widgets/first_launch_disclaimer_dialog.dart';
import 'widgets/free_spin_info_line.dart';
import 'widgets/free_spin_scatter_transition.dart';
import 'widgets/flying_tumble_sprite.dart';
import 'widgets/game_bottom_panel.dart';
import 'widgets/tumble_win_line.dart';
import 'widgets/win_amount_counter.dart';
import 'widgets/win_presentation.dart';
import 'widgets/win_presentation_controller.dart';
import '../../../auth/presentation/views/login_screen.dart';
import 'auto_play_settings_screen.dart';
import 'buy_freespins_confirm_screen.dart';
import 'game_rules_screen.dart';
import 'system_settings_screen.dart';

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

  late final TextStyle _statusBaseStyle;
  late final TextStyle _statusKazancStyle;
  late final TextStyle _statusInsufficientStyle;
  late final TextStyle _bottomLabelStyle;
  late final TextStyle _bottomValueStyle;
  late final TextStyle _bottomClockStyle;

  late final Listenable _freeSpinVisualListenable;
  late final Listenable _gridVisualListenable;
  late final Listenable _balanceStatusListenable;
  late final Listenable _fsInfoListenable;
  late final Listenable _buyFeatureListenable;
  late final Listenable _anteToggleListenable;
  late final Listenable _spinControlsListenable;
  late final Listenable _tumbleWinListenable;

  @override
  void initState() {
    super.initState();
    _reelControllers = List.generate(
      GameViewModel.columns,
      (_) => SlotReelController(),
    );
    _freeSpinVisualListenable = Listenable.merge([
      _viewModel,
      _viewModel.fsCtrl,
    ]);
    _gridVisualListenable = Listenable.merge([_viewModel, _viewModel.gridCtrl]);
    _balanceStatusListenable = Listenable.merge([
      _viewModel,
      _viewModel.balanceCtrl,
    ]);
    _fsInfoListenable = Listenable.merge([
      _viewModel,
      _viewModel.fsCtrl,
      _viewModel.gridCtrl,
    ]);
    _buyFeatureListenable = Listenable.merge([
      _viewModel,
      _viewModel.balanceCtrl,
      _viewModel.anteCtrl,
      _viewModel.fsCtrl,
    ]);
    _anteToggleListenable = Listenable.merge([
      _viewModel,
      _viewModel.anteCtrl,
      _viewModel.balanceCtrl,
      _viewModel.fsCtrl,
    ]);
    _spinControlsListenable = Listenable.merge([
      _viewModel,
      _viewModel.balanceCtrl,
      _viewModel.fsCtrl,
      _winCtrl,
    ]);
    _tumbleWinListenable = Listenable.merge([
      _viewModel,
      _viewModel.balanceCtrl,
      _viewModel.gridCtrl,
      _winCtrl,
    ]);
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
      unawaited(_maybeShowFirstLaunchDisclaimer());
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

  Future<void> _maybeShowFirstLaunchDisclaimer() async {
    try {
      if (await _firstLaunchDisclaimerRepository.hasSeenDisclaimer()) return;
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        barrierLabel: 'Disclaimer',
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, _, child) => FirstLaunchDisclaimerDialog(
          onOkay: () async {
            UiClickSound.play();
            await _firstLaunchDisclaimerRepository.markDisclaimerSeen();
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        transitionBuilder: (context, anim, _, child) {
          return buildSpringPopupTransition(anim, child);
        },
      );
    } catch (_) {}
  }

  void _onViewModelChange() {
    UiClickSound.enabled = _viewModel.soundEffects;
    _handleLogout(context);
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
    final scatterPath = SymbolRegistry.all
        .firstWhere((s) => s.isScatter)
        .assetPath;
    final cells = <ScatterCell>[];
    final grid = _viewModel.grid;

    for (var col = 0; col < grid.length; col++) {
      final column = grid[col];
      for (var row = 0; row < column.length; row++) {
        if (column[row] == scatterPath) {
          cells.add(ScatterCell(column: col, row: row));
        }
      }
    }

    return cells;
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

  void _showAutoPlaySettings(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Auto Play Settings',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          AutoPlaySettingsScreen(viewModel: _viewModel),
      transitionBuilder: (context, anim, _, child) {
        return buildSpringPopupTransition(anim, child);
      },
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
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (_, _, _) => BuyFreeSpinsConfirmScreen(
          spinCount: 10,
          price: _viewModel.buyFeaturePrice,
        ),
        transitionsBuilder: (_, anim, _, child) =>
            buildSpringPopupTransition(anim, child),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
    if (!mounted || confirmed != true) return;
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
          style: _statusBaseStyle,
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
        final double screenH = constraints.maxHeight;
        final double screenW = constraints.maxWidth;

        const double bgAspect = 1408 / 3040;
        const double bgInnerLeftRatio = 88 / 1408;
        const double bgInnerRightRatio = 1319 / 1408;

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

        return AbsorbPointer(
          absorbing: _isBigWinShowing,
          child: Stack(
            children: [
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _freeSpinVisualListenable,
                  builder: (context, _) {
                    final bgPath = _isFreeSpinVisualMode
                        ? 'lib/images/slot_main_screen/freespin arka plan.png'
                        : 'lib/images/slot_main_screen/nihai arka plan.png';
                    return RepaintBoundary(
                      child: Image.asset(
                        bgPath,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.4),
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
                        listenable: _gridVisualListenable,
                        builder: (context, _) => _buildSlotGrid(),
                      ),
                    ),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: _viewModel.gridCtrl,
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
                listenable: _freeSpinVisualListenable,
                builder: (context, _) {
                  final isFs = _isFreeSpinVisualMode;
                  const bandHeight = 31.0;
                  const wideGap = 31.0;
                  const infoTop = bandHeight;
                  const kazancTop = infoTop + bandHeight + wideGap;
                  const fsTotalHeight = kazancTop + bandHeight;
                  final totalHeight = isFs ? fsTotalHeight : bandHeight;
                  final kazancBand = StatusBand(
                    child: ListenableBuilder(
                      listenable: _balanceStatusListenable,
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
                            child: StatusBand(
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
                            child: StatusBand(
                              child: ListenableBuilder(
                                listenable: _fsInfoListenable,
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
                  listenable: _buyFeatureListenable,
                  builder: (context, _) {
                    if (_isFreeSpinVisualMode) {
                      return const SizedBox.shrink();
                    }
                    final betButtonPassive =
                        _isBigWinShowing ||
                        _viewModel.isBusy ||
                        _isCelebrationActive;
                    return RepaintBoundary(
                      child: BuyFeatureButton(
                        price: _viewModel.buyFeaturePrice,
                        disabled:
                            _viewModel.anteBetActive ||
                            betButtonPassive ||
                            !_viewModel.canBuyFreeSpinsForUi,
                        vibrationEnabled: _viewModel.vibration,
                        onTap: () {
                          _promptBuyFreeSpinsConfirm();
                        },
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
                  listenable: _anteToggleListenable,
                  builder: (context, _) {
                    if (_isFreeSpinVisualMode) {
                      return const SizedBox.shrink();
                    }
                    return RepaintBoundary(
                      child: DoubleChanceButton(
                        betAmount: _viewModel.anteCost,
                        isOn: _viewModel.anteBetActive,
                        disabled:
                            _isBigWinShowing ||
                            _viewModel.isBusy ||
                            _viewModel.isAutoSpinning ||
                            _viewModel.isInFreeSpins,
                        vibrationEnabled: _viewModel.vibration,
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
                child: ListenableBuilder(
                  listenable: _spinControlsListenable,
                  builder: (context, _) {
                    final autoActive = _viewModel.isAutoSpinning;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!autoActive) ...[
                          RepaintBoundary(
                            child: MinusButton(
                              size: 42,
                              onTap: _viewModel.decreaseBet,
                              disabled:
                                  _isBigWinShowing ||
                                  !_viewModel.canDecreaseBet ||
                                  _viewModel.isInFreeSpins,
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        RepaintBoundary(
                          child: RespinButton(
                            size: 84,
                            onTap: autoActive
                                ? _viewModel.stopAutoSpin
                                : _viewModel.spin,
                            spinning: _viewModel.isBusy || _isCelebrationActive,
                            disabled: _isBigWinShowing,
                            autoSpinsRemaining: autoActive
                                ? _viewModel.autoSpinsRemaining
                                : null,
                          ),
                        ),
                        if (!autoActive) ...[
                          const SizedBox(width: 16),
                          RepaintBoundary(
                            child: PlusButton(
                              size: 42,
                              onTap: _viewModel.increaseBet,
                              disabled:
                                  _isBigWinShowing ||
                                  !_viewModel.canIncreaseBet ||
                                  _viewModel.isInFreeSpins,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: 0,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => InfoButton(
                    betAmount: _viewModel.betAmount,
                    onTap: _isBigWinShowing
                        ? null
                        : () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                opaque: false,
                                barrierDismissible: true,
                                pageBuilder: (context, animation, child) =>
                                    GameRulesScreen(
                                      betAmount: _viewModel.betAmount,
                                    ),
                                transitionsBuilder:
                                    (context, anim, animation, child) {
                                      return buildSpringPopupTransition(
                                        anim,
                                        child,
                                      );
                                    },
                                transitionDuration: const Duration(
                                  milliseconds: 280,
                                ),
                                reverseTransitionDuration: const Duration(
                                  milliseconds: 220,
                                ),
                              ),
                            );
                          },
                  ),
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                right: 0,
                child: SettingsButton(
                  onTap: _isBigWinShowing
                      ? null
                      : () {
                          showGeneralDialog(
                            context: context,
                            barrierColor: Colors.transparent,
                            barrierDismissible: true,
                            barrierLabel: 'Settings',
                            transitionDuration: const Duration(
                              milliseconds: 280,
                            ),
                            pageBuilder: (context, _, child) =>
                                SystemSettingsScreen(viewModel: _viewModel),
                            transitionBuilder: (context, anim, _, child) {
                              return buildSpringPopupTransition(anim, child);
                            },
                          );
                        },
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: screenW * 0.30,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => AutoSpinButton(
                    onTap: _isBigWinShowing || _viewModel.isAutoSpinning
                        ? null
                        : () => _showAutoPlaySettings(context),
                  ),
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: screenW * 0.5 + 42,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => SpeedButton(
                    level: _viewModel.speedMultiplier,
                    onTap: _isBigWinShowing ? null : _viewModel.toggleSpeed,
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
                  child: GameBottomPanel(
                    balanceListenable: _viewModel.balanceCtrl,
                    balance: () => _viewModel.balance,
                    betAmount: () => _viewModel.betAmount,
                    labelStyle: _bottomLabelStyle,
                    valueStyle: _bottomValueStyle,
                    clockStyle: _bottomClockStyle,
                  ),
                ),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: List.generate(GameViewModel.columns, (col) {
          return Expanded(
            child: RepaintBoundary(
              child: SlotReel(
                columnIndex: col,
                controller: _reelControllers[col],
                previousItems: _viewModel.previousGrid[col],
                targetItems: _viewModel.grid[col],
                spinning: _viewModel.isSpinning,
                fadingPaths: _viewModel.fadingPaths,
                clearedPositions: _viewModel.clearedPositions,
                speedMultiplier: _viewModel.speedMultiplier,
                soundEffectsEnabled: _viewModel.soundEffects,
                pulseScattersOnLanding: _viewModel.shouldPulseLandingScatters,
                scatterPulseTrigger: _scatterPulseTrigger,
                onComplete: col == GameViewModel.columns - 1
                    ? () => _viewModel.onSpinComplete()
                    : null,
                onDropInStart: col == 0
                    ? () => _viewModel.clearMultiplierResidues()
                    : null,
              ),
            ),
          );
        }),
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
    final isFs = _isFreeSpinVisualMode;

    if (_viewModel.showInsufficientFundsHint) {
      return Text('PLEASE DEPOSIT MONEY!', style: _statusInsufficientStyle);
    }

    if (isFs) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('WIN', style: _statusKazancStyle),
          const SizedBox(width: 6),
          Container(
            key: _kazancAnchorKey,
            child: WinAmountCounter(
              to: _fsAccumulatedWin,
              style: _statusBaseStyle,
              duration: const Duration(milliseconds: 700),
              vibrationEnabled: _viewModel.vibration,
            ),
          ),
        ],
      );
    }

    if (isTumbling && liveWin > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('WIN', style: _statusKazancStyle),
          const SizedBox(width: 6),
          WinAmountCounter(
            to: liveWin,
            style: _statusBaseStyle,
            duration: const Duration(milliseconds: 900),
            vibrationEnabled: _viewModel.vibration,
          ),
        ],
      );
    }

    if (lastWin > 0 && !isBusy) {
      final result = _viewModel.lastSpinResult;
      final hasMultiplierSequence =
          result != null &&
          result.baseWin > 0 &&
          result.finalMultipliers.isNotEmpty &&
          !(_viewModel.lastSpinWasFreeSpin && !_isFreeSpinVisualMode);

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
          soundEnabled: _viewModel.soundEffects,
          vibrationEnabled: _viewModel.vibration,
          speedMultiplier: _viewModel.speedMultiplier,
          onMultiplierLifted: (col, row) {
            _viewModel.gridCtrl.clearMultiplierPosition(col, row);
          },
        );
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('WIN', style: _statusKazancStyle),
          const SizedBox(width: 6),
          MoneyText(
            text: formatMoney(lastWin),
            style: _statusBaseStyle,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
          ),
        ],
      );
    }

    if (isBusy || _viewModel.isAutoSpinning) {
      return Text('GOOD LUCK!', style: _statusBaseStyle);
    }

    return Text('PLACE YOUR BETS!', style: _statusBaseStyle);
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
    final showOrchestrator =
        hasMultiplierSequence &&
        !_viewModel.isBusy &&
        _winCtrl.phase != WinPresentationPhase.done;

    return Stack(
      children: [
        Center(
          child: ListenableBuilder(
            listenable: _tumbleWinListenable,
            builder: (context, _) => TumbleWinLine(
              isFlyingTumble: _isFlyingTumble,
              isBusy: _viewModel.isBusy,
              liveTumbleWin: _viewModel.liveTumbleWin,
              lastWin: _viewModel.lastWin,
              result: _viewModel.lastSpinResult,
              controller: _winCtrl,
              anchorKey: _tumbleWinAnchorKey,
              labelStyle: _statusKazancStyle,
              valueStyle: _statusBaseStyle,
              vibrationEnabled: _viewModel.vibration,
            ),
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
            soundEnabled: _viewModel.soundEffects,
            speedMultiplier: _viewModel.speedMultiplier,
            onMultiplierLifted: (col, row) {
              _viewModel.gridCtrl.clearMultiplierPosition(col, row);
            },
          ),
      ],
    );
  }

  Widget _buildFsInfoLine() {
    final infoStyle = _statusBaseStyle.copyWith(fontSize: 16);
    final activeExplosions = _viewModel.activeExplosions;
    final ClusterWin? clusterToShow = activeExplosions.isNotEmpty
        ? activeExplosions.reduce((a, b) => a.amount >= b.amount ? a : b)
        : _lingeringCluster;

    return FreeSpinInfoLine(
      cluster: clusterToShow,
      freeSpinsRemaining: _viewModel.freeSpinsRemaining,
      style: infoStyle,
    );
  }

}


