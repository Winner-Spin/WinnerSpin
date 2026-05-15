import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../audio/ui_click_sound.dart';
import 'widgets/spring_popup_card.dart';

const Color _panelColor = Color(0xFFF0CDE6);
const Color _panelAccent = Color(0xFFE2BED8);
const Color _textColor = Color(0xFF2C2530);

class BuyFreeSpinsConfirmScreen extends StatelessWidget {
  final int spinCount;
  final double price;

  const BuyFreeSpinsConfirmScreen({
    super.key,
    required this.spinCount,
    required this.price,
  });

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
                Navigator.of(context).pop(false);
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
                    alignment: Alignment.center,
                    child: SpringPopupCard(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.92,
                          maxHeight: MediaQuery.of(context).size.height * 0.46,
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
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      24,
                                      22,
                                      22,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _buildPackageInfo(),
                                        _buildPriceBox(),
                                        _buildActions(context),
                                      ],
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
            'BUY FEATURE',
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
                Navigator.of(context).pop(false);
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

  Widget _buildPackageInfo() {
    return Column(
      children: [
        Text(
          'FREE SPINS PACKAGE',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$spinCount FREE SPINS',
          textAlign: TextAlign.center,
          style: GoogleFonts.barlowCondensed(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildPriceBox() {
    return Container(
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _textColor.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'COST',
            style: GoogleFonts.barlowCondensed(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _textColor.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(width: 10),
          MoneyText(
            text: formatMoney(price),
            symbolOffset: const Offset(0, 2.0),
            lineYOffset: 2.35,
            symbolTextYOffset: 2.3,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ConfirmActionButton(
            label: 'NO',
            color: const Color(0xFFE5485B),
            onTap: () {
              UiClickSound.play();
              Navigator.of(context).pop(false);
            },
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _ConfirmActionButton(
            label: 'YES',
            color: const Color(0xFF00C76A),
            onTap: () {
              UiClickSound.play();
              Navigator.of(context).pop(true);
            },
          ),
        ),
      ],
    );
  }
}

class _ConfirmActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ConfirmActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.32),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.barlowCondensed(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
