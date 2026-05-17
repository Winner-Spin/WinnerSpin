import 'package:flutter/material.dart';

import '../../../../../../core/widgets/money_text.dart';
import '../../../../domain/models/slot_symbol.dart';
import '../../../models/game_rules_payout_formatter.dart';
import '../../../models/game_rules_styles.dart';

class GameRulesSymbolPayoutCard extends StatelessWidget {
  const GameRulesSymbolPayoutCard({
    super.key,
    required this.symbol,
    required this.betAmount,
    this.isHorizontal = false,
  });

  final SlotSymbol symbol;
  final double betAmount;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    final payouts = symbol.isScatter ? symbol.scatterPayouts : symbol.payouts;
    final sortedThresholds = payouts.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    final imageWidget = SizedBox(
      height: 58,
      width: 58,
      child: Image.asset(
        symbol.assetPath,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );

    final rowsWidget = Column(
      crossAxisAlignment: isHorizontal
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: sortedThresholds.map((threshold) {
        final multiplier = payouts[threshold]!;
        final payout = multiplier * betAmount;
        final rangeText = symbol.isScatter
            ? GameRulesPayoutFormatter.scatterRangeText(
                threshold,
                sortedThresholds,
              )
            : GameRulesPayoutFormatter.rangeText(threshold, sortedThresholds);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: _PayoutRow(
            range: rangeText,
            value: GameRulesPayoutFormatter.payoutValue(payout),
          ),
        );
      }).toList(),
    );

    if (isHorizontal) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [imageWidget, const SizedBox(width: 16), rowsWidget],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [imageWidget, const SizedBox(height: 2), rowsWidget],
      ),
    );
  }
}

class _PayoutRow extends StatelessWidget {
  const _PayoutRow({required this.range, required this.value});

  final String range;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = GameRulesStyles.payoutText();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(range, style: style),
        const SizedBox(width: 4),
        MoneyText(text: value, style: style),
      ],
    );
  }
}
