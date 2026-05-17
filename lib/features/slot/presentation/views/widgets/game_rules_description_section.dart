import 'package:flutter/material.dart';

import '../../models/game_rules_styles.dart';

class GameRulesDescriptionSection extends StatelessWidget {
  const GameRulesDescriptionSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Symbols pay anywhere on the 6x5 grid. Each tumble checks the total '
      'number of matching regular symbols on the screen and pays when 8 or more are present.',
      textAlign: TextAlign.center,
      style: GameRulesStyles.bodyText(),
    );
  }
}
