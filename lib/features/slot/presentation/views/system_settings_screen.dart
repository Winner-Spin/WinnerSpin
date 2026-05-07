import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/custom_switch.dart';

class SystemSettingsScreen extends StatefulWidget {
  final GameViewModel viewModel;

  const SystemSettingsScreen({super.key, required this.viewModel});

  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  // Using GameViewModel for states

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
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
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
                                  thumbColor: Colors.white.withValues(alpha: 0.5),
                                  thickness: 6,
                                  radius: const Radius.circular(8),
                                  padding: const EdgeInsets.only(right: 4, top: 4, bottom: 4),
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Top Section (formerly Left Column)
                              _buildGameHistory(),
                              const SizedBox(height: 16),
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 16),
                              _buildTotalBet(),
                              
                              const SizedBox(height: 24),
                              // Horizontal Divider
                              const Divider(color: Colors.white24, height: 1),
                              const SizedBox(height: 24),
                              
                              // Bottom Section (formerly Right Column)
                              ListenableBuilder(
                                listenable: widget.viewModel,
                                builder: (context, _) {
                                  return Column(
                                    children: [
                                      _buildSettingRow(
                                        title: 'PİL TASARRUFU',
                                        description: 'ANİMASYON HIZINI DÜŞÜREREK PİL ÖMRÜNÜ UZATIN',
                                        value: widget.viewModel.batterySaver,
                                        onChanged: (v) => widget.viewModel.setBatterySaver(v),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildSettingRow(
                                        title: 'ORTAM MÜZİĞİ',
                                        description: 'OYUN MÜZİĞİNİ AÇIN VEYA KAPATIN',
                                        value: widget.viewModel.ambientMusic,
                                        onChanged: (v) => widget.viewModel.setAmbientMusic(v),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildSettingRow(
                                        title: 'SES EFEKTLERİ',
                                        description: 'OYUN SESLERİNİ AÇIN VEYA KAPATIN',
                                        value: widget.viewModel.soundEffects,
                                        onChanged: (v) => widget.viewModel.setSoundEffects(v),
                                      ),
                                      const SizedBox(height: 24),
                                      _buildSettingRow(
                                        title: 'GİRİŞ EKRANI',
                                        description: 'OYUNA BAŞLAMADAN ÖNCE TANITIM EKRANINI GÖSTERİN',
                                        value: widget.viewModel.introScreen,
                                        onChanged: (v) => widget.viewModel.setIntroScreen(v),
                                      ),
                                    ],
                                  );
                                }
                              ),
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

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'SİSTEM AYARLARI',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE5A800), // Darker yellow/gold color
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 36,
                  color: Colors.white.withValues(alpha: 0.75), // More whitish color
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameHistory() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Henüz oyun geçmişiniz bulunmuyor.',
              style: GoogleFonts.barlowCondensed(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            backgroundColor: Colors.black.withValues(alpha: 0.8),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'OYUN GEÇMİŞİ',
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          Icon(
            Icons.open_in_new,
            color: Colors.white.withValues(alpha: 0.6),
            size: 28,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalBet() {
    return Column(
      children: [
        Text(
          'TOPLAM BAHİS',
          style: GoogleFonts.barlowCondensed(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ListenableBuilder(
          listenable: widget.viewModel.balanceCtrl,
          builder: (context, _) {
            final bet = widget.viewModel.betAmount;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBetButton(
                  icon: Icons.remove,
                  color: Colors.white,
                  iconColor: Colors.black,
                  onTap: widget.viewModel.decreaseBet,
                ),
                const SizedBox(width: 16),
                Container(
                  width: 120,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Text(
                    '${formatMoney(bet)} \$', // Using $ to match the screenshot
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildBetButton(
                  icon: Icons.add,
                  color: const Color(0xFF00C853), // Green plus button
                  iconColor: Colors.white,
                  onTap: widget.viewModel.increaseBet,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildBetButton({
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: 32),
      ),
    );
  }

  Widget _buildSettingRow({
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: GoogleFonts.barlowCondensed(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        CustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
