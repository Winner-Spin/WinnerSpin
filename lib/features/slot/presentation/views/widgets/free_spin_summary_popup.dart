import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';
import '../../../../../core/widgets/money_text.dart';
import '../../models/game_presentation_timings.dart';

class FreeSpinSummaryPopup extends StatefulWidget {
  static const assetPath =
      'lib/images/slot_main_screen/WIN_ARTICLES/xFreeSpinWin.png';

  final double totalWin;
  final int totalFreeSpins;
  final int cacheWidth;
  final VoidCallback onDismiss;

  const FreeSpinSummaryPopup({
    super.key,
    required this.totalWin,
    required this.totalFreeSpins,
    required this.cacheWidth,
    required this.onDismiss,
  });

  @override
  State<FreeSpinSummaryPopup> createState() => _FreeSpinSummaryPopupState();
}

class _FreeSpinSummaryPopupState extends State<FreeSpinSummaryPopup>
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
      duration: GamePresentationTimings.freeSpinPopupShowDuration,
      reverseDuration: GamePresentationTimings.freeSpinPopupDismissDuration,
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
    final amountFontSize = width * 0.115;
    final spinFontSize = width * 0.060;

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
                    FreeSpinSummaryPopup.assetPath,
                    width: width,
                    filterQuality: FilterQuality.medium,
                    cacheWidth: widget.cacheWidth,
                  ),
                  Transform.translate(
                    offset: Offset(0, width * 0.025),
                    child: SizedBox(
                      width: width * 0.46,
                      height: width * 0.12,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: MoneyText(
                          text: formatMoney(widget.totalWin),
                          spacing: width * 0.007,
                          symbolOffset: Offset(0, width * 0.005),
                          lineYOffset: width * 0.009,
                          lineLengthScale: 0.96,
                          lineTopExtend: width * 0.004,
                          symbolTextYOffset: width * 0.006,
                          style: GoogleFonts.outfit(
                            fontSize: amountFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: const Color(0xFFFFD13B),
                            shadows: [
                              Shadow(
                                color: const Color(
                                  0xFF9C5A00,
                                ).withValues(alpha: 0.95),
                                offset: const Offset(0, 4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(width * -0.14, width * 0.17),
                    child: SizedBox(
                      width: width * 0.11,
                      height: width * 0.07,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${widget.totalFreeSpins}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: spinFontSize,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: const Color(0xFFFFD13B),
                            letterSpacing: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.85),
                                offset: const Offset(0, 3),
                                blurRadius: 5,
                              ),
                            ],
                          ),
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
    );
  }
}
