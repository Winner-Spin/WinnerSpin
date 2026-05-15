import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'spring_popup_card.dart';

class FirstLaunchDisclaimerDialog extends StatelessWidget {
  final VoidCallback onOkay;

  const FirstLaunchDisclaimerDialog({super.key, required this.onOkay});

  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _textColor = Color(0xFF2C2530);
  static const String _bodyText =
      'This project is created solely for entertainment and portfolio purposes. It does not offer real-money gambling, betting, cash prizes, or withdrawal services. All coins, spins, bonuses, and rewards included in this project are entirely virtual; they have no real-world monetary value and cannot be purchased, sold, or converted into money in any way. This project does not promote or encourage gambling or betting activities.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.42)),
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
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
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
                                _buildHeader(),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      24,
                                      22,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          _bodyText,
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: _textColor,
                                            height: 1.18,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        _buildOkayButton(),
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

  Widget _buildHeader() {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: const BoxDecoration(
        color: Color(0xFFF6D7EB),
        border: Border(bottom: BorderSide(color: Color(0x1A2C2530))),
      ),
      child: Center(
        child: Text(
          'DISCLAIMER',
          style: GoogleFonts.barlowCondensed(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            color: _textColor,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildOkayButton() {
    return GestureDetector(
      onTap: onOkay,
      child: Container(
        width: double.infinity,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF00C76A),
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
          'OKAY',
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
