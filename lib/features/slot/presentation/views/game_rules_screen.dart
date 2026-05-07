import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../domain/models/symbol_registry.dart';
import '../../domain/models/slot_symbol.dart';
import '../../domain/enums/symbol_tier.dart';

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
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                color: Colors.transparent,
              ),
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
                              thumbColor: Colors.white.withValues(alpha: 0.3),
                              thickness: 4,
                              radius: const Radius.circular(8),
                              child: SingleChildScrollView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 20,
                              ),
                              child: Column(
                                children: [
                                  const SizedBox(height: 8),
                                  _buildSymbolPayoutGrid(),
                                  const SizedBox(height: 20),
                                  _buildRulesDescription(),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'OYUN KURALLARI',
            style: GoogleFonts.barlowCondensed(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 1.2,
            ),
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
    final scatter = SymbolRegistry.all.firstWhere((s) => s.tier == SymbolTier.scatter);

    return Column(
      children: [
        // Row 1: Kalp, Yeşil Ayı
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: _SymbolPayoutCard(symbol: kalp, betAmount: widget.betAmount)),
              Expanded(child: _SymbolPayoutCard(symbol: yesilAyi, betAmount: widget.betAmount)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Row 2: Pembe Ayı, Çilek
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: _SymbolPayoutCard(symbol: pembeAyi, betAmount: widget.betAmount)),
              Expanded(child: _SymbolPayoutCard(symbol: cilek, betAmount: widget.betAmount)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Scatter positioned diagonally between Çilek (Top Right) and Elma (Bottom Left)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: _SymbolPayoutCard(symbol: scatter, betAmount: widget.betAmount),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Row 3: Elma, Şeftali
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: _SymbolPayoutCard(symbol: elma, betAmount: widget.betAmount)),
              Expanded(child: _SymbolPayoutCard(symbol: seftali, betAmount: widget.betAmount)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Row 4: Karpuz, Üzüm, Muz
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: _SymbolPayoutCard(symbol: karpuz, betAmount: widget.betAmount)),
              Expanded(child: _SymbolPayoutCard(symbol: uzum, betAmount: widget.betAmount)),
              Expanded(child: _SymbolPayoutCard(symbol: muz, betAmount: widget.betAmount)),
            ],
          ),
        ),
      ],
    );
  }

  /// Bottom description text explaining the payout mechanics.
  Widget _buildRulesDescription() {
    return Text(
      'Semboller ekrandaki her yere ödeme yapar. Bir spinin sonunda '
      'ekrandaki aynı sembolün toplam sayısı, kazanma değerini belirler.',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(
        fontSize: 15.5,
        fontWeight: FontWeight.w600,
        color: Colors.white,
        height: 1.45,
      ),
    );
  }
}

/// A single symbol card showing the image and its payout tiers.
class _SymbolPayoutCard extends StatelessWidget {
  final SlotSymbol symbol;
  final double betAmount;

  const _SymbolPayoutCard({
    required this.symbol,
    required this.betAmount,
  });

  @override
  Widget build(BuildContext context) {
    final payouts = symbol.isScatter ? symbol.scatterPayouts : symbol.payouts;
    // Sort thresholds descending (12+, 10-11, 8-9) to match reference
    final sortedThresholds = payouts.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          // Symbol image
          SizedBox(
            height: 96,
            width: 96,
            child: Image.asset(
              symbol.assetPath,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          const SizedBox(height: 6),
          // Payout rows
          ...sortedThresholds.map((threshold) {
            final multiplier = payouts[threshold]!;
            final payout = multiplier * betAmount;
            final rangeText = _getRangeText(threshold, sortedThresholds);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: _PayoutRow(
                range: rangeText,
                value: _formatPayout(payout),
              ),
            );
          }),
        ],
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

/// A single payout row: "12+  100,00 ₺"
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
            fontSize: 17.0,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.3,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.barlowCondensed(
            fontSize: 17.0,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
