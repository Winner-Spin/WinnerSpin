import 'package:flutter/material.dart';

import '../../audio/ui_click_sound.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'widgets/deposit_amount_selector.dart';
import 'widgets/deposit_buy_button.dart';
import 'widgets/deposit_credit_line.dart';
import 'widgets/deposit_disclaimer.dart';
import 'widgets/deposit_money_header.dart';
import '../shared/widgets/spring_popup_card.dart';

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

  void _close() {
    UiClickSound.play();
    Navigator.of(context).pop();
  }

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
    try {
      await widget.viewModel.purchaseGameMoney(_selectedAmount);
    } finally {
      if (mounted) {
        setState(() => _isBuying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
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
                                DepositMoneyHeader(
                                  textColor: _textColor,
                                  panelAccent: _panelAccent,
                                  onClose: _close,
                                ),
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
                                        ListenableBuilder(
                                          listenable:
                                              widget.viewModel.balanceCtrl,
                                          builder: (context, _) {
                                            return DepositCreditLine(
                                              balance: widget.viewModel.balance,
                                              textColor: _textColor,
                                            );
                                          },
                                        ),
                                        DepositAmountSelector(
                                          amount: _selectedAmount,
                                          canDecrease:
                                              _canDecrease && !_isBuying,
                                          canIncrease:
                                              _canIncrease && !_isBuying,
                                          textColor: _textColor,
                                          onDecrease: _decreaseAmount,
                                          onIncrease: _increaseAmount,
                                        ),
                                        Column(
                                          children: [
                                            DepositBuyButton(
                                              isBuying: _isBuying,
                                              onTap: _buy,
                                            ),
                                            const SizedBox(height: 10),
                                            const DepositDisclaimer(
                                              textColor: _textColor,
                                            ),
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
