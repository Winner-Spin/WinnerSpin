import 'package:flutter/material.dart';

class CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const CustomSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 32,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: value ? const Color(0xFF00B050) : const Color(0xFF424242),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: value ? const Color(0xFF13DF70) : const Color(0xFFF0F0F0),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLine(value),
                _buildLine(value),
                _buildLine(value),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(bool isActive) {
    return Container(
      width: 2,
      height: 10,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFF008A3D) : const Color(0xFFBDBDBD),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
