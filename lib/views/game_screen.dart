import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../viewmodels/game_viewmodel.dart';
import '../widgets/slot_reel.dart';
import 'login_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
  final GameViewModel _viewModel = GameViewModel();

  late AnimationController _spinButtonController;
  late Animation<double> _spinButtonScale;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChange);
    _viewModel.fetchUserData();

    _spinButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _spinButtonScale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
          parent: _spinButtonController, curve: Curves.easeInOut),
    );
  }

  void _onViewModelChange() {
    _handleLogout(context);
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChange);
    _spinButtonController.dispose();
    super.dispose();
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
              // ── BACKGROUND ──────────────────────────────
              Positioned.fill(
                child: Image.asset(
                  'lib/images/slot_main_screen/nihai arka plan.png',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),

              // ── TOP BAR (User info + Balance) ───────────
              Positioned(
                top: screenH * 0.045,
                left: screenW * 0.04,
                right: screenW * 0.04,
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) => _buildTopBar(screenW),
                ),
              ),

              // ── SLOT GRID (5×3) ─────────────────────────
              Positioned(
                top: screenH * 0.195,
                left: screenW * 0.065,
                right: screenW * 0.065,
                height: screenH * 0.32,
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) => _buildSlotGrid(),
                ),
              ),

              // ── BOTTOM CONTROL PANEL ────────────────────
              Positioned(
                bottom: screenH * 0.02,
                left: screenW * 0.04,
                right: screenW * 0.04,
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) => _buildBottomPanel(screenW, screenH),
                ),
              ),

              // ── WIN OVERLAY ─────────────────────────────
              Positioned(
                top: screenH * 0.42,
                left: screenW * 0.15,
                right: screenW * 0.15,
                child: AnimatedBuilder(
                  animation: _viewModel,
                  builder: (context, child) {
                    if (_viewModel.lastWin > 0 && !_viewModel.isSpinning) {
                      return _buildWinBanner();
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTopBar(double screenW) {
    return SafeArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // User info
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.purple.shade900.withValues(alpha: 0.85),
                  Colors.deepPurple.shade800.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.amber.shade300.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.amber.shade400,
                        Colors.orange.shade600,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.person,
                      size: 18, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Text(
                  _viewModel.isLoading ? '...' : _viewModel.username,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Balance
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.shade800.withValues(alpha: 0.9),
                  Colors.orange.shade700.withValues(alpha: 0.9),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.yellow.shade300.withValues(alpha: 0.7),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '💰',
                  style: GoogleFonts.outfit(fontSize: 16),
                ),
                const SizedBox(width: 6),
                Text(
                  '₺${_viewModel.balance.toStringAsFixed(0)}',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        offset: const Offset(0, 1),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Logout button
          GestureDetector(
            onTap: () => _viewModel.signOut(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade400,
                    Colors.red.shade700,
                  ],
                ),
                border: Border.all(
                  color: Colors.red.shade200.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.logout, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SLOT GRID (5×3)
  // ═══════════════════════════════════════════════════════════════

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
                            color:
                                Colors.white.withValues(alpha: 0.12),
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

  // ═══════════════════════════════════════════════════════════════
  // BOTTOM CONTROL PANEL
  // ═══════════════════════════════════════════════════════════════

  Widget _buildBottomPanel(double screenW, double screenH) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bet controls row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Decrease bet
            _buildBetButton(
              icon: Icons.remove,
              onTap: _viewModel.decreaseBet,
            ),

            const SizedBox(width: 12),

            // Bet display
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.shade900.withValues(alpha: 0.85),
                    Colors.deepPurple.shade800.withValues(alpha: 0.85),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      Colors.amber.shade300.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'BAHİS',
                    style: GoogleFonts.outfit(
                      color:
                          Colors.amber.shade200.withValues(alpha: 0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    '₺${_viewModel.betAmount.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      color: Colors.amber.shade300,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Increase bet
            _buildBetButton(
              icon: Icons.add,
              onTap: _viewModel.increaseBet,
            ),
          ],
        ),

        const SizedBox(height: 14),

        // SPIN Button
        GestureDetector(
          onTapDown: (_) => _spinButtonController.forward(),
          onTapUp: (_) {
            _spinButtonController.reverse();
            _viewModel.spin();
          },
          onTapCancel: () => _spinButtonController.reverse(),
          child: AnimatedBuilder(
            animation: _spinButtonScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _spinButtonScale.value,
                child: child,
              );
            },
            child: Container(
              width: screenW * 0.55,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: _viewModel.isSpinning ||
                        _viewModel.balance < _viewModel.betAmount
                    ? LinearGradient(
                        colors: [
                          Colors.grey.shade600,
                          Colors.grey.shade700,
                        ],
                      )
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.green.shade400,
                          Colors.green.shade600,
                          Colors.green.shade800,
                        ],
                      ),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: _viewModel.isSpinning
                      ? Colors.grey.shade400
                      : Colors.greenAccent.shade200.withValues(alpha: 0.6),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_viewModel.isSpinning
                            ? Colors.grey
                            : Colors.green)
                        .withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: (_viewModel.isSpinning
                            ? Colors.grey
                            : Colors.greenAccent)
                        .withValues(alpha: 0.2),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: _viewModel.isSpinning
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white.withValues(alpha: 0.8),
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Dönüyor...',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        '🎰  SPIN',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                          shadows: [
                            Shadow(
                              color:
                                  Colors.black.withValues(alpha: 0.4),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Last win info
        if (_viewModel.lastWin > 0)
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
    );
  }

  Widget _buildBetButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.amber.shade600,
              Colors.orange.shade700,
            ],
          ),
          border: Border.all(
            color: Colors.amber.shade300.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WIN BANNER
  // ═══════════════════════════════════════════════════════════════

  Widget _buildWinBanner() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amber.shade700.withValues(alpha: 0.95),
              Colors.orange.shade600.withValues(alpha: 0.95),
              Colors.amber.shade700.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.yellow.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              '🎉 KAZANDIN! 🎉',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '₺${_viewModel.lastWin.toStringAsFixed(0)}',
              style: GoogleFonts.outfit(
                color: Colors.yellow.shade100,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void _handleLogout(BuildContext context) {
    if (!mounted) return;
    if (_viewModel.loggedOut) {
      _viewModel.resetLoggedOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }
}
