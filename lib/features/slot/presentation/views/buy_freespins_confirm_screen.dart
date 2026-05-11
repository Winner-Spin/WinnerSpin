import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import 'widgets/confirm_button.dart';

/// Full-screen confirmation overlay shown before a Buy FS purchase is
/// committed. Same black-card structure as the info / settings screens
/// so the prompt reads as part of the same UI family. Two large
/// confirm buttons drive the decision — YES executes the buy, NO
/// dismisses the dialog without charging anything.
class BuyFreeSpinsConfirmScreen extends StatelessWidget {
  final int spinCount;
  final double price;
  final VoidCallback onConfirm;

  const BuyFreeSpinsConfirmScreen({
    super.key,
    required this.spinCount,
    required this.price,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cardMaxHeight = size.height * 0.50;
    final buttonWidth = size.width * 0.22;
    final buttonHeight = size.width * 0.10;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Tap-outside-to-dismiss backdrop. Transparent so the game
          // screen behind it stays visible through the dialog gap.
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: cardMaxHeight),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.93),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: size.width * 0.04,
                  vertical: size.height * 0.04,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ConfirmPrompt(spinCount: spinCount, price: price),
                    SizedBox(height: size.height * 0.035),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ConfirmButton(
                          label: 'YES',
                          variant: ConfirmButtonVariant.yes,
                          width: buttonWidth,
                          height: buttonHeight,
                          onTap: () {
                            Navigator.of(context).pop();
                            onConfirm();
                          },
                        ),
                        ConfirmButton(
                          label: 'NO',
                          variant: ConfirmButtonVariant.no,
                          width: buttonWidth,
                          height: buttonHeight,
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-line confirmation text. Counts and currency amounts are
/// painted in the same gold accent the DoubleChanceButton uses for
/// its bet readout and lifted a touch larger so they read as the
/// emphasis points the player is being asked to confirm.
class _ConfirmPrompt extends StatelessWidget {
  final int spinCount;
  final double price;

  const _ConfirmPrompt({required this.spinCount, required this.price});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final baseSize = width * 0.062;
    final accentSize = baseSize * 1.28;
    final base = GoogleFonts.outfit(
      fontSize: baseSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.5,
      height: 1.15,
      color: const Color(0xFFB8D8FF),
      shadows: const [
        Shadow(
          color: Color(0xCC000000),
          offset: Offset(0, 2),
          blurRadius: 3,
        ),
      ],
    );
    final accent = base.copyWith(
      fontSize: accentSize,
      fontWeight: FontWeight.w900,
      color: const Color(0xFFFFC93C),
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'ARE YOU SURE YOU WANT TO PURCHASE\n'),
          TextSpan(text: '$spinCount ', style: accent),
          const TextSpan(text: 'FREE SPINS\n'),
          const TextSpan(text: 'AT THE COST OF '),
          TextSpan(text: '₺${formatMoney(price)}', style: accent),
          const TextSpan(text: ' ?'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
