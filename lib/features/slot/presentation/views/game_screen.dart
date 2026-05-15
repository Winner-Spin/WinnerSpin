import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';

import '../../data/repositories/local_first_launch_disclaimer_repository.dart';
import '../../domain/models/cluster_win.dart';
import '../../domain/models/symbol_registry.dart';
import '../../domain/repositories/first_launch_disclaimer_repository.dart';
import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/buy_feature_button.dart';
import 'widgets/double_chance_button.dart';
import 'widgets/slot_reel.dart';
import 'widgets/respin_button.dart';
import 'widgets/minus_button.dart';
import 'widgets/plus_button.dart';
import 'widgets/pulsing_multiplier_sum.dart';
import 'widgets/auto_spin_button.dart';
import 'widgets/info_button.dart';
import 'widgets/settings_button.dart';
import 'widgets/speed_button.dart';
import 'widgets/spring_popup_card.dart';
import 'widgets/big_win_overlay.dart';
import 'widgets/floating_win_overlay.dart';
import 'widgets/first_launch_disclaimer_dialog.dart';
import 'widgets/flying_tumble_sprite.dart';
import 'widgets/footer_clock_text.dart';
import 'widgets/multiplier_label.dart';
import 'widgets/win_amount_counter.dart';
import 'widgets/win_presentation.dart';
import 'widgets/win_presentation_controller.dart';
import '../../../auth/presentation/views/login_screen.dart';
import 'auto_play_settings_screen.dart';
import 'buy_freespins_confirm_screen.dart';
import 'game_rules_screen.dart';
import 'system_settings_screen.dart';

