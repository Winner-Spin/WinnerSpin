import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/audio/app_audio_context.dart';
import '../../domain/models/pool_state.dart';
import '../../domain/models/spin_result.dart';
import '../../domain/models/symbol_registry.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/data/repositories/firebase_auth_repository.dart';
import '../audio/ui_click_sound.dart';
import '../../data/repositories/firestore_pool_repository.dart';
import '../../domain/repositories/pool_repository.dart';
import '../../domain/engine/slot_engine.dart';
import '../../domain/engine/spin_task.dart';
import '../../domain/models/cluster_win.dart';
import 'controllers/ante_controller.dart';
import 'controllers/balance_controller.dart';
import 'controllers/free_spins_controller.dart';
import 'controllers/grid_controller.dart';

class GameHistoryEntry {
  const GameHistoryEntry({
    required this.id,
    required this.playedAt,
    required this.newBalance,
    required this.bet,
    required this.winAmount,
  });

  factory GameHistoryEntry.fromJson(Map<String, dynamic> json) {
    final playedAt = DateTime.parse(json['playedAt'] as String);
    return GameHistoryEntry(
      id: json['id'] as String? ?? playedAt.microsecondsSinceEpoch.toString(),
      playedAt: playedAt,
      newBalance: (json['newBalance'] as num).toDouble(),
      bet: (json['bet'] as num).toDouble(),
      winAmount: (json['winAmount'] as num).toDouble(),
    );
  }

  final String id;
  final DateTime playedAt;
  final double newBalance;
  final double bet;
  final double winAmount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'playedAt': playedAt.toIso8601String(),
      'newBalance': newBalance,
      'bet': bet,
      'winAmount': winAmount,
    };
  }
}

/// Top-level orchestrator for the slot screen. Composes four focused
/// sub-controllers (balance, ante, free spins, grid) and coordinates the
/// engine, repositories, and animation lifecycle. Each sub-controller is
/// itself a ChangeNotifier and is exposed via a public getter so views
/// can subscribe only to the slice of state they care about. This
/// ViewModel notifies for state it owns directly: spinning/tumbling
/// flags, auto-spin, speed, and user-profile fields.
class GameViewModel extends ChangeNotifier {
  static const double _ambientMusicVolume = 0.48;

