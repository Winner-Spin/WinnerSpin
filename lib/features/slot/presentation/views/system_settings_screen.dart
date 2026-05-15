import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';
import 'deposit_money_screen.dart';
import 'game_history_screen.dart';
import 'widgets/custom_switch.dart';
import 'widgets/spring_popup_card.dart';

class SystemSettingsScreen extends StatefulWidget {
  final GameViewModel viewModel;

  const SystemSettingsScreen({super.key, required this.viewModel});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _textColor = Color(0xFF2C2530);

  final ScrollController _scrollController = ScrollController();
  bool _isExiting = false;
  bool _showGameHistory = false;

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
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SpringPopupCard(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.92,
                          maxHeight: MediaQuery.of(context).size.height * 0.84,
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
                                _buildHeader(context),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    thumbColor: _textColor.withValues(
                                      alpha: 0.25,
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
                                        22,
                                        30,
                                        22,
                                        24,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildGameHistory(),
                                          const SizedBox(height: 24),
                                          const Divider(
                                            color: Color(0x332C2530),
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
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: const Color(
                                                        0xFF2C2530,
                                                      ),
                                                      letterSpacing: 1.2,
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
                                            color: Color(0x332C2530),
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
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: const Color(
                                                        0xFF2C2530,
                                                      ),
                                                      letterSpacing: 1.2,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          _buildTotalBet(),
                                          const SizedBox(height: 24),
                                          _buildBuyGameMoneyButton(),
                                          const SizedBox(height: 36),
                                          Text(
                                            'Made with ☕️ & 💻 by Hakan Güneş & Enes Eken',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.barlowCondensed(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black,
                                              letterSpacing: 0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'This project is created solely for entertainment and portfolio purposes. It does not offer real-money gambling, betting, cash prizes, or withdrawal services. All coins, spins, bonuses, and rewards included in this project are entirely virtual; they have no real-world monetary value and cannot be purchased, sold, or converted into money in any way. This project does not promote or encourage gambling or betting activities.',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.barlowCondensed(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black.withValues(
                                                alpha: 0.74,
                                              ),
                                              height: 1.08,
                                            ),
                                          ),
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
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          if (_showGameHistory)
            Positioned.fill(
              child: GameHistoryScreen(
                viewModel: widget.viewModel,
                onClose: () => setState(() => _showGameHistory = false),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(color: _textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(alignment: Alignment.centerLeft, child: _buildExitButton()),
          Text(
            'SETTINGS',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 30, color: _textColor),
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
      onTap: _isExiting
          ? null
          : () {
              UiClickSound.play();
              _exitGame();
            },
      child: AnimatedOpacity(
        opacity: _isExiting ? 0.55 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _panelAccent.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.logout_rounded, size: 30, color: _textColor),
        ),
      ),
    );
  }

  Widget _buildGameHistory() {
    return GestureDetector(
      onTap: () {
        UiClickSound.play();
        setState(() => _showGameHistory = true);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'GAME HISTORY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _textColor.withValues(alpha: 0.70),
            ),
          ),
          Icon(
            Icons.open_in_new,
            color: _textColor.withValues(alpha: 0.70),
            size: 24,
          ),
        ],
      ),
    );
  }

  void _showDepositMoney() {
    if (widget.viewModel.isInFreeSpins) return;
    UiClickSound.play();
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Deposit Money',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          DepositMoneyScreen(viewModel: widget.viewModel),
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

  Widget _buildBuyGameMoneyButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.viewModel, widget.viewModel.fsCtrl]),
      builder: (context, _) {
        final disabled = widget.viewModel.isInFreeSpins;
        return GestureDetector(
          onTap: disabled ? null : _showDepositMoney,
          child: AnimatedOpacity(
            opacity: disabled ? 0.48 : 1,
            duration: const Duration(milliseconds: 120),
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: disabled
                    ? const Color(0xFF8A7C86)
                    : const Color(0xFF00C76A),
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
                'BUY GAME MONEY',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        );
      },
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
            color: _textColor,
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
                    color: const Color(0xFFF6D7EB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _textColor.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
                  ),
                  child: MoneyText(
                    text: formatMoney(bet),
                    symbolOffset: const Offset(0, 2.0),
                    lineYOffset: 2.35,
                    symbolTextYOffset: 2.3,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _textColor,
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
                  color: _textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _textColor.withValues(alpha: 0.58),
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