const int _freeSpinPopupCacheWidth = 1024;

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
  OverlayEntry? _freeSpinWinPopupEntry;
  int _fsAwardedThisRound = 0;
  _PendingFreeSpinAward? _pendingFreeSpinAwardPopup;
  bool _freeSpinAwardSequenceActive = false;
  bool _fsSummaryPopupVisible = false;
  bool _deferInitialFreeSpinVisualMode = false;
  int _scatterPulseTrigger = 0;
  Timer? _scatterPulseTimer;

  bool _isFlyingTumble = false;

  double _lastSeenLastWinNormal = 0;

  bool _bigWinShownThisSpin = false;
  bool _isBigWinShowing = false;
  OverlayEntry? _bigWinEntry;
  Timer? _deferredPrecacheTimer;

  bool get _isFreeSpinVisualMode =>
      _viewModel.isInFreeSpins && !_deferInitialFreeSpinVisualMode;

  bool _celebrationLocked = false;

  bool get _isCelebrationActive {
    final phase = _winCtrl.phase;
    final winPresentationActive =
        phase != WinPresentationPhase.idle &&
        phase != WinPresentationPhase.done;
    return winPresentationActive || _bigWinEntry != null || _celebrationLocked;
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
      _precacheOpeningGridSymbols();
      _precacheMultiplierLabels();
      _precacheWinOverlayAssets();
      unawaited(_FreeSpinScatterTransitionState.precacheCupcakeImage());
      _scheduleDeferredSymbolPrecache();
      precacheImage(
        const AssetImage('lib/images/slot_main_screen/freespin arka plan.png'),
        context,
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

  void _precacheOpeningGridSymbols() {
    final openingPaths = <String>{
      for (final column in _viewModel.grid) ...column,
    };
    for (final path in openingPaths) {
      _precacheSymbol(path);
    }
  }

  void _scheduleDeferredSymbolPrecache() {
    final openingPaths = <String>{
      for (final column in _viewModel.grid) ...column,
    };
    final remainingPaths = SymbolRegistry.all
        .map((symbol) => symbol.assetPath)
        .where((path) => !openingPaths.contains(path))
        .toList(growable: false);

    _deferredPrecacheTimer?.cancel();
    _deferredPrecacheTimer = Timer(const Duration(milliseconds: 300), () {
      unawaited(_precacheSymbolsInBatches(remainingPaths));
    });
  }

  Future<void> _precacheSymbolsInBatches(List<String> paths) async {
    const batchSize = 3;
    for (var index = 0; index < paths.length; index += batchSize) {
      if (!mounted) return;
      final end = math.min(index + batchSize, paths.length);
      for (final path in paths.sublist(index, end)) {
        _precacheSymbol(path);
      }
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }
  }

  void _precacheSymbol(String path) {
    precacheImage(ResizeImage(AssetImage(path), width: 256), context);
  }

  void _precacheMultiplierLabels() {
    for (final path in MultiplierLabel.assetPaths) {
      precacheImage(ResizeImage(AssetImage(path), width: 384), context);
    }
  }

  void _precacheWinOverlayAssets() {
    for (final path in WinTier.assetPaths) {
      precacheImage(
        ResizeImage(AssetImage(path), width: BigWinOverlay.headlineCacheWidth),
        context,
      );
    }
    precacheImage(
      const ResizeImage(
        AssetImage(BigWinOverlay.amountBannerAssetPath),
        width: BigWinOverlay.amountBannerCacheWidth,
      ),
      context,
    );
    precacheImage(
      const ResizeImage(
        AssetImage(_FreeSpinWinPopupState.assetPath),
        width: _freeSpinPopupCacheWidth,
      ),
      context,
    );
    precacheImage(
      const ResizeImage(
        AssetImage(_FreeSpinSummaryPopupState.assetPath),
        width: _freeSpinPopupCacheWidth,
      ),
      context,
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
          return _buildSpringPopupTransition(anim, child);
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
    _pendingFreeSpinAwardPopup = _PendingFreeSpinAward(
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
    _freeSpinWinPopupEntry?.remove();
    _freeSpinWinPopupEntry = null;

    final overlay = _stageOverlayKey.currentState;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FreeSpinWinPopup(
        value: value,
        isRetrigger: isRetrigger,
        winAmount: winAmount,
        onDismiss: () {
          if (_freeSpinWinPopupEntry == entry) {
            _freeSpinWinPopupEntry = null;
          }
          entry.remove();
          _freeSpinAwardSequenceActive = false;
          _continueAutoSpinIfPresentationIdle();
        },
      ),
    );
    _freeSpinWinPopupEntry = entry;
    overlay.insert(entry);
  }

  void _showPendingFreeSpinAwardPopup() {
    final pending = _pendingFreeSpinAwardPopup;
    if (pending == null || _freeSpinWinPopupEntry != null) return;
    _pendingFreeSpinAwardPopup = null;
    _showFreeSpinAwardSequence(pending);
  }

  void _showFreeSpinAwardSequence(_PendingFreeSpinAward pending) {
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

  void _startInitialFreeSpinVisualTransition(_PendingFreeSpinAward pending) {
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

  List<_ScatterCell> _currentScatterCells() {
    final scatterPath = SymbolRegistry.all
        .firstWhere((s) => s.isScatter)
        .assetPath;
    final cells = <_ScatterCell>[];
    final grid = _viewModel.grid;

    for (var col = 0; col < grid.length; col++) {
      final column = grid[col];
      for (var row = 0; row < column.length; row++) {
        if (column[row] == scatterPath) {
          cells.add(_ScatterCell(column: col, row: row));
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

    _freeSpinWinPopupEntry?.remove();
    _freeSpinWinPopupEntry = null;
    _pendingFreeSpinAwardPopup = null;

    setState(() => _fsSummaryPopupVisible = true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _FreeSpinSummaryPopup(
        totalWin: _fsAccumulatedWin,
        totalFreeSpins: _fsAwardedThisRound,
        onDismiss: () {
          if (_freeSpinWinPopupEntry == entry) {
            _freeSpinWinPopupEntry = null;
          }
          entry.remove();
          if (!mounted) return;
          setState(() => _fsSummaryPopupVisible = false);
          _playFreeSpinExitTransitionThenRelease();
          _continueAutoSpinIfPresentationIdle();
        },
      ),
    );
    _freeSpinWinPopupEntry = entry;
    overlay.insert(entry);
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
        return _buildSpringPopupTransition(anim, child);
      },
    );
  }

  Widget _buildSpringPopupTransition(Animation<double> anim, Widget child) {
    final fade = CurvedAnimation(
      parent: anim,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(opacity: fade, child: child);
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
            _buildSpringPopupTransition(anim, child),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _viewModel.buyFreeSpins();
  }

  void _maybeShowBigWin(double amount) {
    if (!mounted) return;
    if (_bigWinShownThisSpin || _bigWinEntry != null) return;
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

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => BigWinOverlay(
        amount: amount,
        tier: tier,
        instantAmount: _viewModel.speedMultiplier >= 3,
        soundEnabled: _viewModel.soundEffects,
        vibrationEnabled: _viewModel.vibration,
        onComplete: () {
          if (_bigWinEntry == entry) {
            setState(() => _bigWinEntry = null);
            _releaseCelebrationLock();
          }
          entry.remove();
          if (mounted) setState(() => _isBigWinShowing = false);
        },
      ),
    );
    overlay.insert(entry);
    setState(() => _bigWinEntry = entry);
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
    _bigWinEntry?.remove();
    _bigWinEntry = null;
    _freeSpinWinPopupEntry?.remove();
    _freeSpinWinPopupEntry = null;
    _isBigWinShowing = false;
    _freeSpinTransitionTimer?.cancel();
    _scatterPulseTimer?.cancel();
    _deferredPrecacheTimer?.cancel();
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
    if (_bigWinEntry != null) {
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
        _freeSpinWinPopupEntry != null ||
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
                  final kazancBand = _buildStatusBand(
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
                                      return _buildSpringPopupTransition(
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
                              return _buildSpringPopupTransition(anim, child);
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
                  child: _buildBottomPanel(),
                ),
              ),
              if (_showFreeSpinTransition)
                const Positioned.fill(child: _FreeSpinScatterTransition()),
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
    final showOrchestrator =
        hasMultiplierSequence &&
        !_viewModel.isBusy &&
        _winCtrl.phase != WinPresentationPhase.done;

    return Stack(
      children: [
        Center(
          child: ListenableBuilder(
            listenable: _tumbleWinListenable,
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
            soundEnabled: _viewModel.soundEffects,
            speedMultiplier: _viewModel.speedMultiplier,
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
    if (_isFlyingTumble) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: MoneyText(
          text: formatMoney(0),
          style: _statusBaseStyle,
          symbolOffset: const Offset(0, 1.5),
          lineYOffset: 0.75,
          lineLengthScale: 0.94,
        ),
      );
    }

    if (_viewModel.isBusy) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: WinAmountCounter(
          to: _viewModel.liveTumbleWin,
          style: _statusBaseStyle,
          duration: const Duration(milliseconds: 350),
          vibrationEnabled: _viewModel.vibration,
        ),
      );
    }

    final result = _viewModel.lastSpinResult;
    if (result == null) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: MoneyText(
          text: formatMoney(_viewModel.lastWin),
          style: _statusBaseStyle,
          symbolOffset: const Offset(0, 1.5),
          lineYOffset: 0.75,
          lineLengthScale: 0.94,
        ),
      );
    }

    final hasSequence =
        result.baseWin > 0 && result.finalMultipliers.isNotEmpty;
    if (!hasSequence) {
      return Container(
        key: _tumbleWinAnchorKey,
        child: MoneyText(
          text: formatMoney(result.totalWin),
          style: _statusBaseStyle,
          symbolOffset: const Offset(0, 1.5),
          lineYOffset: 0.75,
          lineLengthScale: 0.94,
        ),
      );
    }

    switch (_winCtrl.phase) {
      case WinPresentationPhase.idle:
      case WinPresentationPhase.baseCounting:
        return Container(
          key: _tumbleWinAnchorKey,
          child: MoneyText(
            text: formatMoney(result.baseWin),
            style: _statusBaseStyle,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
          ),
        );

      case WinPresentationPhase.multiplierCollecting:
        final sum = _winCtrl.runningSum;
        final showMultiplySign = _winCtrl.multiplierFlightStarted;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            MoneyText(
              text: formatMoney(result.baseWin),
              style: _statusBaseStyle,
              symbolOffset: const Offset(0, 1.5),
              lineYOffset: 0.75,
              lineLengthScale: 0.94,
            ),
            if (showMultiplySign) ...[
              const SizedBox(width: 8),
              Text('×', style: _statusBaseStyle),
              const SizedBox(width: 6),
              Container(
                key: _tumbleWinAnchorKey,
                child: sum > 0
                    ? PulsingMultiplierSum(
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
        return Container(
          key: _tumbleWinAnchorKey,
          child: WinAmountCounter(
            from: _winCtrl.baseWin,
            to: result.totalWin,
            style: _statusBaseStyle,
            duration: WinPresentationController.finalCountUpDuration,
            vibrationEnabled: _viewModel.vibration,
          ),
        );

      case WinPresentationPhase.done:
        return Container(
          key: _tumbleWinAnchorKey,
          child: MoneyText(
            text: formatMoney(result.totalWin),
            style: _statusBaseStyle,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
          ),
        );
    }
  }

  Widget _buildFsInfoLine() {
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
          Text('${clusterToShow.positions.length}X', style: infoStyle),
          const SizedBox(width: 6),
          Image.asset(
            clusterToShow.assetPath,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 6),
          Text('PAYS', style: infoStyle),
          const SizedBox(width: 3),
          MoneyText(
            text: formatMoney(clusterToShow.amount),
            style: infoStyle,
            symbolOffset: const Offset(0, 1.5),
            lineYOffset: 0.75,
            lineLengthScale: 0.94,
            lineTopExtend: 0.9,
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
        Text('${_viewModel.freeSpinsRemaining}', style: infoStyle),
      ],
    );
  }

  Widget _buildBottomPanel() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListenableBuilder(
          listenable: _viewModel.balanceCtrl,
          builder: (context, _) => _buildBottomMoneyRow(),
        ),
        const SizedBox(height: 1),
        FooterClockText(style: _bottomClockStyle),
      ],
    );
  }

  Widget _buildBottomMoneyRow() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('CREDIT', style: _bottomLabelStyle),
          const SizedBox(width: 4),
          MoneyText(
            text: formatMoney(_viewModel.balance),
            style: _bottomValueStyle,
            symbolOffset: const Offset(0, 1.1),
            lineYOffset: 1.05,
            symbolTextYOffset: 0.45,
          ),
          const SizedBox(width: 16),
          Text('BET', style: _bottomLabelStyle),
          const SizedBox(width: 4),
          MoneyText(
            text: formatMoney(_viewModel.betAmount),
            style: _bottomValueStyle,
            symbolOffset: const Offset(0, 1.1),
            lineYOffset: 1.05,
            symbolTextYOffset: 0.45,
          ),
        ],
      ),
    );
  }
}

