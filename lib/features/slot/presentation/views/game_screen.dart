import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';

import '../../domain/models/cluster_win.dart';
import '../../domain/models/symbol_registry.dart';
import '../audio/ui_click_sound.dart';
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
import 'widgets/big_win_overlay.dart';
import 'widgets/floating_win_overlay.dart';
import 'widgets/win_amount_counter.dart';
import 'widgets/win_presentation.dart';
import 'widgets/win_presentation_controller.dart';
import '../../../auth/presentation/views/login_screen.dart';
import 'auto_play_settings_screen.dart';
import 'buy_freespins_confirm_screen.dart';
import 'deposit_money_screen.dart';
import 'game_rules_screen.dart';
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

  // Tracks the cascade tumbling flag so the lingering cluster pay
  // line can auto-clear after the cascade fully ends — gives the
  // last cluster's payout a brief beat on screen before the FS info
  // row flips back to FREE SPINS LEFT.
  bool _wasTumbling = false;
  Timer? _lingeringClusterTimer;

  // Safety net for the celebration lock. The post-spin sequence has
  // multiple async hand-offs (multiplier collect → flight → count-up
  // → big-win overlay) that each release the lock when they finish.
  // If a single hand-off hangs (e.g. an animation callback never
  // fires), the lock would otherwise stay raised forever and freeze
  // the respin button. The watchdog force-releases the lock and
  // commits any deferred FS state if no path released it within a
  // generous upper bound.
  Timer? _celebrationLockWatchdog;
  static const Duration _celebrationLockMaxHold = Duration(seconds: 20);

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
  bool _depositPromptShowing = false;
  bool _depositPromptShownForCurrentHint = false;

  // Per-column reel controllers so a screen tap can interrupt an
  // in-flight spin and snap each reel to its landing position.
  late final List<SlotReelController> _reelControllers;

  // FS-entry transition state — when the round flips to FS we briefly
  // overlay a scatter burst + "FREE SPINS" headline so the player
  // sees a distinct entry moment instead of an instant backdrop swap.
  bool _wasInFreeSpins = false;
  bool _showFreeSpinTransition = false;
  Object? _lastFreeSpinAwardPopupResult;
  Timer? _freeSpinTransitionTimer;
  OverlayEntry? _freeSpinWinPopupEntry;
  int _fsAwardedThisRound = 0;
  _PendingFreeSpinAward? _pendingFreeSpinAwardPopup;
  bool _fsSummaryPopupVisible = false;
  bool _deferInitialFreeSpinVisualMode = false;
  int _scatterPulseTrigger = 0;
  Timer? _scatterPulseTimer;

  // True while the tumble-win sprite is in flight toward the Kazanç
  // readout. The middle band drops to zero for the duration so the
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
  bool _isBigWinShowing = false;
  OverlayEntry? _bigWinEntry;

  bool get _isFreeSpinVisualMode =>
      _viewModel.isInFreeSpins && !_deferInitialFreeSpinVisualMode;

  // Optimistic lock raised the instant the cascade ends, before the
  // multiplier collect sequence has actually entered its first phase.
  // Without it, a single frame slips through where isBusy is false
  // but the controller is still idle — long enough for the respin
  // button to flash active before the sequence locks it again. The
  // lock clears automatically the moment a microtask confirms the
  // spin won't trigger a celebration, and otherwise stays raised
  // until the controller reaches [WinPresentationPhase.done].
  bool _celebrationLocked = false;

  // True while either the multiplier collect sequence is mid-flight or
  // the big-win celebration overlay is on screen. The respin button
  // stays locked through both phases so the player can't trigger a
  // fresh reel before the previous spin's celebration has resolved.
  bool get _isCelebrationActive {
    final phase = _winCtrl.phase;
    final winPresentationActive =
        phase != WinPresentationPhase.idle &&
        phase != WinPresentationPhase.done;
    return winPresentationActive || _bigWinEntry != null || _celebrationLocked;
  }

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
    _reelControllers = List.generate(
      GameViewModel.columns,
      (_) => SlotReelController(),
    );
    WidgetsBinding.instance.addObserver(this);
    UiClickSound.enabled = _viewModel.soundEffects;
    unawaited(UiClickSound.preload());
    _viewModel.addListener(_onViewModelChange);
    // The ViewModel itself doesn't notify after `awardWin` — that
    // path only fires on the balance controller. Listen there too so
    // the lastWin → FS-accumulator hand-off doesn't get missed.
    _viewModel.balanceCtrl.addListener(_onViewModelChange);
    _viewModel.gridCtrl.addListener(_onViewModelChange);
    // The Buy CTA's trigger spin flips the FS state on the FS counter
    // (not the viewmodel itself), so the lastWin → FS-accumulator
    // hand-off would otherwise miss its window — listen on the FS
    // controller too so the FS flight queues the moment the round
    // gets awarded mid-cascade.
    _viewModel.fsCtrl.addListener(_onViewModelChange);
    _viewModel.fsCtrl.addListener(_onFreeSpinStateChange);
    // `isInFreeSpins` also reflects the viewmodel's round-hold flag,
    // which only emits notifications on the viewmodel itself. Without
    // this listener, `_wasInFreeSpins` would stall on the previous
    // round's hold being cleared (viewmodel-only notify) and a
    // subsequent buy-trigger awarding FS would see `_wasInFreeSpins`
    // still true — skipping the cupcake-burst transition.
    _viewModel.addListener(_onFreeSpinStateChange);
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
      precacheImage(
        const AssetImage(
          'lib/images/slot_main_screen/WIN_ARTICLES/FreeSpinWin.png',
        ),
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

  Future<File> _firstLaunchDisclaimerFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/first_launch_disclaimer_seen.txt');
  }

  Future<void> _maybeShowFirstLaunchDisclaimer() async {
    try {
      final file = await _firstLaunchDisclaimerFile();
      if (await file.exists()) return;
      if (!mounted) return;
      await showGeneralDialog<void>(
        context: context,
        barrierColor: Colors.transparent,
        barrierDismissible: false,
        barrierLabel: 'Disclaimer',
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, _, child) => _FirstLaunchDisclaimerDialog(
          onOkay: () async {
            UiClickSound.play();
            await file.writeAsString('seen');
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
        transitionBuilder: (context, anim, _, child) {
          return _buildSpringPopupTransition(anim, child);
        },
      );
    } catch (_) {
      // If local persistence is unavailable, avoid blocking gameplay.
    }
  }

  void _onViewModelChange() {
    UiClickSound.enabled = _viewModel.soundEffects;
    _handleLogout(context);
    _maybeShowDepositMoneyPrompt();
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
      // Reset the trigger so the next spin doesn't re-wrap scatter cells
      // in _ScatterPulse (which would auto-start even with 1–2 cupcakes).
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

  void _maybeShowDepositMoneyPrompt() {
    if (!_viewModel.showInsufficientFundsHint) {
      _depositPromptShownForCurrentHint = false;
      return;
    }
    if (_depositPromptShowing || _depositPromptShownForCurrentHint) return;
    _depositPromptShownForCurrentHint = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showDepositMoneyDialog();
    });
  }

  Future<void> _showDepositMoneyDialog() async {
    if (!mounted || _depositPromptShowing) return;
    _depositPromptShowing = true;
    await showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Deposit Money',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          DepositMoneyScreen(viewModel: _viewModel),
      transitionBuilder: (context, anim, _, child) {
        return _buildSpringPopupTransition(anim, child);
      },
    );
    _depositPromptShowing = false;
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
      // The viewmodel sets `_lastSpinResult` a couple of lines after
      // the awardWin notify, so defer the multiplier-sequence check
      // until that assignment has run.
      Future.microtask(() {
        if (!mounted) return;
        final result = _viewModel.lastSpinResult;
        final hasSequence =
            result != null &&
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

  /// Pops a confirmation overlay over the slot screen instead of
  /// charging the Buy FS fee on first tap — keeps the player from
  /// dropping ₺10k on a stray press. Confirming runs the actual
  /// buy; cancelling just closes the dialog.
  Future<void> _promptBuyFreeSpinsConfirm() async {
    if (_viewModel.anteBetActive ||
        _isBigWinShowing ||
        _viewModel.isBusy ||
        _isCelebrationActive ||
        _viewModel.isAutoSpinning ||
        _viewModel.isInFreeSpins) {
      return;
    }
    if (!_viewModel.balanceCtrl.canAffordDisplayed(
      _viewModel.buyFeaturePrice,
    )) {
      await _showDepositMoneyDialog();
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
        // Turbo speed skips the count-up the same way the tap path
        // does so big-win celebrations stay compact on the fastest
        // pacing setting.
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
      // Drop the previous spin's lock state without touching the FS
      // consume — the consume for THIS spin was just queued by spin()
      // and must wait for this spin's own celebration to settle. The
      // viewmodel's own _pendingFsConsume flag stays set on the new
      // spin; the unlock just clears local screen state.
      if (_celebrationLocked) {
        setState(() => _celebrationLocked = false);
      }
      // A pending watchdog from the previous spin would otherwise stay
      // armed across the new spin's setup — cancel it so the next
      // cascade end gets a fresh timer rather than racing the stale
      // one for the unlock callback.
      _celebrationLockWatchdog?.cancel();
      _celebrationLockWatchdog = null;
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = null;
      if (_lingeringCluster != null) {
        setState(() => _lingeringCluster = null);
      }
    }
    if (!isBusy && _wasBusy) {
      // Cascade just ended — raise the lock optimistically so the
      // respin button doesn't flash active in the single frame
      // between isBusy flipping false and the controller entering
      // its first phase. A microtask defers the sequence-prediction
      // check until after the viewmodel finishes assigning
      // [lastSpinResult], at which point we unlock immediately when
      // there's nothing to celebrate.
      setState(() => _celebrationLocked = true);
      _celebrationLockWatchdog?.cancel();
      _celebrationLockWatchdog = Timer(_celebrationLockMaxHold, () {
        if (!mounted) return;
        if (_celebrationLocked) {
          // No release path fired in time — clear everything so the
          // respin button can re-arm. Indicates a hung animation
          // callback worth investigating further.
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
        // FS rounds always run the TUMBLE WIN → Kazanç flight + the
        // top-row count-up after every winning spin, so the lock must
        // hold past phase=done until the count-up settles. Buy-trigger
        // spins are the exception: their payout folds directly into
        // KazanÃ§ so the FS-entry burst stays unobstructed and the first
        // real free spin can be started immediately.
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
      // Fresh free-spin round — start the accumulator from scratch.
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
        // Buy CTA's trigger spin: skip the TUMBLE WIN → Kazanç flight
        // entirely. The FS-entry cupcake burst overlay would otherwise
        // be covered by the flight sprite mid-animation (the flight
        // overlay sits above the burst in the stage stack), and the
        // burst is the player's main visual cue that the round has
        // started. Folding the payout straight into the round-total
        // readout lets the burst play uninterrupted and unlocks the
        // respin button immediately for the first real FS spin.
        setState(() => _fsAccumulatedWin = lastWin);
      } else {
        setState(() => _pendingFsSpinWin = lastWin);
        // The viewmodel notifies via balanceCtrl from inside awardWin,
        // but the new `lastSpinResult` is assigned a couple of lines
        // later — reading it synchronously here would still see the
        // previous spin's data. A microtask defers the hasSequence
        // check until that assignment has run.
        Future.microtask(() {
          if (!mounted) return;
          final result = _viewModel.lastSpinResult;
          final hasSequence =
              result != null &&
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
    }
    _lastSeenLastWin = lastWin;
  }

  void _trackLingeringCluster() {
    final activeExplosions = _viewModel.activeExplosions;
    final isTumbling = _viewModel.isTumbling;

    if (activeExplosions.isNotEmpty) {
      // Active cluster on screen — kill any pending auto-clear so the
      // hold timer doesn't fire while a fresh cluster is being shown.
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = null;
      final best = activeExplosions.reduce(
        (a, b) => a.amount >= b.amount ? a : b,
      );
      if (!identical(_lingeringCluster, best)) {
        setState(() => _lingeringCluster = best);
      }
    } else if (_wasTumbling && !isTumbling && _lingeringCluster != null) {
      // Cascade just finished — let the final cluster's payout linger
      // for a beat, then flip the FS info row back to FREE SPINS LEFT
      // and commit the FS counter consume so the displayed remaining
      // count updates the instant the cluster pay line steps off
      // (the FS chrome itself stays through the rest of the
      // celebration via the round-hold flag).
      _lingeringClusterTimer?.cancel();
      _lingeringClusterTimer = Timer(const Duration(seconds: 1), () {
        if (!mounted) return;
        setState(() => _lingeringCluster = null);
        _viewModel.commitPendingFsConsume();
      });
    }
    _wasTumbling = isTumbling;
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
    _freeSpinWinPopupEntry?.remove();
    _freeSpinWinPopupEntry = null;
    _isBigWinShowing = false;
    _freeSpinTransitionTimer?.cancel();
    _scatterPulseTimer?.cancel();
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
        if (_viewModel.isCurrentSpinFromBuy) {
          _releaseCelebrationLock();
        } else {
          // FS round: the TUMBLE WIN → Kazanç flight (and the top-row
          // count-up that follows it) is still to come. Leave
          // _celebrationLocked raised — the flight's onComplete handler
          // releases it after the count-up settles.
          Future.delayed(const Duration(milliseconds: 600), () {
            if (mounted) _commitPendingFsWin();
          });
        }
      } else {
        // Normal round: no flight follows, so the lock can drop the
        // instant the final count-up reaches its target. The big-win
        // overlay (if running) still keeps it locked through its own
        // _bigWinEntry check.
        _releaseCelebrationLock();
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
    // positions before the layout flips — once the band drops to zero
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
        _releaseLockAfterFsCountUp();
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
            // The Kazanç counter now spends ~700ms chasing the new
            // total. Hold the respin button locked until that
            // count-up settles so the player can read the round
            // total before triggering the next reel.
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
      // Layout missing — fall back to a plain accumulator commit so
      // the spin's value isn't lost if the anchors haven't laid out.
      setState(() {
        _fsAccumulatedWin += amount;
        _pendingFsSpinWin = 0;
      });
      _releaseLockAfterFsCountUp();
    }
  }

  /// Releases [_celebrationLocked] once the Kazanç counter has had
  /// enough time to chase the new accumulator total. Used by the FS
  /// fallback paths where the value is folded in directly (no flying
  /// sprite carries the lock release on its own onComplete).
  void _releaseLockAfterFsCountUp() {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      _releaseCelebrationLock();
    });
  }

  /// Drops [_celebrationLocked], commits any deferred FS counter
  /// consume left over from the spin (catch-up path for spins without
  /// a tumble cascade), and releases the FS round-hold so
  /// [isInFreeSpins] falls back to the raw active-counter check. The
  /// hold release is what actually flips the chrome off the screen on
  /// the last FS spin — by deferring it until every celebration
  /// timeline has unwound the FS UI never tears down mid-sequence.
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

        // The backdrop is BoxFit.cover'd — when the screen aspect
        // doesn't match the source aspect, the image gets horizontally
        // cropped/extended. Compute the inner grid frame's actual
        // on-screen position so the slot grid lands on the bg's own
        // cell boundaries regardless of device aspect.
        const double bgAspect = 1408 / 3040;
        const double bgInnerLeftRatio = 88 / 1408; // bg's inner-frame left edge
        const double bgInnerRightRatio =
            1319 / 1408; // bg's inner-frame right edge

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
                // Backdrop swaps to the FS-mode artwork while a free-spin
                // round is active, so the round's distinct atmosphere is
                // visible the moment FS starts.
                child: ListenableBuilder(
                  listenable: Listenable.merge([_viewModel, _viewModel.fsCtrl]),
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
                listenable: Listenable.merge([_viewModel, _viewModel.fsCtrl]),
                builder: (context, _) {
                  // In free-spin rounds the strip splits into three
                  // black bands of the original height: top hosts the
                  // per-spin TUMBLE WIN counter, the FREE SPINS LEFT
                  // / cluster info line sits flush beneath it, and
                  // the round Kazanç readout sits at the bottom past
                  // a transparent gap.
                  final isFs = _isFreeSpinVisualMode;
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
                top: screenH * 0.565,
                left: screenW * 0.08,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                    _viewModel.anteCtrl,
                    _viewModel.fsCtrl,
                  ]),
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
                            _viewModel.isAutoSpinning ||
                            _viewModel.isInFreeSpins,
                        dimmed: !_viewModel.balanceCtrl.canAffordDisplayed(
                          _viewModel.buyFeaturePrice,
                        ),
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
                top: screenH * 0.565,
                right: screenW * 0.08,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.anteCtrl,
                    _viewModel.balanceCtrl,
                    _viewModel.fsCtrl,
                  ]),
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
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                    _viewModel.fsCtrl,
                    _winCtrl,
                  ]),
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
                            // Hold the spinning state past plain isBusy so the
                            // manual respin button stays locked through the
                            // entire post-spin celebration choreography
                            // (multiplier collect, middle-row count-up, FS
                            // flight, round-total count-up). Auto-spin's
                            // stop tap is exempted inside RespinButton, so
                            // the player can always abort an active autoplay
                            // run even while a celebration is on screen.
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
                top: screenH * 0.885,
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
                top: screenH * 0.885,
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
                top: screenH * 0.885,
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
                top: screenH * 0.885,
                left: screenW * 0.5 + 34,
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
                  // Bottom panel only reads balance + bet — no need to
                  // rebuild on unrelated _viewModel notifications.
                  child: ListenableBuilder(
                    listenable: _viewModel.balanceCtrl,
                    builder: (context, _) => _buildBottomPanel(screenW),
                  ),
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
            // Per-column RepaintBoundary so a reel's drop animation
            // doesn't invalidate sibling columns or the grid frame.
            child: RepaintBoundary(
              child: SlotReel(
                columnIndex: col,
                controller: _reelControllers[col],
                // Pass column lists by reference; List.generate
                // here was producing fresh refs every rebuild.
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

      // Non-multiplier win — value already showed live during the
      // cascade, so the counter just holds at [lastWin] without
      // re-animating from zero.
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
    final showOrchestrator =
        hasMultiplierSequence &&
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
    // While the spin's win is mid-flight up to the Kazanç readout the
    // middle band drops to zero — once the sprite lands the flag flips
    // back and the multiplied total restores in place.
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
        // Hold at the cluster total while the multiplier collect is
        // about to start — the formula appears once the first sprite
        // lifts off.
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
        // Live formula — `base × runningSum`. Multipliers fly into
        // the running-sum slot and the integer pops on each landing,
        // matching the previous Kazanç-bar behaviour.
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
            vibrationEnabled: _viewModel.vibration,
          ),
        );

      case WinPresentationPhase.done:
        // Multiplied total parks here statically — also what the
        // middle band falls back to after the flight lands so the
        // value isn't wiped out.
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
        ),
        const SizedBox(height: 1),
        _ClockText(style: _bottomClockStyle),
      ],
    );
  }
}

