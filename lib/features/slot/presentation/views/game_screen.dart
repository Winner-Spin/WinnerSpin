import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';

import '../../domain/models/symbol_registry.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/buy_feature_button.dart';
import 'widgets/double_chance_button.dart';
import 'widgets/free_spins_banner.dart';
import 'widgets/slot_reel.dart';
import 'widgets/respin_button.dart';
import 'widgets/minus_button.dart';
import 'widgets/plus_button.dart';
import 'widgets/auto_spin_button.dart';
import 'widgets/info_button.dart';
import 'widgets/settings_button.dart';
import 'widgets/speed_button.dart';
import 'widgets/floating_win_overlay.dart';
import '../../../auth/presentation/views/login_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameViewModel _viewModel = GameViewModel();

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
    _viewModel.fetchUserData();

    // Pre-decode symbol assets at the cell-sized cache width so the
    // first appearance of each symbol doesn't block the main thread.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final sym in SymbolRegistry.all) {
        precacheImage(
          ResizeImage(AssetImage(sym.assetPath), width: 256),
          context,
        );
      }
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
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _viewModel.removeListener(_onViewModelChange);
    super.dispose();
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
      body: LayoutBuilder(
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
                // RepaintBoundary keeps the static backdrop out of grid
                // and button repaint passes.
                child: RepaintBoundary(
                  child: Image.asset(
                    'lib/images/slot_main_screen/nihai arka plan.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.low,
                  ),
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
              Positioned(
                top: screenH * 0.15,
                left: screenW * 0.1,
                right: screenW * 0.1,
                child: ListenableBuilder(
                  listenable: _viewModel.fsCtrl,
                  builder: (context, _) {
                    if (_viewModel.isInFreeSpins) {
                      return FreeSpinsBanner(
                        remaining: _viewModel.freeSpinsRemaining,
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.5185,
                left: 0,
                right: 0,
                height: 31,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
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
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        _viewModel,
                        _viewModel.balanceCtrl,
                      ]),
                      builder: (context, _) => _buildStatusText(),
                    ),
                  ],
                ),
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
                  builder: (context, _) => RepaintBoundary(
                    child: BuyFeatureButton(
                      price: _viewModel.buyFeaturePrice,
                      disabled: !_viewModel.canBuyFreeSpinsForUi ||
                          _viewModel.anteBetActive,
                      onTap: _viewModel.buyFreeSpins,
                      width: screenW * 0.39,
                      height: screenW * 0.22,
                    ),
                  ),
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
                  ]),
                  builder: (context, _) => RepaintBoundary(
                    child: DoubleChanceButton(
                      betAmount: _viewModel.anteCost,
                      isOn: _viewModel.anteBetActive,
                      disabled: _viewModel.isBusy || _viewModel.isInFreeSpins,
                      onTap: _viewModel.toggleAnteBet,
                      width: screenW * 0.39,
                      height: screenW * 0.22,
                    ),
                  ),
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
                      listenable: _viewModel.balanceCtrl,
                      builder: (context, _) => RepaintBoundary(
                        child: MinusButton(
                          size: 42,
                          onTap: _viewModel.decreaseBet,
                          disabled: !_viewModel.canDecreaseBet,
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
                      listenable: _viewModel.balanceCtrl,
                      builder: (context, _) => RepaintBoundary(
                        child: PlusButton(
                          size: 42,
                          onTap: _viewModel.increaseBet,
                          disabled: !_viewModel.canIncreaseBet,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: screenH * 0.90,
                left: 0,
                child: const InfoButton(),
              ),
              Positioned(
                top: screenH * 0.90,
                right: 0,
                child: const SettingsButton(),
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
      ),
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
                  speedMultiplier: _viewModel.speedMultiplier,
                  onComplete: col == GameViewModel.columns - 1
                      ? () => _viewModel.onSpinComplete()
                      : null,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    final lastWin = _viewModel.lastWin;
    final isBusy = _viewModel.isBusy;

    if (_viewModel.showInsufficientFundsHint) {
      return Text('PLEASE DEPOSIT MONEY!', style: _statusInsufficientStyle);
    }

    if (lastWin > 0 && !isBusy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('KAZANÇ', style: _statusKazancStyle),
          const SizedBox(width: 6),
          TweenAnimationBuilder<double>(
            key: ValueKey<double>(lastWin),
            tween: Tween<double>(begin: 0, end: lastWin),
            duration: const Duration(seconds: 1),
            curve: Curves.easeOut,
            builder: (context, value, _) =>
                Text('₺${formatMoney(value)}', style: _statusBaseStyle),
          ),
        ],
      );
    }

    if (isBusy) {
      return Text('GOOD LUCK!', style: _statusBaseStyle);
    }

    return Text('PLACE YOUR BETS!', style: _statusBaseStyle);
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
