import 'package:flutter/material.dart';

import '../../../../domain/enums/symbol_tier.dart';
import '../../../../domain/models/symbol_registry.dart';
import 'game_rules_symbol_payout_card.dart';
import 'game_rules_text_widgets.dart';

class GameRulesExtraSection extends StatelessWidget {
  const GameRulesExtraSection({super.key, required this.betAmount});

  final double betAmount;

  @override
  Widget build(BuildContext context) {
    final scatter = SymbolRegistry.all.firstWhere(
      (symbol) => symbol.tier == SymbolTier.scatter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: GameRulesSymbolPayoutCard(
              symbol: scatter,
              betAmount: betAmount,
              isHorizontal: true,
            ),
          ),
        ),
        const GameRulesText('This is the SCATTER symbol.'),
        const GameRulesText('SCATTER can land anywhere on the grid.'),
        const GameRulesText(
          'SCATTER pays by total count after all tumbles are complete.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('DOUBLE CHANCE'),
        const GameRulesText(
          'Double Chance increases the cost of a base spin to 1.25x the selected bet.',
        ),
        const GameRulesText(
          'When Double Chance is active, the chance of naturally triggering FREE SPINS is doubled.',
        ),
        const GameRulesText(
          'BUY FEATURE is disabled while Double Chance is active.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('BUY FEATURE'),
        const GameRulesText(
          'BUY FEATURE starts a FREE SPINS round immediately for 100x the selected bet.',
        ),
        const GameRulesText(
          'Bought FREE SPINS rounds start with 10 free spins and use the same tumble and multiplier rules.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('TUMBLE FEATURE'),
        const GameRulesText(
          'After a winning tumble, all winning regular symbols pop and disappear. The remaining symbols fall down and empty positions are filled from above.',
        ),
        const GameRulesText(
          'Tumbling continues until no new combination appears as a result of a tumble. There is no limit to the number of possible tumbles.',
        ),
        const GameRulesText(
          'All tumble wins from the spin are added together before any final multiplier is applied.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('FREE SPINS RULES'),
        const GameRulesText(
          'The FREE SPINS feature is triggered when 4 or more SCATTER symbols land anywhere on the screen.',
        ),
        const GameRulesText('The round starts with 10 free spins.'),
        const GameRulesText(
          'During FREE SPINS, 3 or more SCATTER symbols award 5 additional free spins.',
        ),
        const SizedBox(height: 12),
        const GameRulesMultiplierBomb(size: 56),
        const SizedBox(height: 12),
        const GameRulesTextWithBomb(
          textBeforeBomb: 'This is the MULTIPLIER symbol. It',
          textAfterBomb:
              ' can land in base spins and FREE SPINS. Multipliers stay on the grid until the tumble process ends.',
        ),
        const GameRulesTextWithBomb(
          textBeforeBomb: 'When a ',
          textAfterBomb:
              ' symbol lands, it can show 2x, 3x, 5x, 10x, 25x, 50x or 100x.',
        ),
        const GameRulesTextWithBomb(
          textBeforeBomb: 'When the tumble process ends, the values of all ',
          textAfterBomb:
              ' symbols left on the screen are added together. If there was a regular symbol win, the tumble win total is multiplied by that sum.',
        ),
        const GameRulesText(
          'During FREE SPINS, multiplier symbols appear more often. Multiplier values always pay exactly as shown on the symbols.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('GAME RULES'),
        const GameRulesVarianceBadge(),
        const GameRulesText(
          'Medium volatility games pay regularly and the payout range can vary from low to very high.',
        ),
        const GameRulesText('Symbols pay anywhere.'),
        const GameRulesText(
          'Regular symbol and SCATTER payouts are multiplied by the selected bet.',
        ),
        const GameRulesText(
          'Multiplier symbols do not pay by themselves; they multiply regular tumble wins.',
        ),
        const GameRulesText(
          'When winning with multiple symbols, all wins are added to the total win.',
        ),
        const GameRulesText(
          'Free spins are awarded after the round is completed.',
        ),
        const GameRulesText(
          'Free spin total winnings history includes the total winnings of the series.',
        ),
        const GameRulesText('Target RTP of this game is 96.5%.'),
        const GameRulesText(
          'SPACE and ENTER keys on the keyboard can be used to start and stop the spin.\nMalfunction voids all pays and plays.',
        ),
        const SizedBox(height: 8),
        const GameRulesBetLimitsText(),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('HOW TO PLAY'),
        const GameRulesText(
          'Open BET SETTINGS from the menu to change the selected bet.',
        ),
        const GameRulesText(
          'Use the plus and minus controls to choose one of the available bet levels.',
        ),
        const GameRulesText(
          'Press SPIN to play. During FREE SPINS, spins do not charge the balance.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('MENU'),
        const GameRulesIconTextRow(
          Icons.settings,
          'opens the menu containing settings that affect how the game is played.',
        ),
        const GameRulesIconTextRow(
          Icons.fast_forward,
          'spin speed settings switch between normal speed, fast spin, and turbo spin.',
        ),
        const GameRulesText(
          'BATTERY SAVER: helps reduce the game\'s battery consumption and may help prevent the device from overheating during long gaming sessions.',
        ),
        const GameRulesText(
          'MUSIC and SOUND EFFECTS can be turned on and off separately.',
        ),
        const GameRulesIconTextRow(
          Icons.open_in_new,
          'opens the game history page.',
        ),
        const GameRulesIconTextRow(Icons.info_outline, 'opens the info page.'),
        const GameRulesText(
          'CREDIT and BET labels show the current virtual balance and the current total virtual bet. Click the labels to switch between compact and detailed coin display.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('MENU'),
        const GameRulesIconTextRow(
          Icons.autorenew,
          'starts a spin or stops auto spin.',
        ),
        const GameRulesIconTextRow(
          Icons.play_circle_outline,
          'opens the auto play menu.',
        ),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('INFO SCREEN'),
        const GameRulesText('Scroll up and down to read the game rules.'),
        const GameRulesIconTextRow(Icons.close, 'closes the info screen.'),
        const SizedBox(height: 16),
        const GameRulesSectionTitle('BET MENU'),
        const GameRulesText(
          'BET SETTINGS shows the selected bet and the current total spin cost.',
        ),
        const GameRulesText(
          'Use the plus and minus buttons to move through the available bet levels.',
        ),
      ],
    );
  }
}