class _FirstLaunchDisclaimerDialog extends StatelessWidget {
  final VoidCallback onOkay;

  const _FirstLaunchDisclaimerDialog({required this.onOkay});

  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _textColor = Color(0xFF2C2530);
  static const String _bodyText =
      'This project is created solely for entertainment and portfolio purposes. It does not offer real-money gambling, betting, cash prizes, or withdrawal services. All coins, spins, bonuses, and rewards included in this project are entirely virtual; they have no real-world monetary value and cannot be purchased, sold, or converted into money in any way. This project does not promote or encourage gambling or betting activities.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.42)),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: SpringPopupCard(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.92,
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _panelColor,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Column(
                              children: [
                                _buildHeader(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      24,
                                      22,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          _bodyText,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _textColor,
                                            height: 1.18,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        _buildOkayButton(),
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
                  ),
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF6D7EB),
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Center(
        child: Text(
          'DISCLAIMER',
          style: GoogleFonts.barlowCondensed(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildOkayButton() {
    return GestureDetector(
      onTap: onOkay,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF00C76A),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          'OKAY',
          style: GoogleFonts.barlowCondensed(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
      ),
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
                    child: MoneyText(
                      text: formatMoney(widget.amount),
                      style: widget.style,
                      symbolOffset: const Offset(0, 1.5),
                      lineYOffset: 0.75,
                      lineLengthScale: 0.94,
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

  const _PulsingMultiplierSum({required this.value, required this.style});

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
        tween: Tween<double>(
          begin: 1.0,
          end: 1.5,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.5,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
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
  static const _initialAssetPath =
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
    // Always use FreeSpinWin.png — both initial trigger and retrigger.
    const assetPath = _initialAssetPath;
    // Centre offset for the spin-count circle (purple area).
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
                  ),
                  // Show the awarded free-spin count in the purple centre area.
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
  static const _assetPath =
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
                    _assetPath,
                    width: width,
                    filterQuality: FilterQuality.medium,
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

/// Brief celebration overlay that plays on the first frame of a
/// free-spin round — a scatter burst of cupcakes erupts around the
/// playfield while a "FREE SPINS" headline scales in from below.
/// Lasts 1.5s and dismisses itself.
class _FreeSpinScatterTransition extends StatefulWidget {
  const _FreeSpinScatterTransition();

  @override
  State<_FreeSpinScatterTransition> createState() =>
      _FreeSpinScatterTransitionState();
}

class _FreeSpinScatterTransitionState extends State<_FreeSpinScatterTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

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
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Widget> _buildCupcakeBurst(BuildContext context) {
    final size = MediaQuery.of(context).size;
    const assetPath = 'lib/images/slot_main_screen/Items/cupCake.png';

    const int count = 420;
    const double cellSize = 0.19;

    double noise(int seed) {
      final raw = math.sin(seed * 12.9898) * 43758.5453;
      return raw - raw.floorToDouble();
    }

    final List<Widget> cupcakes = [];

    for (int index = 0; index < count; index++) {
      final t = index / count;
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
      final sizeVar = cellSize + noise(index * 19 + 11) * 0.13;
      final rotation = (noise(index * 23 + 13) - 0.5) * 1.8;
      final delay = (radius * 0.22 + noise(index * 29 + 15) * 0.12).clamp(
        0.0,
        0.28,
      );

      final localProgress = ((_controller.value - delay) / 0.52).clamp(
        0.0,
        1.0,
      );
      final pop = Curves.easeOutBack.transform(localProgress);
      final drift = Curves.easeOutCubic.transform(localProgress);

      cupcakes.add(
        Positioned(
          left: size.width * (0.5 + x) - (size.width * sizeVar / 2),
          top: size.height * (0.46 + y) - (size.width * sizeVar / 2),
          child: Transform.translate(
            offset: Offset(
              (noise(index * 31 + 17) - 0.5) * 95 * (1 - drift),
              (1 - drift) * (-85 - noise(index * 37 + 19) * 95),
            ),
            child: Transform.scale(
              scale: (0.34 + pop * 0.84) * _scale.value.clamp(0.9, 1.22),
              child: Transform.rotate(
                angle: rotation + _rotation.value,
                child: Image.asset(
                  assetPath,
                  width: size.width * sizeVar,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return cupcakes;
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Opacity(
            opacity: _fade.value,
            child: Container(
              color: Colors.black.withValues(alpha: 0.38),
              child: Stack(
                alignment: Alignment.center,
                children: [..._buildCupcakeBurst(context)],
              ),
            ),
          );
        },
      ),
    );
  }
}
