import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/custom_switch.dart';

class SystemSettingsScreen extends StatefulWidget {
  final GameViewModel viewModel;

  const SystemSettingsScreen({super.key, required this.viewModel});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  // Using GameViewModel for states

  final ScrollController _scrollController = ScrollController();
  bool _isExiting = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.81,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.93),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          child: Column(
                            children: [
                              _buildHeader(context),
                              Expanded(
                                child: RawScrollbar(
                                  controller: _scrollController,
                                  thumbVisibility: true,
                                  thumbColor: Colors.white.withValues(
                                    alpha: 0.5,
                                  ),
                                  thickness: 6,
                                  radius: const Radius.circular(8),
                                  padding: const EdgeInsets.only(
                                    right: 4,
                                    top: 4,
                                    bottom: 4,
                                  ),
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      56,
                                      20,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildGameHistory(),
                                        const SizedBox(height: 24),
                                        const Divider(
                                          color: Colors.white24,
                                          height: 1,
                                        ),
                                        const SizedBox(height: 24),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              'GENERAL SETTINGS',
                                              style:
                                                  GoogleFonts.barlowCondensed(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(
                                                      0xFFE5A800,
                                                    ),
                                                    letterSpacing: 1.2,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        ListenableBuilder(
                                          listenable: widget.viewModel,
                                          builder: (context, _) {
                                            return Column(
                                              children: [
                                                _buildSettingRow(
                                                  title: 'AMBIENT MUSIC',
                                                  description:
                                                      'TURN GAME MUSIC ON OR OFF',
                                                  value: widget
                                                      .viewModel
                                                      .ambientMusic,
                                                  onChanged: (v) => widget
                                                      .viewModel
                                                      .setAmbientMusic(v),
                                                ),
                                                const SizedBox(height: 24),
                                                _buildSettingRow(
                                                  title: 'SOUND EFFECTS',
                                                  description:
                                                      'TURN GAME SOUNDS ON OR OFF',
                                                  value: widget
                                                      .viewModel
                                                      .soundEffects,
                                                  onChanged: (v) => widget
                                                      .viewModel
                                                      .setSoundEffects(v),
                                                ),
                                                const SizedBox(height: 24),
                                                _buildSettingRow(
                                                  title: 'VIBRATION',
                                                  description:
                                                      'TURN IN-GAME VIBRATIONS ON OR OFF',
                                                  value: widget
                                                      .viewModel
                                                      .vibration,
                                                  onChanged: (v) => widget
                                                      .viewModel
                                                      .setVibration(v),
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 32),
                                        const Divider(
                                          color: Colors.white24,
                                          height: 1,
                                        ),
                                        const SizedBox(height: 24),

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Text(
                                              'BET SETTINGS',
                                              style:
                                                  GoogleFonts.barlowCondensed(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
                                                    color: const Color(
                                                      0xFFE5A800,
                                                    ),
                                                    letterSpacing: 1.2,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha: 0.8,
                                                            ),
                                                        blurRadius: 4,
                                                        offset: const Offset(
                                                          0,
                                                          2,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTotalBet(),
                                        const SizedBox(height: 32),
                                        Center(child: _buildExitButton()),
                                      ],
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
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SYSTEM SETTINGS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE5A800), // Darker yellow/gold color
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 30,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exitGame() async {
    if (_isExiting) return;
    setState(() => _isExiting = true);
    Navigator.of(context).pop();
    await widget.viewModel.signOut();
  }

  Widget _buildExitButton() {
    return GestureDetector(
      onTap: _isExiting ? null : _exitGame,
      child: AnimatedOpacity(
        opacity: _isExiting ? 0.55 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 132,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE5A800),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            _isExiting ? 'EXITING...' : 'EXIT',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGameHistory() {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameHistoryScreen(viewModel: widget.viewModel),
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'GAME HISTORY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Icon(
            Icons.open_in_new,
            color: Colors.white.withValues(alpha: 0.6),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBet() {
    return Column(
      children: [
        Text(
          'TOTAL BET',
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.viewModel.balanceCtrl,
          builder: (context, _) {
            final bet = widget.viewModel.betAmount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBetButton(
                  icon: Icons.remove,
                  color: Colors.white,
                  iconColor: Colors.black,
                  onTap: widget.viewModel.decreaseBet,
                ),
                const SizedBox(width: 16),
                Container(
                  width: 130,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Text(
                    '${formatMoney(bet)} \$', // Using $ to match the screenshot
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildBetButton(
                  icon: Icons.add,
                  color: Colors.white,
                  iconColor: Colors.black,
                  onTap: widget.viewModel.increaseBet,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBetButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  final Set<String> _selectedHistoryIds = {};

  bool get _isSelecting => _selectedHistoryIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.viewModel,
                builder: (context, _) {
                  final history = widget.viewModel.gameHistory;

                  if (history.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                      child: _buildHistoryEmptyState(),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
                    itemBuilder: (context, index) =>
                        _buildHistoryEntry(history[index]),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemCount: history.length,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            _isSelecting
                ? '${_selectedHistoryIds.length} SELECTED'
                : 'GAME HISTORY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFE5A800),
              letterSpacing: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _isSelecting
                  ? () => setState(_selectedHistoryIds.clear)
                  : () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  _isSelecting ? Icons.close : Icons.arrow_back_ios_new,
                  size: 24,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
          if (_isSelecting)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: _deleteSelectedEntries,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.delete_outline,
                    size: 28,
                    color: Colors.redAccent.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(
        'NO GAME HISTORY YET',
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(GameHistoryEntry entry) {
    final selected = _selectedHistoryIds.contains(entry.id);
    final winColor = entry.winAmount > 0
        ? const Color(0xFF00C853)
        : Colors.white.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: _isSelecting ? () => _toggleEntrySelection(entry.id) : null,
      onLongPress: () => _toggleEntrySelection(entry.id),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE5A800).withValues(alpha: 0.16)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? const Color(0xFFE5A800)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatHistoryDate(entry.playedAt),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFE5A800),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (_isSelecting)
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: selected
                        ? const Color(0xFFE5A800)
                        : Colors.white.withValues(alpha: 0.45),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'NEW BALANCE',
                    value: '${formatMoney(entry.newBalance)} \$',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'BET',
                    value: '${formatMoney(entry.bet)} \$',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'WIN',
                    value: '${formatMoney(entry.winAmount)} \$',
                    valueColor: winColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMetric({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.45),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: valueColor ?? Colors.white,
          ),
        ),
      ],
    );
  }

  void _toggleEntrySelection(String id) {
    setState(() {
      if (!_selectedHistoryIds.add(id)) {
        _selectedHistoryIds.remove(id);
      }
    });
  }

  void _deleteSelectedEntries() {
    widget.viewModel.deleteGameHistoryEntries(Set.of(_selectedHistoryIds));
    setState(_selectedHistoryIds.clear);
  }

  String _formatHistoryDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }
}
