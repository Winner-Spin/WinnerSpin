import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum ConfirmButtonVariant { yes, no }

class ConfirmButton extends StatefulWidget {
  final String label;
  final ConfirmButtonVariant variant;
  final VoidCallback onTap;
  final double width;
  final double height;

  const ConfirmButton({
    super.key,
    required this.label,
    required this.variant,
    required this.onTap,
    this.width = 160,
    this.height = 80,
  });

  @override
  State<ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends State<ConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.variant == ConfirmButtonVariant.yes
        ? const _Palette.green()
        : const _Palette.red();
    final radius = widget.height * 0.32;
    final w = widget.width;
    final h = widget.height;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: RepaintBoundary(
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [p.bodyTop, p.bodyMid, p.bodyBottom],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: p.border, width: 3),
              boxShadow: [
                BoxShadow(
                  color: p.shadowDeep.withValues(alpha: 0.55),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: p.haloOuter.withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 2),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: h * 0.50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            p.shadowDeep.withValues(alpha: 0.45),
                            p.shadowDeep.withValues(alpha: 0.18),
                            p.shadowDeep.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius - 2),
                          border: Border.all(
                            color: p.innerHi.withValues(alpha: 0.85),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(radius - 4),
                          border: Border.all(
                            color: p.innerMid.withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: _EmbossedText(
                      text: widget.label,
                      fontSize: h * 0.42,
                      strokeWidth: 3.0,
                      strokeColor: p.textStroke,
                      letterSpacing: 1.0,
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

class _Palette {
  final Color bodyTop;
  final Color bodyMid;
  final Color bodyBottom;
  final Color border;
  final Color shadowDeep;
  final Color haloOuter;
  final Color haloInner;
  final Color haloBright;
  final Color innerHi;
  final Color innerMid;
  final Color textStroke;

  const _Palette.green()
    : bodyTop = const Color(0xFF7BCC55),
      bodyMid = const Color(0xFF3DA838),
      bodyBottom = const Color(0xFF156A24),
      border = const Color(0xFF0E5320),
      shadowDeep = const Color(0xFF052D11),
      haloOuter = const Color(0xFFC8FFB8),
      haloInner = const Color(0xFFE8FFE0),
      haloBright = const Color(0xFFA5FF80),
      innerHi = const Color(0xFFD8FFC0),
      innerMid = const Color(0xFFA5E590),
      textStroke = const Color(0xFF053C14);

  const _Palette.red()
    : bodyTop = const Color(0xFFE85555),
      bodyMid = const Color(0xFFB23030),
      bodyBottom = const Color(0xFF6A1015),
      border = const Color(0xFF530E0E),
      shadowDeep = const Color(0xFF2D0505),
      haloOuter = const Color(0xFFFFB8B8),
      haloInner = const Color(0xFFFFE0E0),
      haloBright = const Color(0xFFFF8080),
      innerHi = const Color(0xFFFFC0C0),
      innerMid = const Color(0xFFE59090),
      textStroke = const Color(0xFF3C0505);
}

/// Stroke + fill text for an embossed label effect.
class _EmbossedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;
  final double letterSpacing;
  final Color strokeColor;

  const _EmbossedText({
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
    required this.letterSpacing,
    required this.strokeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
            height: 1.0,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
            height: 1.0,
            color: Colors.white,
            shadows: [
              Shadow(
                color: strokeColor,
                offset: const Offset(0, 2),
                blurRadius: 2,
              ),
              const Shadow(
                color: Color(0x55FFC089),
                offset: Offset(0, -1),
                blurRadius: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
