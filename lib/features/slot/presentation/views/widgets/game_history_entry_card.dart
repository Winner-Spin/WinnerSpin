import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../../domain/models/game_history_entry.dart';
import 'game_history_metric.dart';

class GameHistoryEntryCard extends StatelessWidget {
  const GameHistoryEntryCard({
    super.key,
    required this.entry,
    required this.selected,
    required this.isSelecting,
    required this.formattedDate,
    required this.textColor,
    required this.headerColor,
    required this.goldColor,
    required this.onTap,
    required this.onLongPress,
  });

  final GameHistoryEntry entry;
  final bool selected;
  final bool isSelecting;
  final String formattedDate;
  final Color textColor;
  final Color headerColor;
  final Color goldColor;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final winColor = entry.winAmount > 0
        ? const Color(0xFF00C853)
        : textColor.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: isSelecting ? onTap : null,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? goldColor.withValues(alpha: 0.18)
              : headerColor.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? goldColor : textColor.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    formattedDate,
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: textColor.withValues(alpha: 0.82),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (isSelecting)
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: selected
                        ? goldColor
                        : textColor.withValues(alpha: 0.45),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: GameHistoryMetric(
                    label: 'NEW BALANCE',
                    textColor: textColor,
                    valueWidget: _HistoryMoneyText(
                      amount: entry.newBalance,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameHistoryMetric(
                    label: 'BET',
                    textColor: textColor,
                    valueWidget: _HistoryMoneyText(
                      amount: entry.bet,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GameHistoryMetric(
                    label: 'WIN',
                    textColor: textColor,
                    valueWidget: _HistoryMoneyText(
                      amount: entry.winAmount,
                      color: winColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMoneyText extends StatelessWidget {
  const _HistoryMoneyText({required this.amount, required this.color});

  final double amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MoneyText(
      text: formatMoney(amount),
      symbolOffset: const Offset(0, 1.0),
      lineYOffset: 1.25,
      symbolTextYOffset: 0.45,
      style: GoogleFonts.barlowCondensed(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }
}
