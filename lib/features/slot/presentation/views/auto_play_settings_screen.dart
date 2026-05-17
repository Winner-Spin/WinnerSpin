import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/auto_play_header.dart';
import 'widgets/auto_play_spin_count_slider.dart';
import 'widgets/auto_play_start_button.dart';
import 'widgets/spring_popup_card.dart';

class AutoPlaySettingsScreen extends StatefulWidget {
  const AutoPlaySettingsScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<AutoPlaySettingsScreen> createState() => _AutoPlaySettingsScreenState();
}

class _AutoPlaySettingsScreenState extends State<AutoPlaySettingsScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _panelAccent = Color(0xFFE2BED8);

  static const List<int> _spinCounts = [
    10,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  int _spinCountIndex = 9;

  int get _spinCount => _spinCounts[_spinCountIndex];

  void _close() {
    UiClickSound.play();
    Navigator.of(context).pop();
  }

  void _startAutoPlay() {
    widget.viewModel.startAutoSpin(
      _spinCount,
      speedMultiplier: widget.viewModel.speedMultiplier,
    );
    Navigator.of(context).pop();
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
                                AutoPlayHeader(
                                  textColor: _textColor,
                                  panelAccent: _panelAccent,
                                  onClose: _close,
                                ),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      42,
                                      22,
                                      24,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'AUTOSPIN COUNT',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.barlowCondensed(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: _textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        AutoPlaySpinCountSlider(
                                          spinCount: _spinCount,
                                          spinCountIndex: _spinCountIndex,
                                          maxIndex: _spinCounts.length - 1,
                                          textColor: _textColor,
                                          onChanged: (value) {
                                            setState(
                                              () => _spinCountIndex = value,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 40),
                                        ListenableBuilder(
                                          listenable: widget.viewModel,
                                          builder: (context, _) {
                                            final disabled =
                                                widget.viewModel.isBusy ||
                                                widget.viewModel.isAutoSpinning;
                                            return AutoPlayStartButton(
                                              spinCount: _spinCount,
                                              disabled: disabled,
                                              onTap: () {
                                                UiClickSound.play();
                                                _startAutoPlay();
                                              },
                                            );
                                          },
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
