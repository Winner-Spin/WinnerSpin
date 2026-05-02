import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
import 'widgets/top_bar.dart';
import 'widgets/win_banner.dart';
import '../../../auth/presentation/views/login_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  final GameViewModel _viewModel = GameViewModel();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModelChange);
    _viewModel.fetchUserData();
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

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'lib/images/slot_main_screen/nihai arka plan.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
              Positioned(
                top: screenH * 0.045,
                left: screenW * 0.04,
                right: screenW * 0.04,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                  ]),
                  builder: (context, _) => TopBar(
                    username: _viewModel.username,
                    userBalance: _viewModel.userBalance,
                    isLoading: _viewModel.isLoading,
                    onSignOut: _viewModel.signOut,
                  ),
                ),
              ),
              Positioned(
                top: screenH * 0.195,
                left: screenW * 0.065,
                right: screenW * 0.065,
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
                bottom: screenH * 0.02,
                left: screenW * 0.04,
                right: screenW * 0.04,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                  ]),
                  builder: (context, _) => _buildBottomPanel(screenW),
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
                top: screenH * 0.55,
                left: screenW * 0.15,
                right: screenW * 0.15,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                  ]),
                  builder: (context, _) {
                    if (_viewModel.lastWin > 0 && !_viewModel.isSpinning) {
                      return RepaintBoundary(
                        child: WinBanner(winAmount: _viewModel.lastWin),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
              Positioned(
                top: screenH * 0.55,
                left: screenW * 0.08,
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _viewModel,
                    _viewModel.balanceCtrl,
                  ]),
                  builder: (context, _) => RepaintBoundary(
                    child: BuyFeatureButton(
                      price: _viewModel.buyFeaturePrice,
                      disabled: _viewModel.isBusy,
                      onTap: _viewModel.buyFreeSpins,
                      width: screenW * 0.39,
                      height: screenW * 0.22,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: screenH * 0.56,
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
                    RepaintBoundary(
                      child: MinusButton(
                        size: 42,
                        onTap: _viewModel.decreaseBet,
                      ),
                    ),
                    const SizedBox(width: 16),
                    RepaintBoundary(
                      child: RespinButton(size: 84, onTap: _viewModel.spin),
                    ),
                    const SizedBox(width: 16),
                    RepaintBoundary(
                      child: PlusButton(
                        size: 42,
                        onTap: _viewModel.increaseBet,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: screenH * 0.93,
                left: 0,
                child: const InfoButton(),
              ),
              Positioned(
                top: screenH * 0.93,
                right: 0,
                child: const SettingsButton(),
              ),
              Positioned(
                top: screenH * 0.93,
                left: screenW * 0.30,
                child: const AutoSpinButton(),
              ),
              Positioned(
                top: screenH * 0.93,
                left: screenW * 0.5 + 42,
                child: ListenableBuilder(
                  listenable: _viewModel,
                  builder: (context, _) => SpeedButton(
                    level: _viewModel.speedMultiplier,
                    onTap: _viewModel.toggleSpeed,
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
              child: Container(
                decoration: BoxDecoration(
                  border: col < GameViewModel.columns - 1
                      ? Border(
                          right: BorderSide(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        )
                      : null,
                ),
                child: SlotReel(
                  columnIndex: col,
                  previousItems: List.generate(
                    GameViewModel.rows,
                    (row) => _viewModel.previousGrid[col][row],
                  ),
                  targetItems: List.generate(
                    GameViewModel.rows,
                    (row) => _viewModel.grid[col][row],
                  ),
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

  Widget _buildBottomPanel(double screenW) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'BET ₺${_viewModel.betAmount.toStringAsFixed(2)}',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.6),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        if (_viewModel.lastWin > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Son Kazanç: ₺${_viewModel.lastWin.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
              color: Colors.amber.shade300,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  offset: const Offset(0, 1),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
