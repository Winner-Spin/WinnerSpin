import 'package:flutter/material.dart';

import '../../../../domain/models/symbol_registry.dart';
import 'game_rules_symbol_payout_card.dart';

class GameRulesSymbolPayoutGrid extends StatelessWidget {
  const GameRulesSymbolPayoutGrid({super.key, required this.betAmount});

  final double betAmount;

  @override
  Widget build(BuildContext context) {
    final kalp = SymbolRegistry.all.firstWhere((s) => s.id == 'kalp');
    final yesilAyi = SymbolRegistry.all.firstWhere((s) => s.id == 'yesil_ayi');
    final pembeAyi = SymbolRegistry.all.firstWhere((s) => s.id == 'pembe_ayi');
    final cilek = SymbolRegistry.all.firstWhere((s) => s.id == 'cilek');
    final elma = SymbolRegistry.all.firstWhere((s) => s.id == 'elma');
    final seftali = SymbolRegistry.all.firstWhere((s) => s.id == 'seftali');
    final karpuz = SymbolRegistry.all.firstWhere((s) => s.id == 'karpuz');
    final uzum = SymbolRegistry.all.firstWhere((s) => s.id == 'uzum');
    final muz = SymbolRegistry.all.firstWhere((s) => s.id == 'muz');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: kalp,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: yesilAyi,
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
                  symbol: pembeAyi,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: cilek,
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
                  symbol: elma,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: seftali,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: karpuz,
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
                  symbol: uzum,
                  betAmount: betAmount,
                ),
              ),
              Expanded(
                child: GameRulesSymbolPayoutCard(
                  symbol: muz,
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
