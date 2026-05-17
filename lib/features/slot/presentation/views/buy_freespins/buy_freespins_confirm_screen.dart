import 'package:flutter/material.dart';

import '../../audio/ui_click_sound.dart';
import 'widgets/buy_freespins_confirm_actions.dart';
import 'widgets/buy_freespins_confirm_header.dart';
import 'widgets/buy_freespins_package_info.dart';
import 'widgets/buy_freespins_price_box.dart';
import '../shared/widgets/spring_popup_card.dart';

const Color _panelColor = Color(0xFFF0CDE6);
const Color _panelAccent = Color(0xFFE2BED8);
const Color _textColor = Color(0xFF2C2530);

class BuyFreeSpinsConfirmScreen extends StatelessWidget {
  const BuyFreeSpinsConfirmScreen({
    super.key,
    required this.spinCount,
    required this.price,
  });

  final int spinCount;
  final double price;

  void _close(BuildContext context, bool confirmed) {
    UiClickSound.play();
    Navigator.of(context).pop(confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _close(context, false),
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
                                BuyFreeSpinsConfirmHeader(
                                  textColor: _textColor,
                                  panelAccent: _panelAccent,
                                  onClose: () => _close(context, false),
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
                                        BuyFreeSpinsPackageInfo(
                                          spinCount: spinCount,
                                          textColor: _textColor,
                                        ),
                                        BuyFreeSpinsPriceBox(
                                          price: price,
                                          textColor: _textColor,
                                        ),
                                        BuyFreeSpinsConfirmActions(
                                          onCancel: () =>
                                              _close(context, false),
                                          onConfirm: () =>
                                              _close(context, true),
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
