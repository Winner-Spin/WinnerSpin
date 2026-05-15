import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';

class DepositMoneyScreen extends StatefulWidget {
  final GameViewModel viewModel;

  const DepositMoneyScreen({super.key, required this.viewModel});

  @override
  State<DepositMoneyScreen> createState() => _DepositMoneyScreenState();
}

class _DepositMoneyScreenState extends State<DepositMoneyScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _textColor = Color(0xFF2C2530);
  static const List<double> _moneyTiers = [
    1000,
    2500,
    5000,
    10000,
    25000,
    50000,
    100000,
  ];

  int _selectedTier = 3;
  bool _isBuying = false;

  double get _selectedAmount => _moneyTiers[_selectedTier];
  bool get _canDecrease => _selectedTier > 0;
  bool get _canIncrease => _selectedTier < _moneyTiers.length - 1;

  void _decreaseAmount() {
    if (!_canDecrease || _isBuying) return;
    UiClickSound.play();
    setState(() => _selectedTier--);
  }

  void _increaseAmount() {
    if (!_canIncrease || _isBuying) return;
    UiClickSound.play();
    setState(() => _selectedTier++);
  }

  Future<void> _buy() async {
    if (_isBuying) return;
    UiClickSound.play();
    setState(() => _isBuying = true);
    await widget.viewModel.purchaseGameMoney(_selectedAmount);
    if (!mounted) return;
    setState(() => _isBuying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: GestureDetector(
                onTap: () {
                  UiClickSound.play();
                  Navigator.of(context).pop();
                },
                child: Container(color: Colors.black.withValues(alpha: 0.42)),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.92,
                        maxHeight: MediaQuery.of(context).size.height * 0.54,
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
                                      _buildCreditLine(),
                                      _buildMoneyAmount(),
                                      Column(
                                        children: [
                                          _buildBuyButton(),
                                          const SizedBox(height: 10),
                                          _buildDepositDisclaimer(),
                                        ],
                                      ),
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
            'DEPOSIT MONEY',
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

  Widget _buildCreditLine() {
    return ListenableBuilder(
      listenable: widget.viewModel.balanceCtrl,
      builder: (context, _) {
        return Column(
          children: [
            Text(
              'CURRENT CREDIT',
              style: GoogleFonts.barlowCondensed(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _textColor.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 5),
            MoneyText(
              text: formatMoney(widget.viewModel.balance),
              symbolOffset: const Offset(0, 2.0),
              lineYOffset: 2.35,
              symbolTextYOffset: 2.3,
              style: GoogleFonts.barlowCondensed(
                fontSize: 25,
                fontWeight: FontWeight.w900,
                color: _textColor,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMoneyAmount() {
    return Column(
      children: [
        Text(
          'GAME MONEY AMOUNT',
          style: GoogleFonts.barlowCondensed(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildAmountButton(
              icon: Icons.remove,
              onTap: _decreaseAmount,
              enabled: _canDecrease && !_isBuying,
            ),
            const SizedBox(width: 16),
            Container(
              width: 150,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF6D7EB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _textColor.withValues(alpha: 0.18),
                  width: 1.5,
                ),
              ),
              child: MoneyText(
                text: formatMoney(_selectedAmount),
                symbolOffset: const Offset(0, 2.0),
                lineYOffset: 2.35,
                symbolTextYOffset: 2.3,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _textColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            _buildAmountButton(
              icon: Icons.add,
              onTap: _increaseAmount,
              enabled: _canIncrease && !_isBuying,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAmountButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.black, size: 28),
        ),
      ),
    );
  }

  Widget _buildBuyButton() {
    return GestureDetector(
      onTap: _isBuying ? null : _buy,
      child: AnimatedOpacity(
        opacity: _isBuying ? 0.65 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 48,
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
            _isBuying ? 'ADDING...' : 'BUY GAME MONEY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepositDisclaimer() {
    return Text(
      'This deposit action is not a real-money deposit. It only increases virtual in-game CREDIT with virtual game money that has no real-world value.',
      textAlign: TextAlign.center,
      style: GoogleFonts.barlowCondensed(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _textColor.withValues(alpha: 0.72),
        height: 1.08,
      ),
    );
  }
}
