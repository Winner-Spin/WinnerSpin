import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SystemSettingsHeader extends StatelessWidget {
  const SystemSettingsHeader({
    super.key,
    required this.title,
    required this.textColor,
    required this.panelAccent,
    required this.isExiting,
    required this.onExit,
    required this.onClose,
  });

  final String title;
  final Color textColor;
  final Color panelAccent;
  final bool isExiting;
  final VoidCallback onExit;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(color: textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _HeaderIconButton(
              icon: Icons.logout_rounded,
              textColor: textColor,
              panelAccent: panelAccent,
              isEnabled: !isExiting,
              opacity: isExiting ? 0.55 : 1,
              onTap: onExit,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: _HeaderIconButton(
              icon: Icons.close,
              textColor: textColor,
              panelAccent: panelAccent,
              onTap: onClose,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.textColor,
    required this.panelAccent,
    required this.onTap,
    this.isEnabled = true,
    this.opacity = 1,
  });

  final IconData icon;
  final Color textColor;
  final Color panelAccent;
  final VoidCallback onTap;
  final bool isEnabled;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: panelAccent.withValues(alpha: 0.88),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: textColor),
        ),
      ),
    );
  }
}