class _PendingFreeSpinAward {
  final int value;
  final bool isRetrigger;
  final double winAmount;

  const _PendingFreeSpinAward({
    required this.value,
    required this.isRetrigger,
    required this.winAmount,
  });
}

class _ScatterCell {
  final int column;
  final int row;

  const _ScatterCell({required this.column, required this.row});
}

class _FreeSpinWinPopup extends StatefulWidget {
  final int value;
  final bool isRetrigger;
  final double winAmount;
  final VoidCallback onDismiss;

  const _FreeSpinWinPopup({
    required this.value,
    required this.isRetrigger,
    required this.winAmount,
    required this.onDismiss,
  });

  @override
  State<_FreeSpinWinPopup> createState() => _FreeSpinWinPopupState();
}

class _FreeSpinWinPopupState extends State<_FreeSpinWinPopup>
    with SingleTickerProviderStateMixin {
  static const assetPath =
      'lib/images/slot_main_screen/WIN_ARTICLES/FreeSpinWin.png';

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.88;
    final valueOffset = Offset(0, width * 0.035);
    final valueFontSize = width * 0.16;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withValues(alpha: 0.36),
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(_scale),
            child: SizedBox(
              width: width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    assetPath,
                    width: width,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: _freeSpinPopupCacheWidth,
                  ),
                  Transform.translate(
                    offset: valueOffset,
                    child: Text(
                      '${widget.value}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: const Color(0xFFFFB72E),
                        shadows: [
                          Shadow(
                            color: const Color(
                              0xFF9C5A00,
                            ).withValues(alpha: 0.95),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: const Color(
                              0xFFFFF0A8,
                            ).withValues(alpha: 0.85),
                            offset: const Offset(0, -2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeSpinSummaryPopup extends StatefulWidget {
  final double totalWin;
  final int totalFreeSpins;
  final VoidCallback onDismiss;

  const _FreeSpinSummaryPopup({
    required this.totalWin,
    required this.totalFreeSpins,
    required this.onDismiss,
  });

  @override
  State<_FreeSpinSummaryPopup> createState() => _FreeSpinSummaryPopupState();
}

class _FreeSpinSummaryPopupState extends State<_FreeSpinSummaryPopup>
    with SingleTickerProviderStateMixin {
  static const assetPath =
      'lib/images/slot_main_screen/WIN_ARTICLES/xFreeSpinWin.png';

  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.88;
    final amountFontSize = width * 0.115;
    final spinFontSize = width * 0.060;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withValues(alpha: 0.36),
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(_scale),
            child: SizedBox(
              width: width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    assetPath,
                    width: width,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: _freeSpinPopupCacheWidth,
                  ),
                  Transform.translate(
                    offset: Offset(0, width * 0.025),
                    child: SizedBox(
                      width: width * 0.46,
                      height: width * 0.12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          text: formatMoney(widget.totalWin),
                          spacing: width * 0.007,
                          symbolOffset: Offset(0, width * 0.005),
                          lineYOffset: width * 0.009,
                          lineLengthScale: 0.96,
                          lineTopExtend: width * 0.004,
                          symbolTextYOffset: width * 0.006,
                          style: GoogleFonts.outfit(
                            fontSize: amountFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: const Color(0xFFFFD13B),
                            shadows: [
                              Shadow(
                                color: const Color(
                                  0xFF9C5A00,
                                ).withValues(alpha: 0.95),
                                offset: const Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(width * -0.14, width * 0.17),
                    child: SizedBox(
                      width: width * 0.11,
                      height: width * 0.07,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.totalFreeSpins}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: spinFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: const Color(0xFFFFD13B),
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.85),
                                offset: const Offset(0, 3),
                                blurRadius: 5,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FreeSpinScatterTransition extends StatefulWidget {
  const _FreeSpinScatterTransition();

  @override
  State<_FreeSpinScatterTransition> createState() =>
      _FreeSpinScatterTransitionState();
}

class _FreeSpinScatterTransitionState extends State<_FreeSpinScatterTransition>
    with SingleTickerProviderStateMixin {
  static const _cupcakeAssetPath =
      'lib/images/slot_main_screen/Items/cupCake.png';
  static const int _cupcakeCount = 420;
  static const double _cupcakeCellSize = 0.19;
  static ui.Image? _cachedCupcakeImage;
  static Future<ui.Image>? _cupcakeImageFuture;

  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;
  Size? _burstLayoutSize;
  late List<_CupcakeBurstParticle> _cupcakeParticles = const [];
  ui.Image? _cupcakeImage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
    _fade = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 18),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 27),
    ]).animate(_controller);
    _scale = Tween<double>(
      begin: 0.25,
      end: 1.45,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _rotation = Tween<double>(
      begin: -0.16,
      end: 0.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    unawaited(_resolveCupcakeImage());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static Future<ui.Image> precacheCupcakeImage() {
    final cached = _cachedCupcakeImage;
    if (cached != null) return Future.value(cached);
    return _cupcakeImageFuture ??= _loadCupcakeImage().then((image) {
      _cachedCupcakeImage = image;
      return image;
    });
  }

  static Future<ui.Image> _loadCupcakeImage() async {
    final data = await rootBundle.load(_cupcakeAssetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  Future<void> _resolveCupcakeImage() async {
    final image = await precacheCupcakeImage();
    if (!mounted) return;
    setState(() => _cupcakeImage = image);
  }

  void _ensureCupcakeBurstLayout(Size size) {
    if (_burstLayoutSize == size) return;
    double noise(int seed) {
      final raw = math.sin(seed * 12.9898) * 43758.5453;
      return raw - raw.floorToDouble();
    }

    final particles = <_CupcakeBurstParticle>[];

    for (int index = 0; index < _cupcakeCount; index++) {
      final t = index / _cupcakeCount;
      final angleBase = index * 2.399963229728653;
      final angle = angleBase + (noise(index * 7 + 3) - 0.5) * 1.15;
      final radius = math.sqrt(t) * (0.95 + noise(index * 11 + 5) * 0.58);
      final aspect = size.height / size.width;
      final x =
          math.cos(angle) * radius * 0.88 +
          (noise(index * 13 + 7) - 0.5) * 0.26;
      final y =
          math.sin(angle) * radius * 0.88 / aspect +
          (noise(index * 17 + 9) - 0.5) * 0.26;
      final sizeVar = _cupcakeCellSize + noise(index * 19 + 11) * 0.13;
      final rotation = (noise(index * 23 + 13) - 0.5) * 1.8;
      final delay = (radius * 0.22 + noise(index * 29 + 15) * 0.12).clamp(
        0.0,
        0.28,
      );
      final width = size.width * sizeVar;

      particles.add(
        _CupcakeBurstParticle(
          left: size.width * (0.5 + x) - (width / 2),
          top: size.height * (0.46 + y) - (width / 2),
          driftX: (noise(index * 31 + 17) - 0.5) * 95,
          driftY: -85 - noise(index * 37 + 19) * 95,
          rotation: rotation,
          delay: delay,
          width: width,
        ),
      );
    }

    _burstLayoutSize = size;
    _cupcakeParticles = particles;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size =
              constraints.hasBoundedWidth && constraints.hasBoundedHeight
              ? constraints.biggest
              : MediaQuery.sizeOf(context);
          _ensureCupcakeBurstLayout(size);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Opacity(
                opacity: _fade.value,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.38),
                  child: CustomPaint(
                    size: size,
                    painter: _CupcakeBurstPainter(
                      particles: _cupcakeParticles,
                      image: _cupcakeImage,
                      progress: _controller.value,
                      scale: _scale.value.clamp(0.9, 1.22),
                      rotation: _rotation.value,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CupcakeBurstParticle {
  final double left;
  final double top;
  final double driftX;
  final double driftY;
  final double rotation;
  final double delay;
  final double width;

  const _CupcakeBurstParticle({
    required this.left,
    required this.top,
    required this.driftX,
    required this.driftY,
    required this.rotation,
    required this.delay,
    required this.width,
  });
}

class _CupcakeBurstPainter extends CustomPainter {
  final List<_CupcakeBurstParticle> particles;
  final ui.Image? image;
  final double progress;
  final double scale;
  final double rotation;

  const _CupcakeBurstPainter({
    required this.particles,
    required this.image,
    required this.progress,
    required this.scale,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cupcake = image;
    if (cupcake == null) return;

    final source = Rect.fromLTWH(
      0,
      0,
      cupcake.width.toDouble(),
      cupcake.height.toDouble(),
    );
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..isAntiAlias = true;

    for (final particle in particles) {
      final localProgress = ((progress - particle.delay) / 0.52).clamp(
        0.0,
        1.0,
      );
      final pop = Curves.easeOutBack.transform(localProgress);
      final drift = Curves.easeOutCubic.transform(localProgress);
      final drawScale = (0.34 + pop * 0.84) * scale;
      final center = Offset(
        particle.left + particle.width / 2 + particle.driftX * (1 - drift),
        particle.top + particle.width / 2 + particle.driftY * (1 - drift),
      );
      final target = Rect.fromCenter(
        center: Offset.zero,
        width: particle.width,
        height: particle.width,
      );

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(particle.rotation + rotation);
      canvas.scale(drawScale);
      canvas.drawImageRect(cupcake, source, target, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CupcakeBurstPainter oldDelegate) {
    return oldDelegate.particles != particles ||
        oldDelegate.image != image ||
        oldDelegate.progress != progress ||
        oldDelegate.scale != scale ||
        oldDelegate.rotation != rotation;
  }
}
