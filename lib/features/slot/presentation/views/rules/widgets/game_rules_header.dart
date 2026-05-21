import 'package:flutter/material.dart';

import '../../../audio/ui_click_sound.dart';
import '../../../models/game_rules_styles.dart';

class GameRulesHeader extends StatelessWidget {
  const GameRulesHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(
            color: GameRulesStyles.textColor.withValues(alpha: 0.10),
          ),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text('GAME RULES', style: GameRulesStyles.headerTitle()),
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
                  color: GameRulesStyles.panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 30,
                  color: GameRulesStyles.textColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
