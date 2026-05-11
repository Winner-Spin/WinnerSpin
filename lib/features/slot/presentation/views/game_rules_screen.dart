import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../domain/models/symbol_registry.dart';
import '../../domain/models/slot_symbol.dart';
import '../../domain/enums/symbol_tier.dart';
import '../audio/ui_click_sound.dart';
import 'widgets/multiplier_bomb_animation.dart';
import 'widgets/multiplier_label.dart';

/// Full-screen overlay showing game rules and symbol payout tables.
/// Opened from the info button on the game screen.
class GameRulesScreen extends StatefulWidget {
  /// Current bet amount — payouts are shown as bet × multiplier.
  final double betAmount;

  const GameRulesScreen({super.key, required this.betAmount});

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
          // Dimmed backdrop without blur
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          // Content card
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.81,
                      ),
                      child: Container(
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
                        child: ClipRRect(
                          child: Column(
                            children: [
                              _buildHeader(context),
                              Expanded(
                                child: RawScrollbar(
                                  controller: _scrollController,
                                  thumbVisibility: true,
                                  thumbColor: Colors.white.withValues(
                                    alpha: 0.3,
                                  ),
                                  thickness: 4,
                                  radius: const Radius.circular(8),
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      10,
                                    ),
                                    child: Column(
                                      children: [
                                        const SizedBox(height: 4),
                                        _buildSymbolPayoutGrid(),
                                        const SizedBox(height: 10),
                                        _buildRulesDescription(),
                                        _buildExtraRules(),
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
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Header with title and close button.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'GAME RULES',
            style: GoogleFonts.barlowCondensed(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 30,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the payout grid — high-tier symbols at top (2 per row),
  /// then mid-tier, then low-tier (3 per row), matching the reference layout.
  Widget _buildSymbolPayoutGrid() {
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
        // Row 1: Kalp, Yeşil Ayı
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: kalp,
                  betAmount: widget.betAmount,
                ),
              ),
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: yesilAyi,
                  betAmount: widget.betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Row 2: Pembe Ayı, Çilek
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: pembeAyi,
                  betAmount: widget.betAmount,
                ),
              ),
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: cilek,
                  betAmount: widget.betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Row 3: Elma, Şeftali (Portakal), Karpuz
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          child: Row(
            children: [
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: elma,
                  betAmount: widget.betAmount,
                ),
              ),
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: seftali,
                  betAmount: widget.betAmount,
                ),
              ),
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: karpuz,
                  betAmount: widget.betAmount,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Row 4: Üzüm, Muz
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            children: [
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: uzum,
                  betAmount: widget.betAmount,
                ),
              ),
              Expanded(
                child: _SymbolPayoutCard(
                  symbol: muz,
                  betAmount: widget.betAmount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Bottom description text explaining the payout mechanics.
  Widget _buildRulesDescription() {
    return Text(
      'Symbols pay anywhere on the screen. At the end of a spin, '
      'the total count of the same symbol on the screen determines the win value.',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.3,
      ),
    );
  }

  Widget _buildExtraRules() {
    final scatter = SymbolRegistry.all.firstWhere(
      (s) => s.tier == SymbolTier.scatter,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: _SymbolPayoutCard(
              symbol: scatter,
              betAmount: widget.betAmount,
              isHorizontal: true,
            ),
          ),
        ),
        _buildText('This is the SCATTER symbol.'),
        _buildText('The SCATTER symbol appears on all reels.'),
        _buildText('SCATTER pays in any position.'),
        const SizedBox(height: 16),
        _buildSectionTitle('ANTE BET'),
        _buildText(
          'The player has the option to choose a bet multiplier. Depending on the selected bet type, the game behaves differently. Possible values:',
        ),
        _buildText(
          '20x bet multiplier: grants the ability to BUY FREE SPINS ROUND by paying a value equal to 100x total bet.',
        ),
        _buildText(
          '25x bet multiplier: the chance of naturally winning free spins doubles. More SCATTER symbols appear on the reels. BUY FREE SPINS FEATURE is disabled.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('TUMBLE FEATURE'),
        _buildText(
          'TUMBLE FEATURE means that after each spin, winning combinations are paid and winning symbols disappear. Remaining symbols fall to the bottom of the screen and empty positions are replaced with symbols coming from above.',
        ),
        _buildText(
          'Tumbling continues until no new combination appears as a result of a tumble. There is no limit to the number of possible tumbles.',
        ),
        _buildText(
          'All wins are added to the player\'s balance after all tumbles from a base spin have been played.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('FREE SPINS RULES'),
        _buildText(
          'The FREE SPINS feature is triggered when 4 or more SCATTER symbols land anywhere on the screen.',
        ),
        _buildText('The round starts with 10 free spins.'),
        _buildText(
          'During the FREE SPINS ROUND, when 3 or more SCATTER symbols are caught, 5 additional free spins are awarded.',
        ),

        const SizedBox(height: 12),
        _buildInfoMultiplierBomb(size: 56),
        const SizedBox(height: 12),

        _buildTextWithBomb(
          'This is the MULTIPLIER symbol. It',
          ' only appears on the reels during the FREE SPINS ROUND and remains on the screen until the end of the tumble process.',
        ),
        _buildTextWithBomb(
          'When a ',
          ' symbol lands, it takes a random multiplier value of 2x, 3x, 4x, 5x, 6x, 8x, 10x, 12x, 15x, 20x, 25x, 50x or 100x.',
        ),
        _buildTextWithBomb(
          'When the tumble process ends, the values of all ',
          ' symbols on the screen are added together and the total win of the process is multiplied by the final value.',
        ),
        _buildText('Special reels are in play during FREE SPINS ROUNDS.'),

        const SizedBox(height: 16),
        _buildSectionTitle('GAME RULES'),
        _buildVarianceBadge(),
        _buildText(
          'Medium volatility games pay regularly and the payout range can vary from low to very high.',
        ),
        _buildText('Symbols pay anywhere.'),
        _buildText('All wins are multiplied by the base bet.'),
        _buildText(
          'All values are expressed in terms of actual coin winnings.',
        ),
        _buildText(
          'When winning with multiple symbols, all wins are added to the total win.',
        ),
        _buildText('Free spins are awarded after the round is completed.'),
        _buildText(
          'Free spin total winnings history includes the total winnings of the series.',
        ),
        _buildText(
          'Maximum RTP of this game is 95.5%\nMinimum RTP of this game is 95.45%',
        ),
        _buildText(
          'SPACE and ENTER keys on the keyboard can be used to start and stop the spin.\nMalfunction voids all pays and plays.',
        ),
        const SizedBox(height: 8),
        _buildText('MINIMUM BET: 0.20 \$\nMAXIMUM BET: 125.00 \$'),

        const SizedBox(height: 16),
        _buildSectionTitle('HOW TO PLAY'),
        _buildText('Click the 🪙 button to open the bet menu.'),
        _buildText(
          'Select your bet by adjusting the values using the ➕ and ➖ buttons.',
        ),
        _buildText('Press the SPIN button to play.'),

        const SizedBox(height: 16),
        _buildSectionTitle('MENU'),
        _buildIconTextRow(
          Icons.settings,
          'opens the menu containing settings that affect how the game is played.',
        ),
        _buildIconTextRow(
          Icons.fast_forward,
          'spin speed settings switch between normal speed, fast spin, and turbo spin.',
        ),
        _buildText(
          'BATTERY SAVER: helps reduce the game\'s battery consumption and may help prevent the device from overheating during long gaming sessions.',
        ),
        _buildText('SOUND: turns sound and music on and off.'),
        _buildIconTextRow(Icons.open_in_new, 'opens the game history page.'),
        _buildIconTextRow(Icons.info_outline, 'opens the info page.'),
        _buildText(
          'CREDIT and BET labels show the current balance and the current total bet. Click the labels to switch between coin view and money view.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('MENU'),
        _buildIconTextRow(Icons.autorenew, 'starts the game.'),
        _buildIconTextRow(
          Icons.play_circle_outline,
          'opens the auto play menu.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('INFO SCREEN'),
        _buildText(
          'Drag the pages up and down to navigate between info pages.',
        ),
        _buildIconTextRow(Icons.close, 'closes the info screen.'),

        const SizedBox(height: 16),
        _buildSectionTitle('BET MENU'),
        _buildText(
          'The bet menu shows the available bet multiplier and the current total bet in both coins and cash.',
        ),
        _buildText(
          'Use the ➕ and ➖ buttons in the BET and COIN VALUE fields to change values.',
        ),
      ],
    );
  }

  Widget _buildVarianceBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.8),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'VARIANCE',
              style: GoogleFonts.barlowCondensed(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(width: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                5,
                (index) => const Icon(
                  Icons.flash_on,
                  color: Color(0xFFFFD700), // Gold/Yellow color
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildText(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.nunito(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildInfoMultiplierBomb({required double size}) {
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

  Widget _buildTextWithBomb(String text1, String text2) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: GoogleFonts.nunito(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
            height: 1.3,
          ),
          children: [
            TextSpan(text: text1),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                child: _buildInfoMultiplierBomb(size: 20),
              ),
            ),
            TextSpan(text: text2),
          ],
        ),
      ),
    );
  }

  Widget _buildIconTextRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single symbol card showing the image and its payout tiers.
class _SymbolPayoutCard extends StatelessWidget {
  final SlotSymbol symbol;
  final double betAmount;
  final bool isHorizontal;

  const _SymbolPayoutCard({
    required this.symbol,
    required this.betAmount,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final payouts = symbol.isScatter ? symbol.scatterPayouts : symbol.payouts;
    // Sort thresholds descending (12+, 10-11, 8-9) to match reference
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
            ? '$threshold'
            : _getRangeText(threshold, sortedThresholds);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 0),
          child: _PayoutRow(range: rangeText, value: _formatPayout(payout)),
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

  /// Formats the range label. E.g., for threshold 12 -> "12+",
  /// for 10 (next is 12) -> "10 - 11", for 8 (next is 10) -> "8 - 9".
  String _getRangeText(int threshold, List<int> sortedThresholds) {
    final idx = sortedThresholds.indexOf(threshold);
    if (idx == 0) {
      // Highest threshold — open-ended
      return '$threshold+';
    }
    // Range ends just before the next higher threshold
    final nextHigher = sortedThresholds[idx - 1];
    return '$threshold - ${nextHigher - 1}';
  }

  String _formatPayout(double value) {
    // Format with two decimals, using comma as decimal separator
    final parts = value.toStringAsFixed(2).split('.');
    return '${parts[0]},${parts[1]} ₺';
  }
}

class _PayoutRow extends StatelessWidget {
  final String range;
  final String value;

  const _PayoutRow({required this.range, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          range,
          style: GoogleFonts.barlowCondensed(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.2,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
