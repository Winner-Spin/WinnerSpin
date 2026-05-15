import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../viewmodels/game_viewmodel.dart';

class SystemSettingsBetSection extends StatelessWidget {
  static const Color _textColor = Color(0xFF2C2530);

  final GameViewModel viewModel;
  final VoidCallback onBuyGameMoney;

  const SystemSettingsBetSection({
    super.key,
    required this.viewModel,
    required this.onBuyGameMoney,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              'BET SETTINGS',
              style: GoogleFonts.barlowCondensed(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _textColor,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTotalBet(),
        const SizedBox(height: 24),
        _buildBuyGameMoneyButton(),
      ],
    );
  }

  Widget _buildBuyGameMoneyButton() {
    return ListenableBuilder(
      listenable: Listenable.merge([viewModel, viewModel.fsCtrl]),
      builder: (context, _) {
        final disabled = viewModel.isInFreeSpins;
        return GestureDetector(
          onTap: disabled ? null : onBuyGameMoney,
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
          listenable: viewModel.balanceCtrl,
          builder: (context, _) {
            final bet = viewModel.betAmount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBetButton(
                  icon: Icons.remove,
                  color: Colors.white,
                  iconColor: Colors.black,
                  onTap: viewModel.decreaseBet,
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
                  onTap: viewModel.increaseBet,
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
}
