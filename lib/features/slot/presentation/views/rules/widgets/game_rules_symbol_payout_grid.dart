import 'package:flutter/material.dart';

import '../../../../domain/models/symbol_registry.dart';
import 'game_rules_symbol_payout_card.dart';

class GameRulesSymbolPayoutGrid extends StatelessWidget {
  const GameRulesSymbolPayoutGrid({super.key, required this.betAmount});

  final double betAmount;

  @override
  Widget build(BuildContext context) {
    final heart = SymbolRegistry.all.firstWhere((s) => s.id == 'heart');
    final greenBear = SymbolRegistry.all.firstWhere(
      (s) => s.id == 'green_bear',
    );
    final pinkBear = SymbolRegistry.all.firstWhere((s) => s.id == 'pink_bear');
    final strawberry = SymbolRegistry.all.firstWhere(
      (s) => s.id == 'strawberry',
    );
    final apple = SymbolRegistry.all.firstWhere((s) => s.id == 'apple');
    final peach = SymbolRegistry.all.firstWhere((s) => s.id == 'peach');
    final watermelon = SymbolRegistry.all.firstWhere(
      (s) => s.id == 'watermelon',
    );
    final grapes = SymbolRegistry.all.firstWhere((s) => s.id == 'grapes');
    final banana = SymbolRegistry.all.firstWhere((s) => s.id == 'banana');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: heart,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: greenBear,
                  betAmount: betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: pinkBear,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: strawberry,
                  betAmount: betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: apple,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: peach,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: watermelon,
                  betAmount: betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: grapes,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: banana,
                  betAmount: betAmount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
