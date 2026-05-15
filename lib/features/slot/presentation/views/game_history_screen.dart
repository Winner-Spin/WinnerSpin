import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/format/money_format.dart';
import '../../../../core/widgets/money_text.dart';
import '../../domain/models/game_history_entry.dart';
import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';

class GameHistoryScreen extends StatefulWidget {
  const GameHistoryScreen({
    super.key,
    required this.viewModel,
    required this.onClose,
  });

  final GameViewModel viewModel;
  final VoidCallback onClose;

  @override
  State<GameHistoryScreen> createState() => _GameHistoryScreenState();
}

class _GameHistoryScreenState extends State<GameHistoryScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _headerColor = Color(0xFFF6D7EB);
  static const Color _textColor = Color(0xFF2C2530);
  static const Color _goldColor = Color(0xFFE5A800);

  final Set<String> _selectedHistoryIds = {};

  bool get _isSelecting => _selectedHistoryIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
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
                            child: ListenableBuilder(
                              listenable: widget.viewModel,
                              builder: (context, _) {
                                final history = widget.viewModel.gameHistory;

                                if (history.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      32,
                                      20,
                                      24,
                                    ),
                                    child: _buildHistoryEmptyState(),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    28,
                                  ),
                                  itemBuilder: (context, index) =>
                                      _buildHistoryEntry(history[index]),
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemCount: history.length,
                                );
                              },
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: _headerColor,
        border: Border(
          bottom: BorderSide(color: _textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            _isSelecting
                ? '${_selectedHistoryIds.length} SELECTED'
                : 'GAME HISTORY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _isSelecting
                  ? () {
                      UiClickSound.play();
                      setState(_selectedHistoryIds.clear);
                    }
                  : () {
                      UiClickSound.play();
                      widget.onClose();
                    },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isSelecting ? Icons.close : Icons.arrow_back_ios_new,
                  size: 24,
                  color: _textColor,
                ),
              ),
            ),
          ),
          if (_isSelecting)
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  UiClickSound.play();
                  _deleteSelectedEntries();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _panelAccent.withValues(alpha: 0.88),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    size: 28,
                    color: Colors.redAccent.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _headerColor.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _textColor.withValues(alpha: 0.10)),
      ),
      child: Text(
        'NO GAME HISTORY YET',
        textAlign: TextAlign.center,
        style: GoogleFonts.barlowCondensed(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: _textColor.withValues(alpha: 0.55),
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHistoryEntry(GameHistoryEntry entry) {
    final selected = _selectedHistoryIds.contains(entry.id);
    final winColor = entry.winAmount > 0
        ? const Color(0xFF00C853)
        : _textColor.withValues(alpha: 0.55);

    return GestureDetector(
      onTap: _isSelecting
          ? () {
              UiClickSound.play();
              _toggleEntrySelection(entry.id);
            }
          : null,
      onLongPress: () {
        UiClickSound.play();
        _toggleEntrySelection(entry.id);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? _goldColor.withValues(alpha: 0.18)
              : _headerColor.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _goldColor : _textColor.withValues(alpha: 0.10),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatHistoryDate(entry.playedAt),
                    style: GoogleFonts.barlowCondensed(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _textColor.withValues(alpha: 0.82),
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (_isSelecting)
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    size: 22,
                    color: selected
                        ? _goldColor
                        : _textColor.withValues(alpha: 0.45),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'NEW BALANCE',
                    valueWidget: MoneyText(
                      text: formatMoney(entry.newBalance),
                      symbolOffset: const Offset(0, 1.0),
                      lineYOffset: 1.25,
                      symbolTextYOffset: 0.45,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'BET',
                    valueWidget: MoneyText(
                      text: formatMoney(entry.bet),
                      symbolOffset: const Offset(0, 1.0),
                      lineYOffset: 1.25,
                      symbolTextYOffset: 0.45,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHistoryMetric(
                    label: 'WIN',
                    valueWidget: MoneyText(
                      text: formatMoney(entry.winAmount),
                      symbolOffset: const Offset(0, 1.0),
                      lineYOffset: 1.25,
                      symbolTextYOffset: 0.45,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: winColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryMetric({
    required String label,
    String? value,
    Widget? valueWidget,
    Color? valueColor,
  }) {
    assert(value != null || valueWidget != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.barlowCondensed(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _textColor.withValues(alpha: 0.48),
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: double.infinity,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child:
                valueWidget ??
                Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? _textColor,
                  ),
                ),
          ),
        ),
      ],
    );
  }

  void _toggleEntrySelection(String id) {
    setState(() {
      if (!_selectedHistoryIds.add(id)) {
        _selectedHistoryIds.remove(id);
      }
    });
  }

  void _deleteSelectedEntries() {
    widget.viewModel.deleteGameHistoryEntries(Set.of(_selectedHistoryIds));
    setState(_selectedHistoryIds.clear);
  }

  String _formatHistoryDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day.$month.$year  $hour:$minute';
  }
}
