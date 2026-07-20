import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../audio/ui_click_sound.dart';
import '../../../domain/models/symbol_registry.dart';
import '../../viewmodels/game_viewmodel.dart';
import '../deposit/deposit_money_screen.dart';
import '../history/game_history_screen.dart';
import '../profile/profile_screen.dart';
import '../shared/widgets/spring_popup_card.dart';
import '../shared/widgets/spring_popup_transition.dart';
import 'widgets/system_settings_bet_section.dart';
import 'widgets/system_settings_footer.dart';
import 'widgets/system_settings_header.dart';
import 'widgets/system_settings_history_entry.dart';
import 'widgets/system_settings_profile_entry.dart';
import 'widgets/system_settings_row.dart';

class SystemSettingsScreen extends StatefulWidget {
  final GameViewModel viewModel;

  const SystemSettingsScreen({super.key, required this.viewModel});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _textColor = Color(0xFF2C2530);

  final ScrollController _scrollController = ScrollController();
  bool _showGameHistory = false;
  bool _showProfile = false;

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
                                SystemSettingsHeader(
                                  title: 'SETTINGS',
                                  textColor: _textColor,
                                  panelAccent: _panelAccent,
                                  onClose: () {
                                    UiClickSound.play();
                                    Navigator.of(context).pop();
                                  },
                                ),
                                Expanded(
                                  child: RawScrollbar(
                                    controller: _scrollController,
                                    thumbVisibility: true,
                                    thumbColor: _textColor.withValues(
                                      alpha: 0.25,
                                    ),
                                    thickness: 6,
                                    radius: const Radius.circular(8),
                                    padding: const EdgeInsets.only(
                                      right: 4,
                                      top: 4,
                                      bottom: 4,
                                    ),
                                    child: SingleChildScrollView(
                                      controller: _scrollController,
                                      padding: const EdgeInsets.fromLTRB(
                                        22,
                                        30,
                                        22,
                                        24,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ListenableBuilder(
                                            listenable: widget.viewModel,
                                            builder: (context, _) {
                                              final selectedAvatar =
                                                  SymbolRegistry.byId(
                                                    widget
                                                        .viewModel
                                                        .profileAvatarId,
                                                  ) ??
                                                  SymbolRegistry.byId(
                                                    SymbolRegistry
                                                        .defaultProfileAvatarId,
                                                  )!;
                                              return SystemSettingsProfileEntry(
                                                textColor: _textColor,
                                                avatarAssetPath:
                                                    selectedAvatar.assetPath,
                                                onTap: () {
                                                  UiClickSound.play();
                                                  setState(
                                                    () => _showProfile = true,
                                                  );
                                                },
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 18),
                                          const Divider(
                                            color: Color(0x332C2530),
                                            height: 1,
                                          ),
                                          const SizedBox(height: 18),
                                          SystemSettingsHistoryEntry(
                                            textColor: _textColor,
                                            onTap: () {
                                              UiClickSound.play();
                                              setState(
                                                () => _showGameHistory = true,
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 24),
                                          const Divider(
                                            color: Color(0x332C2530),
                                            height: 1,
                                          ),
                                          const SizedBox(height: 24),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            children: [
                                              Text(
                                                'GENERAL SETTINGS',
                                                style:
                                                    GoogleFonts.barlowCondensed(
                                                      fontSize: 20,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: _textColor,
                                                      letterSpacing: 1.2,
                                                    ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          ListenableBuilder(
                                            listenable: widget.viewModel,
                                            builder: (context, _) {
                                              return Column(
                                                children: [
                                                  SystemSettingsRow(
                                                    title: 'AMBIENT MUSIC',
                                                    description:
                                                        'TURN GAME MUSIC ON OR OFF',
                                                    value: widget
                                                        .viewModel
                                                        .ambientMusic,
                                                    textColor: _textColor,
                                                    onChanged: (v) => widget
                                                        .viewModel
                                                        .setAmbientMusic(v),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  SystemSettingsRow(
                                                    title: 'SOUND EFFECTS',
                                                    description:
                                                        'TURN GAME SOUNDS ON OR OFF',
                                                    value: widget
                                                        .viewModel
                                                        .soundEffects,
                                                    textColor: _textColor,
                                                    onChanged: (v) => widget
                                                        .viewModel
                                                        .setSoundEffects(v),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  SystemSettingsRow(
                                                    title: 'VIBRATION',
                                                    description:
                                                        'TURN IN-GAME VIBRATIONS ON OR OFF',
                                                    value: widget
                                                        .viewModel
                                                        .vibration,
                                                    textColor: _textColor,
                                                    onChanged: (v) => widget
                                                        .viewModel
                                                        .setVibration(v),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 32),
                                          const Divider(
                                            color: Color(0x332C2530),
                                            height: 1,
                                          ),
                                          const SizedBox(height: 24),
                                          SystemSettingsBetSection(
                                            viewModel: widget.viewModel,
                                            onBuyGameMoney: _showDepositMoney,
                                          ),
                                          const SizedBox(height: 36),
                                          const SystemSettingsFooter(),
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
          if (_showGameHistory)
            Positioned.fill(
              child: GameHistoryScreen(
                viewModel: widget.viewModel,
                onClose: () => setState(() => _showGameHistory = false),
              ),
            ),
          if (_showProfile)
            Positioned.fill(
              child: ProfileScreen(
                viewModel: widget.viewModel,
                onClose: () => setState(() => _showProfile = false),
              ),
            ),
        ],
      ),
    );
  }

  void _showDepositMoney() {
    if (widget.viewModel.isInFreeSpins) return;
    UiClickSound.play();
    showGeneralDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: true,
      barrierLabel: 'Deposit Money',
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, _, child) =>
          DepositMoneyScreen(viewModel: widget.viewModel),
      transitionBuilder: (context, anim, _, child) {
        return buildSpringPopupTransition(anim, child);
      },
    );
  }
}
