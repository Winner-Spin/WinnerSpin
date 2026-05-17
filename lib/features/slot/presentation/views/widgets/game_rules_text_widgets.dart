import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../../../core/widgets/money_text.dart';
import '../../models/game_rules_styles.dart';
import 'multiplier_bomb_animation.dart';
import 'multiplier_label.dart';

class GameRulesSectionTitle extends StatelessWidget {
  const GameRulesSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GameRulesStyles.sectionTitle(),
      ),
    );
  }
}

class GameRulesText extends StatelessWidget {
  const GameRulesText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GameRulesStyles.bodyText(),
      ),
    );
  }
}

class GameRulesBetLimitsText extends StatelessWidget {
  const GameRulesBetLimitsText({super.key});

  @override
  Widget build(BuildContext context) {
    final style = GameRulesStyles.bodyText();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          _MoneyLine('MINIMUM BET:', '10.00', style),
          _MoneyLine('MAXIMUM BET:', '5000.00', style),
        ],
      ),
    );
  }
}

class GameRulesMultiplierBomb extends StatelessWidget {
  const GameRulesMultiplierBomb({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Transform.scale(
            scale: MultiplierLabel.bombScaleFor(100),
            child: Lottie.asset(
              MultiplierBombAnimation.assetPath,
              fit: BoxFit.contain,
              animate: false,
            ),
          ),
          Align(
            alignment: Alignment(MultiplierLabel.labelXOffsetFor(100), 0.22),
            child: const FractionallySizedBox(
              widthFactor: 1.0,
              heightFactor: 0.43,
              child: MultiplierLabel(value: 100, fit: BoxFit.fitHeight),
            ),
          ),
        ],
      ),
    );
  }
}

class GameRulesTextWithBomb extends StatelessWidget {
  const GameRulesTextWithBomb({
    super.key,
    required this.textBeforeBomb,
    required this.textAfterBomb,
  });

  final String textBeforeBomb;
  final String textAfterBomb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GameRulesStyles.bodyText(),
          children: [
            TextSpan(text: textBeforeBomb),
            const WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.0),
                child: GameRulesMultiplierBomb(size: 20),
              ),
            ),
            TextSpan(text: textAfterBomb),
          ],
        ),
      ),
    );
  }
}

class GameRulesIconTextRow extends StatelessWidget {
  const GameRulesIconTextRow(this.icon, this.text, {super.key});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GameRulesStyles.textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: GameRulesStyles.bodyText(),
            ),
          ),
        ],
      ),
    );
  }
}

class GameRulesVarianceBadge extends StatelessWidget {
  const GameRulesVarianceBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: GameRulesStyles.textColor.withValues(alpha: 0.34),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VARIANCE', style: GameRulesStyles.varianceLabel()),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (index) => const Icon(
                  Icons.flash_on,
                  color: Color(0xFFD19A00),
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine(this.label, this.amount, this.style);

  final String label;
  final String amount;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style),
        const SizedBox(width: 4),
        MoneyText(text: amount, style: style),
      ],
    );
  }
}
