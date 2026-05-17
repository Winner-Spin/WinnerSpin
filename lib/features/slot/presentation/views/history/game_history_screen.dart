import 'package:flutter/material.dart';

import '../../audio/ui_click_sound.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'widgets/game_history_empty_state.dart';
import 'widgets/game_history_entry_card.dart';
import 'widgets/game_history_header.dart';

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
                          GameHistoryHeader(
                            isSelecting: _isSelecting,
                            selectedCount: _selectedHistoryIds.length,
                            textColor: _textColor,
                            panelAccent: _panelAccent,
                            headerColor: _headerColor,
                            onBack: _close,
                            onClearSelection: _clearSelection,
                            onDeleteSelected: _deleteSelectedEntries,
                          ),
                          Expanded(
                            child: ListenableBuilder(
                              listenable: widget.viewModel,
                              builder: (context, _) {
                                final history = widget.viewModel.gameHistory;

                                if (history.isEmpty) {
                                  return const Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      20,
                                      32,
                                      20,
                                      24,
                                    ),
                                    child: GameHistoryEmptyState(
                                      textColor: _textColor,
                                      headerColor: _headerColor,
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    24,
                                    20,
                                    28,
                                  ),
                                  itemBuilder: (context, index) {
                                    final entry = history[index];
                                    return GameHistoryEntryCard(
                                      entry: entry,
                                      selected: _selectedHistoryIds.contains(
                                        entry.id,
                                      ),
                                      isSelecting: _isSelecting,
                                      formattedDate: _formatHistoryDate(
                                        entry.playedAt,
                                      ),
                                      textColor: _textColor,
                                      headerColor: _headerColor,
                                      goldColor: _goldColor,
                                      onTap: () {
                                        UiClickSound.play();
                                        _toggleEntrySelection(entry.id);
                                      },
                                      onLongPress: () {
                                        UiClickSound.play();
                                        _toggleEntrySelection(entry.id);
                                      },
                                    );
                                  },
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

  void _close() {
    UiClickSound.play();
    widget.onClose();
  }

  void _clearSelection() {
    UiClickSound.play();
    setState(_selectedHistoryIds.clear);
  }

  void _toggleEntrySelection(String id) {
    setState(() {
      if (!_selectedHistoryIds.add(id)) {
        _selectedHistoryIds.remove(id);
      }
    });
  }

  void _deleteSelectedEntries() {
    UiClickSound.play();
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