  GameViewModel({
    AuthRepository? authRepository,
    PoolRepository? poolRepository,
  }) : _authRepository = authRepository ?? FirebaseAuthRepository(),
       _poolRepository = poolRepository ?? FirestorePoolRepository() {
    final result = SlotEngine.spin(_pool, 0);
    _gridCtrl = GridController(result.initialGrid);
    _initMusic();
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMusicInitialized = false;

  Future<void> _initMusic() async {
    _isMusicInitialized = true;
    await _audioPlayer.setAudioContext(AppAudioContext.game);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.setVolume(_ambientMusicVolume);
    if (_ambientMusic) {
      await _audioPlayer.play(AssetSource('audio/Items/Basin_of_Light.mp3'));
    }
  }

  final AuthRepository _authRepository;
  final PoolRepository _poolRepository;
  StreamSubscription<Map<String, dynamic>?>? _userSubscription;

  // ── Composed controllers ──
  final BalanceController _balanceCtrl = BalanceController();
  final AnteController _anteCtrl = AnteController();
  final FreeSpinsController _fsCtrl = FreeSpinsController();
  late final GridController _gridCtrl;

  BalanceController get balanceCtrl => _balanceCtrl;
  AnteController get anteCtrl => _anteCtrl;
  FreeSpinsController get fsCtrl => _fsCtrl;
  GridController get gridCtrl => _gridCtrl;

  // ── User profile ──

  String _username = 'Loading...';
  String get username => _username;

  String _email = 'Loading...';
  String get email => _email;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _loggedOut = false;
  bool get loggedOut => _loggedOut;

  // ── Grid + animation state ──

  static const int columns = SlotEngine.columns;
  static const int rows = SlotEngine.rows;

  /// Grid state (delegated to [GridController]).
  List<List<String>> get grid => _gridCtrl.grid;
  List<List<String>> get previousGrid => _gridCtrl.previousGrid;
  Set<String> get fadingPaths => _gridCtrl.fadingPaths;
  List<ClusterWin> get activeExplosions => _gridCtrl.activeExplosions;
  Set<int> get winningPositions => _gridCtrl.winningPositions;
  Set<int> get clearedPositions => _gridCtrl.clearedPositions;

  bool _isTumbling = false;
  bool get isTumbling => _isTumbling;

  bool _isSpinning = false;
  bool get isSpinning => _isSpinning;

  bool _isAutoSpinning = false;
  bool get isAutoSpinning => _isAutoSpinning;

  bool _lastSpinWasFreeSpin = false;
  bool get lastSpinWasFreeSpin => _lastSpinWasFreeSpin;

  int _autoSpinsRemaining = 0;
  int get autoSpinsRemaining => _autoSpinsRemaining;

  /// True while any spin or its cascade is still animating.
  bool get isBusy => _isSpinning || _isTumbling;

  int _speedMultiplier = 1;
  int get speedMultiplier => _speedMultiplier;

  bool _showInsufficientFundsHint = false;
  bool get showInsufficientFundsHint => _showInsufficientFundsHint;
  Timer? _insufficientHintTimer;

  /// Running cluster-win total reported live as each tumble step pops.
  /// Drives the status-bar counter so the player watches the value
  /// climb in lock-step with each cluster's celebration animation,
  /// instead of the old behaviour where the counter only ticked up
  /// once after every tumble had finished.
  double _liveTumbleWin = 0;
  double get liveTumbleWin => _liveTumbleWin;

  // ── Balance & bet (delegated to BalanceController) ──

  double get balance => _balanceCtrl.balance;
  double get userBalance => _balanceCtrl.userBalance;
  double get betAmount => _balanceCtrl.betAmount;
  double get lastWin => _balanceCtrl.lastWin;
  double get effectiveBetCost => _balanceCtrl.effectiveBetCost;
  double get anteCost => _balanceCtrl.anteCost;
  double get buyFeaturePrice => _balanceCtrl.buyFeaturePrice;
  bool get canDecreaseBet => _balanceCtrl.canDecreaseBet;
  bool get canIncreaseBet => _balanceCtrl.canIncreaseBet;

  // ── Ante (delegated to AnteController) ──

  bool get anteBetActive => _anteCtrl.active;

  // ── Free spins (delegated to FreeSpinsController) ──

  int get freeSpinsRemaining => _fsCtrl.remaining;

  /// Held true from the moment an FS spin starts until its full
  /// post-spin celebration settles. Keeps [isInFreeSpins] reporting
  /// true on the very last FS spin even after the counter consumes
  /// to zero, so the FS chrome stays on screen through the multiplier
  /// collect, flight, and Kazanç count-up. The consume itself fires
  /// earlier — at the lingering-cluster timer end — so the displayed
  /// counter updates immediately without holding the chrome flip.
  bool _fsRoundHoldActive = false;

  bool get isInFreeSpins => _fsCtrl.isActive || _fsRoundHoldActive;

  /// True only when the buy CTA can fire. Pool health is intentionally
  /// not gated here — the engine still chooses recovery/jackpot/normal
  /// mode based on pool state, so a buy on an unhealthy pool simply
  /// runs the FS round in the mode pool dictates instead of being
  /// blocked at the button level.
  bool get canBuyFreeSpins =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAffordDisplayed(buyFeaturePrice);

  /// User-facing buy availability. Mirrors the displayed credit (not
  /// the canonical balance) so the button doesn't go grey while the
  /// player still sees enough credit to cover the buy. Skips the
  /// engine pool guard for the same reason — the actual buyFreeSpins()
  /// call still re-runs the full canBuyFreeSpins check before charging.
  bool get canBuyFreeSpinsForUi =>
      !isBusy &&
      !_isAutoSpinning &&
      !isInFreeSpins &&
      _balanceCtrl.canAffordDisplayed(buyFeaturePrice);

  /// User-facing spin availability. Same rationale as
  /// [canBuyFreeSpinsForUi] — uses the displayed balance.
  bool get canSpinForUi =>
      isInFreeSpins || _balanceCtrl.canAffordDisplayed(effectiveBetCost);

  /// True when the spin CTA can fire — free spins always allow it
  /// (cost-free), otherwise the player must cover the per-spin cost.
  bool get canSpin => isInFreeSpins || _balanceCtrl.canAfford(effectiveBetCost);

  // ── Pool + pending result ──

  PoolState _pool = PoolState();
  SpinResult? _pendingResult;
  double _pendingHistoryBet = 0;
  bool _pendingFsConsume = false;

  /// Latches true for the duration of the buy-trigger spin so the FS
  /// round started by its scatters carries the buy origin flag through
  /// to the engine for the buy multiplier boost. Held through the
  /// post-spin celebration too — the screen reads it to skip the FS
  /// accumulator flight on the trigger spin (its win goes to balance,
  /// not the FS round total) and unlock the respin button as soon as
  /// the cascade settles instead of waiting on a flight that never
  /// runs. Cleared at the start of the next spin.
  bool _currentSpinFromBuy = false;
  bool get isCurrentSpinFromBuy => _currentSpinFromBuy;
  String? _historyUserId;
  final List<GameHistoryEntry> _gameHistory = [];
  List<GameHistoryEntry> get gameHistory => List.unmodifiable(_gameHistory);

  /// Exposed result of the most recently completed spin. The win
  /// presentation layer reads `baseWin`, `finalMultipliers`, and
  /// `totalWin` off this to drive the staged collect-and-multiply
  /// reveal.
  SpinResult? _lastSpinResult;
  SpinResult? get lastSpinResult => _lastSpinResult;
  bool get shouldPulseLandingScatters {
    // During an active FS round the scatter-pulse sequence is driven
    // entirely by _showScatterPulse() in game_screen.dart (triggered
    // after the spin settles). Firing the drop-animation pulse here
    // too would cause single-cupcake pulses on every FS spin.
    if (isInFreeSpins) return false;

    final pending = _pendingResult;
    if (pending == null || pending.freeSpinsTriggered) return false;

    final grid = pending.initialGrid;
    final scatterPath = SymbolRegistry.all
        .firstWhere((s) => s.isScatter)
        .assetPath;
    final scatterCount = grid
        .expand((column) => column)
        .where((path) => path == scatterPath)
        .length;

    return scatterCount >= 4;
  }

  // ── Tumble animation timing ──
  /// Window for the winning-cell glow + fade. First half is the gold-glow
  /// celebration, second half is the symbol fade-out — see [TumbleCell].
  static const Duration _tumbleFadeDuration = Duration(milliseconds: 1750);
  static const Duration _tumbleSettleDuration = Duration(milliseconds: 450);

  // ── Settings ──
  bool _vibration = true;
  bool get vibration => _vibration;
  void setVibration(bool value) {
    if (_vibration == value) return;
    _vibration = value;
    notifyListeners();
  }

  bool _ambientMusic = true;
  bool get ambientMusic => _ambientMusic;
  void setAmbientMusic(bool value) {
    if (_ambientMusic == value) return;
    _ambientMusic = value;
    if (_ambientMusic) {
      if (!_isMusicInitialized) {
        _initMusic();
      } else {
        _audioPlayer.setVolume(_ambientMusicVolume);
        _audioPlayer.resume();
      }
    } else {
      _audioPlayer.pause();
    }
    notifyListeners();
  }

  bool _soundEffects = true;
  bool get soundEffects => _soundEffects;
  void setSoundEffects(bool value) {
    _soundEffects = value;
    UiClickSound.enabled = value;
    if (value) unawaited(UiClickSound.preload());
    notifyListeners();
  }

  // ── User actions ──

  /// Flashes a transient "deposit funds" hint in the status bar for a
  /// couple of seconds. Used when the player taps spin without enough
  /// credit — the spin button stays visually enabled so the tap can
  /// surface this guidance instead of silently no-op'ing.
  void _flashInsufficientFundsHint() {
    _showInsufficientFundsHint = true;
    notifyListeners();
    _insufficientHintTimer?.cancel();
    _insufficientHintTimer = Timer(const Duration(seconds: 2), () {
      _showInsufficientFundsHint = false;
      notifyListeners();
    });
  }

  void startAutoSpin(int spinCount, {int speedMultiplier = 1}) {
    if (_isAutoSpinning || isBusy || spinCount <= 0) return;
    if (!isInFreeSpins && !_balanceCtrl.canAfford(effectiveBetCost)) {
      _flashInsufficientFundsHint();
      return;
    }

    _autoSpinsRemaining = spinCount;
    _speedMultiplier = speedMultiplier.clamp(1, 3).toInt();
    _isAutoSpinning = true;
    notifyListeners();
    spin();
  }

  void stopAutoSpin() {
    if (!_isAutoSpinning && _autoSpinsRemaining == 0) return;
    _isAutoSpinning = false;
    _autoSpinsRemaining = 0;
    notifyListeners();
  }

  void toggleAutoSpin() {
    if (_isAutoSpinning) {
      stopAutoSpin();
    } else {
      startAutoSpin(100, speedMultiplier: _speedMultiplier);
    }
  }

  void toggleSpeed() {
    if (isBusy && !_isAutoSpinning) return;
    _speedMultiplier = (_speedMultiplier % 3) + 1;
    notifyListeners();
  }

  /// Flips Ante Bet on/off. Blocked while spinning, cascading, or in FS.
  void toggleAnteBet() {
    if (isBusy || isInFreeSpins || _isAutoSpinning) return;
    _anteCtrl.toggle();
    _balanceCtrl.anteActiveShadow = _anteCtrl.active;
  }

  void increaseBet() {
    if (_isAutoSpinning || isInFreeSpins) return;
    _balanceCtrl.increaseBet();
  }

  void decreaseBet() {
    if (_isAutoSpinning || isInFreeSpins) return;
    _balanceCtrl.decreaseBet();
  }

  // ── User data lifecycle ──

  Future<void> fetchUserData() async {
    try {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        _historyUserId = uid;
        await _loadGameHistory();

        final results = await Future.wait([
          _authRepository.getUserData(uid),
          _poolRepository.load(uid),
        ]);

        final userData = results[0] as Map<String, dynamic>?;
        _pool = results[1] as PoolState;
        _listenToUserBalance(uid);

        if (userData != null) {
          _username = userData['username'] ?? 'Player';
          _email = userData['email'] ?? 'No Email';
          _balanceCtrl.hydrate(userData);
          _fsCtrl.hydrate(userData);

          if (!userData.containsKey('userBalance')) {
            _savePlayerState();
          }
        } else {
          _username = 'Unknown';
          _email = 'Unknown';
        }
      }
    } catch (e) {
      debugPrint('Data fetch error: $e');
      _username = 'Error';
      _email = 'Error';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToUserBalance(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _authRepository.watchUserData(uid).listen((data) {
      if (data == null || !data.containsKey('userBalance')) return;
      _balanceCtrl.applyRemoteUserBalance(
        (data['userBalance'] ?? 10000.0).toDouble(),
      );
    });
  }

  // ── Spin ──

  /// Deducts the bet, runs the engine, and stages the result for animation.
  Future<void> spin() async {
    if (isBusy) return;

    // Any leftover buy-trigger marker from the previous spin clears
    // here so the next manual / auto spin runs through the normal
    // celebration paths.
    _currentSpinFromBuy = false;

    final bool isFreeSpin = isInFreeSpins;
    _lastSpinWasFreeSpin = isFreeSpin;

    if (!isFreeSpin) {
      final cost = _balanceCtrl.effectiveBetCost;
      if (!_balanceCtrl.canAfford(cost)) {
        if (_isAutoSpinning) {
          _isAutoSpinning = false;
          _autoSpinsRemaining = 0;
        }
        _flashInsufficientFundsHint();
        return;
      }
      _pendingHistoryBet = cost;
      _balanceCtrl.charge(cost);
      _pool.recordBet(cost);
    } else {
      // FS round — no charge, so the history entry records a zero
      // stake. The counter consume is deferred (the screen fires it
      // when the lingering-cluster line clears, so the displayed FS
      // counter updates as soon as the cluster pay line steps off),
      // and the round-hold flag keeps [isInFreeSpins] reporting true
      // on the last FS spin even after the counter hits zero so the
      // FS chrome holds through the full post-spin celebration.
      _pendingHistoryBet = 0;
      _pendingFsConsume = true;
      _fsRoundHoldActive = true;
    }

    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _liveTumbleWin = 0;
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (_vibration) HapticFeedback.lightImpact();
    notifyListeners();

    // anteBet/buyFs flags propagate the round's origin so multiplier scaling
    // stays consistent across every spin (incl. retriggers).
    final bool anteFlag = isFreeSpin
        ? _anteCtrl.currentRoundFromAnte
        : _anteCtrl.active;
    final bool buyFlag = isFreeSpin && _fsCtrl.currentRoundFromBuy;

    // Engine runs on a background isolate so the rejection-sampling loop
    // (up to 150 simulated cascades on jackpot/FS spins) doesn't block the
    // tap-down ripple or any in-flight cascade animation.
    final taskOutput = await compute(
      runSlotSpinTask,
      SpinTaskInput(
        pool: _pool,
        betAmount: betAmount,
        isFreeSpins: isFreeSpin,
        anteBet: anteFlag,
        buyFs: buyFlag,
      ),
    );

    // Replace the pool reference so the isolate-side session-mode mutation
    // survives the boundary.
    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;

    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  /// Buys an FS round at 100× bet. Charges the fee, then immediately
  /// fires a trigger spin that's guaranteed to land scatters — the
  /// player watches the cupcakes drop in, any clusters resolve, and
  /// the FS round starts naturally off the scatter trigger rather
  /// than being awarded out of view. The buy origin is recorded on
  /// the awarded round so the engine still applies the buy boost
  /// across the FS spins that follow.
  Future<void> buyFreeSpins() async {
    if (_isAutoSpinning) {
      _isAutoSpinning = false;
      _autoSpinsRemaining = 0;
    }
    if (_anteCtrl.active) return;
    if (isBusy || isInFreeSpins) return;
    if (!_balanceCtrl.canAffordDisplayed(buyFeaturePrice)) {
      _flashInsufficientFundsHint();
      return;
    }

    _lastSpinWasFreeSpin = false;
    final price = buyFeaturePrice;
    _balanceCtrl.charge(price);
    _pool.recordBet(price);
    _currentSpinFromBuy = true;
    _pendingHistoryBet = 0;

    _isSpinning = true;
    _balanceCtrl.resetLastWin();
    _liveTumbleWin = 0;
    _gridCtrl.capturePreviousGrid();
    _gridCtrl.resetForNewSpin();
    if (_vibration) HapticFeedback.lightImpact();
    notifyListeners();

    final taskOutput = await compute(
      runSlotSpinTask,
      SpinTaskInput(
        pool: _pool,
        betAmount: betAmount,
        isFreeSpins: false,
        anteBet: false,
        buyFs: false,
        forceFsTrigger: true,
      ),
    );

    _pool = taskOutput.pool;
    _pendingResult = taskOutput.result;
    _gridCtrl.setGrid(_pendingResult!.initialGrid);
  }

  /// Wipes the dust residue left by last round's exploded multipliers.
  /// SlotReel calls this the moment the drop-in phase begins so the
  /// drop-out can finish showing the residue but the static state
  /// renders the new symbol cleanly.
  void clearMultiplierResidues() {
    _gridCtrl.clearMultiplierResidues();
  }

  /// Plays back cascade tumbles, awards the win, and persists state.
  /// Called by SlotReel once the initial drop-in animation completes.
  Future<void> onSpinComplete() async {
    final result = _pendingResult;
    _gridCtrl.clearMultiplierResidues();
    if (result == null) {
      _isSpinning = false;
      notifyListeners();
      return;
    }

    _isSpinning = false;

    if (result.tumbles.isNotEmpty) {
      _isTumbling = true;
      notifyListeners();
      for (final tumble in result.tumbles) {
        // Bump the live counter target right when the cluster starts
        // popping so the bar climbs in lock-step with the cell
        // celebration instead of waiting for every tumble to finish.
        _liveTumbleWin += tumble.winAmount;
        _gridCtrl.startTumble(
          fadingPaths: tumble.winningPaths,
          activeExplosions: tumble.clusterWins,
        );
        notifyListeners();
        if (_vibration) HapticFeedback.mediumImpact();
        await Future.delayed(_tumbleFadeDuration);

        _gridCtrl.endTumble(newGrid: tumble.gridAfter);
        await Future.delayed(_tumbleSettleDuration);
      }
      _isTumbling = false;
      notifyListeners();
    }

    _balanceCtrl.awardWin(result.totalWin);
    final playedAt = DateTime.now();
    _gameHistory.insert(
      0,
      GameHistoryEntry(
        id: playedAt.microsecondsSinceEpoch.toString(),
        playedAt: playedAt,
        newBalance: userBalance,
        bet: _pendingHistoryBet,
        winAmount: result.totalWin,
      ),
    );
    if (_gameHistory.length > 30) {
      _gameHistory.removeLast();
    }
    _saveGameHistory();
    if (_vibration && result.totalWin > 0) HapticFeedback.heavyImpact();
    _gridCtrl.setWinningPositions(result.winningPositions);
    _lastSpinResult = result;

    if (result.freeSpinsTriggered) {
      if (result.isRetrigger) {
        _fsCtrl.awardRetrigger();
      } else {
        _fsCtrl.awardInitial();
        // Only an initial trigger captures ante state — retriggers inherit
        // the existing round's flag.
        _anteCtrl.captureForNewRound();
        // The buy CTA's trigger spin lights up the FS round with the buy
        // origin so the engine applies the buy multiplier boost across
        // every spin in this round.
        if (_currentSpinFromBuy) {
          _fsCtrl.markCurrentRoundFromBuy();
        }
      }
    }
    // [_currentSpinFromBuy] stays raised until the next spin starts —
    // the celebration code reads it to skip the FS accumulator flight
    // on the trigger spin so its win lands on balance and the lock
    // releases the moment the cascade settles.

    // Round ended? Clear the FS-source flags.
    if (!isInFreeSpins) {
      _anteCtrl.clearRoundFlag();
      _fsCtrl.clearRoundFlag();
    }

    _pool.recordPayout(result.totalWin);
    // Player state is persisted on the same cadence as the pool (every 10
    // base spins). Lifecycle hooks force-save the latest state on background,
    // app close, and logout to cover edge cases between save intervals.
    _savePoolIfNeeded();

    _pendingResult = null;
    _pendingHistoryBet = 0;

    if (_isAutoSpinning) {
      _autoSpinsRemaining = (_autoSpinsRemaining - 1).clamp(0, 9999).toInt();
      if (_autoSpinsRemaining == 0) {
        _isAutoSpinning = false;
        notifyListeners();
        return;
      }

      notifyListeners();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (_isAutoSpinning && !isBusy) {
          spin();
        }
      });
    }
  }

  /// Commits the deferred FS counter consume queued by an FS spin's
  /// start. The screen calls this when the lingering cluster line
  /// clears (~1s after the cascade settles) so the displayed counter
  /// updates immediately, decoupled from the chrome transition which
  /// stays raised through [_fsRoundHoldActive] until the celebration
  /// fully unwinds.
  void commitPendingFsConsume() {
    if (!_pendingFsConsume) return;
    _pendingFsConsume = false;
    _fsCtrl.consumeOne();
  }

  /// Drops the round-hold flag once the post-spin celebration has
  /// fully unwound. After this clears, [isInFreeSpins] falls back to
  /// the raw [FreeSpinsController.isActive] flag — so the FS chrome
  /// only flips off the screen at the very end of the last FS spin's
  /// visual sequence, never mid-presentation.
  void releaseFsRoundHold() {
    if (!_fsRoundHoldActive) return;
    _fsRoundHoldActive = false;
    notifyListeners();
  }

  // ── Sign out ──

  Future<void> signOut() async {
    await _forceSavePool();
    await _userSubscription?.cancel();
    _userSubscription = null;
    await _authRepository.signOut();
    _loggedOut = true;
    notifyListeners();
  }

  void resetLoggedOut() {
    _loggedOut = false;
  }

  // ── Persistence ──

  Future<File?> _gameHistoryFile() async {
    final uid = _historyUserId;
    if (uid == null) return null;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/game_history_$uid.json');
  }

  Future<void> _loadGameHistory() async {
    try {
      final file = await _gameHistoryFile();
      if (file == null || !await file.exists()) return;

      final decoded = jsonDecode(await file.readAsString()) as List<dynamic>;
      _gameHistory
        ..clear()
        ..addAll(
          decoded
              .cast<Map<String, dynamic>>()
              .map(GameHistoryEntry.fromJson)
              .take(30),
        );
    } catch (e) {
      debugPrint('Game history load error: $e');
    }
  }

  Future<void> _saveGameHistory() async {
    try {
      final file = await _gameHistoryFile();
      if (file == null) return;
      await file.writeAsString(
        jsonEncode(_gameHistory.map((entry) => entry.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('Game history save error: $e');
    }
  }

  void deleteGameHistoryEntries(Set<String> ids) {
    if (ids.isEmpty) return;
    _gameHistory.removeWhere((entry) => ids.contains(entry.id));
    _saveGameHistory();
    notifyListeners();
  }

  void _savePlayerState() {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      _authRepository.savePlayerState(
        uid,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    }
  }

  /// Fire-and-forget pool + player save once the save interval has elapsed
  /// (every [PoolState.saveInterval] base spins).
  void _savePoolIfNeeded() {
    if (_pool.shouldSave) {
      final uid = _authRepository.currentUserId;
      if (uid != null) {
        _poolRepository.save(uid, _pool);
        _savePlayerState();
      }
    }
  }

  /// Awaited pool save used at logout / app background.
  Future<void> _forceSavePool() async {
    final uid = _authRepository.currentUserId;
    if (uid != null) {
      await _poolRepository.save(uid, _pool);
      await _authRepository.savePlayerState(
        uid,
        userBalance: userBalance,
        freeSpinsRemaining: freeSpinsRemaining,
      );
    }
  }

  /// Force-save hook for app lifecycle transitions (background, hidden,
  /// detached/killed). Ensures the latest balance + pool state are persisted
  /// even if fewer than [PoolState.saveInterval] spins have elapsed since
  /// the last incremental save.
  Future<void> onAppLifecycleEvent() async {
    await _forceSavePool();
    // Pause music if backgrounded
    if (_ambientMusic) {
      await _audioPlayer.pause();
    }
  }

  void onAppResumed() {
    // Resume music if it should be playing
    if (_ambientMusic) {
      _audioPlayer.setVolume(_ambientMusicVolume);
      _audioPlayer.resume();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _userSubscription?.cancel();
    _insufficientHintTimer?.cancel();
    _balanceCtrl.dispose();
    _anteCtrl.dispose();
    _fsCtrl.dispose();
    _gridCtrl.dispose();
    super.dispose();
  }
}
