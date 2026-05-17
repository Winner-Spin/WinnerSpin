import 'package:flutter/material.dart';

import '../../audio/ui_click_sound.dart';
import '../../models/game_rules_styles.dart';
import 'widgets/game_rules_description_section.dart';
import 'widgets/game_rules_extra_section.dart';
import 'widgets/game_rules_header.dart';
import 'widgets/game_rules_symbol_payout_grid.dart';
import '../shared/widgets/spring_popup_card.dart';

class GameRulesScreen extends StatefulWidget {
  const GameRulesScreen({super.key, required this.betAmount});

  final double betAmount;

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> {
  final ScrollController _scrollController = ScrollController();

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
                            color: GameRulesStyles.panelColor,
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
                                const GameRulesHeader(),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    thumbColor: GameRulesStyles.textColor
                                        .withValues(alpha: 0.25),
                                    thickness: 4,
                                    radius: const Radius.circular(8),
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        18,
                                        20,
                                        18,
                                        18,
                                      ),
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 4),
                                          GameRulesSymbolPayoutGrid(
                                            betAmount: widget.betAmount,
                                          ),
                                          const SizedBox(height: 10),
                                          const GameRulesDescriptionSection(),
                                          GameRulesExtraSection(
                                            betAmount: widget.betAmount,
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
        ],
      ),
    );
  }
}
