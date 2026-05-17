import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GameHistoryHeader extends StatelessWidget {
  const GameHistoryHeader({
    super.key,
    required this.isSelecting,
    required this.selectedCount,
    required this.textColor,
    required this.panelAccent,
    required this.headerColor,
    required this.onBack,
    required this.onClearSelection,
    required this.onDeleteSelected,
  });

  final bool isSelecting;
  final int selectedCount;
  final Color textColor;
  final Color panelAccent;
  final Color headerColor;
  final VoidCallback onBack;
  final VoidCallback onClearSelection;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            isSelecting ? '$selectedCount SELECTED' : 'GAME HISTORY',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: _HistoryHeaderButton(
              icon: isSelecting ? Icons.close : Icons.arrow_back_ios_new,
              iconSize: 24,
              iconColor: textColor,
              panelAccent: panelAccent,
              onTap: isSelecting ? onClearSelection : onBack,
            ),
          ),
          if (isSelecting)
            Align(
              alignment: Alignment.centerRight,
              child: _HistoryHeaderButton(
                icon: Icons.delete_outline,
                iconSize: 28,
                iconColor: Colors.redAccent.withValues(alpha: 0.95),
                panelAccent: panelAccent,
                onTap: onDeleteSelected,
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryHeaderButton extends StatelessWidget {
  const _HistoryHeaderButton({
    required this.icon,
    required this.iconSize,
    required this.iconColor,
    required this.panelAccent,
    required this.onTap,
  });

  final IconData icon;
  final double iconSize;
  final Color iconColor;
  final Color panelAccent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: panelAccent.withValues(alpha: 0.88),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
  }
}
