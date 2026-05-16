import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FreeSpinWinPopup extends StatefulWidget {
  static const assetPath =
      'lib/images/slot_main_screen/WIN_ARTICLES/FreeSpinWin.png';

  final int value;
  final bool isRetrigger;
  final double winAmount;
  final int cacheWidth;
  final VoidCallback onDismiss;

  const FreeSpinWinPopup({
    super.key,
    required this.value,
    required this.isRetrigger,
    required this.winAmount,
    required this.cacheWidth,
    required this.onDismiss,
  });

  @override
  State<FreeSpinWinPopup> createState() => _FreeSpinWinPopupState();
}

class _FreeSpinWinPopupState extends State<FreeSpinWinPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
      reverseDuration: const Duration(milliseconds: 220),
    )..forward();
    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (_isDismissing) return;
    _isDismissing = true;
    await _controller.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.88;
    final valueOffset = Offset(0, width * 0.035);
    final valueFontSize = width * 0.16;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black.withValues(alpha: 0.36),
          alignment: Alignment.center,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.86, end: 1.0).animate(_scale),
            child: SizedBox(
              width: width,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    FreeSpinWinPopup.assetPath,
                    width: width,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: widget.cacheWidth,
                  ),
                  Transform.translate(
                    offset: valueOffset,
                    child: Text(
                      '${widget.value}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                        color: const Color(0xFFFFB72E),
                        shadows: [
                          Shadow(
                            color: const Color(
                              0xFF9C5A00,
                            ).withValues(alpha: 0.95),
                            offset: const Offset(0, 4),
                            blurRadius: 8,
                          ),
                          Shadow(
                            color: const Color(
                              0xFFFFF0A8,
                            ).withValues(alpha: 0.85),
                            offset: const Offset(0, -2),
                            blurRadius: 3,
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
    );
  }
}
