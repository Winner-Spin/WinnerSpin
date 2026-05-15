import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/widgets/money_text.dart';
import '../../domain/models/symbol_registry.dart';
import '../../domain/models/slot_symbol.dart';
import '../../domain/enums/symbol_tier.dart';
import '../audio/ui_click_sound.dart';
import 'widgets/multiplier_bomb_animation.dart';
import 'widgets/multiplier_label.dart';
import 'widgets/spring_popup_card.dart';

class GameRulesScreen extends StatefulWidget {
  final double betAmount;

  const GameRulesScreen({super.key, required this.betAmount});

  @override
  State<GameRulesScreen> createState() => _GameRulesScreenState();
}

class _GameRulesScreenState extends State<GameRulesScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _textColor = Color(0xFF2C2530);

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
                            color: _panelColor,
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
                                _buildHeader(context),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    thumbColor: _textColor.withValues(
                                      alpha: 0.25,
                                    ),
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
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(color: _textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'OYUN KURALLARI',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
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
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 30, color: _textColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _buildRulesDescription() {
    return Text(
      'Symbols pay anywhere on the 6x5 grid. Each tumble checks the total '
      'number of matching regular symbols on the screen and pays when 8 or more are present.',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _textColor.withValues(alpha: 0.88),
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
        _buildText('SCATTER can land anywhere on the grid.'),
        _buildText(
          'SCATTER pays by total count after all tumbles are complete.',
        ),
        const SizedBox(height: 16),
        _buildSectionTitle('DOUBLE CHANCE'),
        _buildText(
          'Double Chance increases the cost of a base spin to 1.25x the selected bet.',
        ),
        _buildText(
          'When Double Chance is active, the chance of naturally triggering FREE SPINS is doubled.',
        ),
        _buildText('BUY FEATURE is disabled while Double Chance is active.'),

        const SizedBox(height: 16),
        _buildSectionTitle('BUY FEATURE'),
        _buildText(
          'BUY FEATURE starts a FREE SPINS round immediately for 100x the selected bet.',
        ),
        _buildText(
          'Bought FREE SPINS rounds start with 10 free spins and use the same tumble and multiplier rules.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('TUMBLE FEATURE'),
        _buildText(
          'After a winning tumble, all winning regular symbols pop and disappear. The remaining symbols fall down and empty positions are filled from above.',
        ),
        _buildText(
          'Tumbling continues until no new combination appears as a result of a tumble. There is no limit to the number of possible tumbles.',
        ),
        _buildText(
          'All tumble wins from the spin are added together before any final multiplier is applied.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('FREE SPINS RULES'),
        _buildText(
          'The FREE SPINS feature is triggered when 4 or more SCATTER symbols land anywhere on the screen.',
        ),
        _buildText('The round starts with 10 free spins.'),
        _buildText(
          'During FREE SPINS, 3 or more SCATTER symbols award 5 additional free spins.',
        ),

        const SizedBox(height: 12),
        _buildInfoMultiplierBomb(size: 56),
        const SizedBox(height: 12),

        _buildTextWithBomb(
          'This is the MULTIPLIER symbol. It',
          ' can land in base spins and FREE SPINS. Multipliers stay on the grid until the tumble process ends.',
        ),
        _buildTextWithBomb(
          'When a ',
          ' symbol lands, it can show 2x, 3x, 5x, 10x, 25x, 50x or 100x.',
        ),
        _buildTextWithBomb(
          'When the tumble process ends, the values of all ',
          ' symbols left on the screen are added together. If there was a regular symbol win, the tumble win total is multiplied by that sum.',
        ),
        _buildText(
          'During FREE SPINS, multiplier symbols appear more often. Multiplier values always pay exactly as shown on the symbols.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('GAME RULES'),
        _buildVarianceBadge(),
        _buildText(
          'Medium volatility games pay regularly and the payout range can vary from low to very high.',
        ),
        _buildText('Symbols pay anywhere.'),
        _buildText(
          'Regular symbol and SCATTER payouts are multiplied by the selected bet.',
        ),
        _buildText(
          'Multiplier symbols do not pay by themselves; they multiply regular tumble wins.',
        ),
        _buildText(
          'When winning with multiple symbols, all wins are added to the total win.',
        ),
        _buildText('Free spins are awarded after the round is completed.'),
        _buildText(
          'Free spin total winnings history includes the total winnings of the series.',
        ),
        _buildText('Target RTP of this game is 96.5%.'),
        _buildText(
          'SPACE and ENTER keys on the keyboard can be used to start and stop the spin.\nMalfunction voids all pays and plays.',
        ),
        const SizedBox(height: 8),
        _buildBetLimitsText(),

        const SizedBox(height: 16),
        _buildSectionTitle('HOW TO PLAY'),
        _buildText(
          'Open BET SETTINGS from the menu to change the selected bet.',
        ),
        _buildText(
          'Use the plus and minus controls to choose one of the available bet levels.',
        ),
        _buildText(
          'Press SPIN to play. During FREE SPINS, spins do not charge the balance.',
        ),

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
        _buildText(
          'MUSIC and SOUND EFFECTS can be turned on and off separately.',
        ),
        _buildIconTextRow(Icons.open_in_new, 'opens the game history page.'),
        _buildIconTextRow(Icons.info_outline, 'opens the info page.'),
        _buildText(
          'CREDIT and BET labels show the current virtual balance and the current total virtual bet. Click the labels to switch between compact and detailed coin display.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('MENU'),
        _buildIconTextRow(Icons.autorenew, 'starts a spin or stops auto spin.'),
        _buildIconTextRow(
          Icons.play_circle_outline,
          'opens the auto play menu.',
        ),

        const SizedBox(height: 16),
        _buildSectionTitle('INFO SCREEN'),
        _buildText('Scroll up and down to read the game rules.'),
        _buildIconTextRow(Icons.close, 'closes the info screen.'),

        const SizedBox(height: 16),
        _buildSectionTitle('BET MENU'),
        _buildText(
          'BET SETTINGS shows the selected bet and the current total spin cost.',
        ),
        _buildText(
          'Use the plus and minus buttons to move through the available bet levels.',
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
            color: _textColor.withValues(alpha: 0.34),
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
                color: _textColor,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Text(
        title,
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _textColor,
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
          color: _textColor.withValues(alpha: 0.88),
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildBetLimitsText() {
    final style = GoogleFonts.nunito(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: _textColor.withValues(alpha: 0.88),
      height: 1.3,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        children: [
          _buildMoneyLine('MINIMUM BET:', '10.00', style),
          _buildMoneyLine('MAXIMUM BET:', '5000.00', style),
        ],
      ),
    );
  }

  Widget _buildMoneyLine(String label, String amount, TextStyle style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style),
        const SizedBox(width: 4),
        MoneyText(text: amount, style: style),
      ],
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
            color: _textColor.withValues(alpha: 0.88),
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
          Icon(icon, color: _textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: GoogleFonts.nunito(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _textColor.withValues(alpha: 0.88),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            ? _getScatterRangeText(threshold, sortedThresholds)
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

  String _getRangeText(int threshold, List<int> sortedThresholds) {
    final idx = sortedThresholds.indexOf(threshold);
    if (idx == 0) {
      return '$threshold+';
    }
    final nextHigher = sortedThresholds[idx - 1];
    return '$threshold - ${nextHigher - 1}';
  }

  String _getScatterRangeText(int threshold, List<int> sortedThresholds) {
    return sortedThresholds.indexOf(threshold) == 0
        ? '$threshold+'
        : '$threshold';
  }

  String _formatPayout(double value) {
    final parts = value.toStringAsFixed(2).split('.');
    return '${parts[0]},${parts[1]}';
  }
}

class _PayoutRow extends StatelessWidget {
  static const Color _textColor = Color(0xFF2C2530);

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
            color: _textColor.withValues(alpha: 0.90),
            height: 1.2,
          ),
        ),
        const SizedBox(width: 4),
        MoneyText(
          text: value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: _textColor.withValues(alpha: 0.90),
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
