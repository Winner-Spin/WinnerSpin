import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/format/money_format.dart';

/// Glossy candy-style "DOUBLE CHANCE" button. Same multi-layer construction
/// as [BuyFeatureButton] but in a green-and-gold palette and with an
/// ON/OFF capsule replacing the price line.
class DoubleChanceButton extends StatefulWidget {
  final double betAmount;
  final bool isOn;
  final bool disabled;
  final VoidCallback onTap;
  final double width;
  final double height;

  const DoubleChanceButton({
    super.key,
    required this.betAmount,
    required this.isOn,
    required this.disabled,
    required this.onTap,
    this.width = 235,
    this.height = 112,
  });

  @override
  State<DoubleChanceButton> createState() => _DoubleChanceButtonState();
}

class _DoubleChanceButtonState extends State<DoubleChanceButton>
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
    final disabled = widget.disabled;
    final radius = widget.height * 0.32;
    final w = widget.width;
    final h = widget.height;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: disabled ? null : (_) => _pressCtrl.forward(),
      onTapUp: disabled
          ? null
          : (_) {
              _pressCtrl.reverse();
              widget.onTap();
            },
      onTapCancel: disabled ? null : () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF7BCC55),
                  Color(0xFF3DA838),
                  Color(0xFF156A24),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: const Color(0xFF0E5320), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF052D11).withValues(alpha: 0.55),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: const Color(0xFFC8FFB8).withValues(alpha: 0.40),
                  blurRadius: 20,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius - 2),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0.0, -0.35),
                          radius: 0.95,
                          colors: [
                            const Color(0xFFE8FFE0).withValues(alpha: 0.42),
                            const Color(0xFFE8FFE0).withValues(alpha: 0.16),
                            const Color(0xFFE8FFE0).withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: h * 0.10,
                    left: w * 0.09,
                    child: Container(
                      width: w * 0.20,
                      height: h * 0.18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.85),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.85],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: h * 0.04,
                    left: w * 0.36,
                    child: Container(
                      width: w * 0.28,
                      height: h * 0.20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h),
                        gradient: RadialGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.40),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.95],
                        ),
                      ),
                    ),
                  ),

                  Positioned(
                    top: h * 0.04,
                    right: w * 0.06,
                    child: Container(
                      width: w * 0.40,
                      height: h * 0.42,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(h),
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFFC8FFB8).withValues(alpha: 0.78),
                            const Color(0xFFA5FF80).withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.95],
                        ),
                      ),
                    ),
                  ),

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
                            const Color(0xFF052D11).withValues(alpha: 0.45),
                            const Color(0xFF052D11).withValues(alpha: 0.18),
                            const Color(0xFF052D11).withValues(alpha: 0.0),
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
                            color: const Color(
                              0xFFD8FFC0,
                            ).withValues(alpha: 0.85),
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
                            color: const Color(
                              0xFFA5E590,
                            ).withValues(alpha: 0.8),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.06,
                      vertical: h * 0.04,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: h * 0.04),
                          child: SizedBox(
                            width: w * 0.85,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: h * 0.03),
                                    child: _EmbossedText(
                                      text: 'BET',
                                      fontSize: h * 0.16,
                                      strokeWidth: 2.6,
                                      letterSpacing: 0.5,
                                      fillColor: Colors.white,
                                    ),
                                  ),
                                SizedBox(width: h * 0.04),
                                _EmbossedText(
                                  text: '₺${formatMoney(widget.betAmount)}',
                                  fontSize: h * 0.20,
                                  strokeWidth: 2.6,
                                  letterSpacing: 0.5,
                                  fillColor: const Color(0xFFFFC93C),
                                ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _EmbossedText(
                              text: 'DOUBLE CHANCE',
                              fontSize: h * 0.13,
                              strokeWidth: 2.3,
                              letterSpacing: 0.6,
                              fillColor: Colors.white,
                            ),
                            _EmbossedText(
                              text: 'TO WIN FEATURE',
                              fontSize: h * 0.13,
                              strokeWidth: 2.3,
                              letterSpacing: 0.6,
                              fillColor: Colors.white,
                            ),
                            SizedBox(height: h * 0.04),
                            _OnOffCapsule(
                              isOn: widget.isOn,
                              height: h * 0.31,
                            ),
                          ],
                        ),
                      ],
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

/// Frosted-glass capsule with a slightly pill-shaped green knob that
/// slides between left (OFF) and right (ON), with the label sitting on
/// the opposite side. Knob sits flush against the capsule edge.
class _OnOffCapsule extends StatelessWidget {
  final bool isOn;
  final double height;

  const _OnOffCapsule({required this.isOn, required this.height});

  @override
  Widget build(BuildContext context) {
    final w = height * 2.7;
    final knobH = height * 0.92;
    final knobW = height * 1.05;
    final pad = height * 0.02;
    const animDuration = Duration(milliseconds: 220);
    const animCurve = Curves.easeInOut;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: w,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: Colors.black.withValues(alpha: 0.18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: animDuration,
                curve: animCurve,
                left: isOn ? 0 : knobW,
                right: isOn ? knobW : 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: animDuration,
                    child: Text(
                      isOn ? 'ON' : 'OFF',
                      key: ValueKey<bool>(isOn),
                      style: GoogleFonts.outfit(
                        fontSize: height * 0.50,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        color: isOn
                            ? const Color(0xFFE8FFD7)
                            : const Color(0xFFFFF8E6),
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.55),
                            offset: const Offset(0, 1),
                            blurRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: animDuration,
                curve: animCurve,
                alignment: isOn
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: pad),
                  child: Container(
                    width: knobW,
                    height: knobH,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(knobH / 2),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF89E875),
                          Color(0xFF3DB836),
                          Color(0xFF166D24),
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                      border: Border.all(
                        color: const Color(0xFF0E5320),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: knobH * 0.55,
                        height: knobH * 0.55,
                        child: CustomPaint(
                          painter: _SolidArrowPainter(
                            color: Colors.white,
                            reversed: isOn,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-layer text: dark-green stroke layer behind a cream/white fill so
/// the lettering reads as embossed against the glossy green panel.
class _EmbossedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final double strokeWidth;
  final double letterSpacing;
  final Color fillColor;

  const _EmbossedText({
    required this.text,
    required this.fontSize,
    required this.strokeWidth,
    required this.letterSpacing,
    required this.fillColor,
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
              ..color = const Color(0xFF053C14),
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
            color: fillColor,
            shadows: const [
              Shadow(
                color: Color(0xFF053C14),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
              Shadow(
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

/// Chunky filled right-pointing arrow — shaft (rectangle body) plus a
/// triangular arrowhead, drawn as a single closed path. Set [reversed]
/// to flip horizontally for a left-pointing arrow.
class _SolidArrowPainter extends CustomPainter {
  final Color color;
  final bool reversed;

  const _SolidArrowPainter({
    required this.color,
    this.reversed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cy = h / 2;

    final shaftEnd = w * 0.55;
    final shaftHalf = h * 0.18;
    final headHalf = h * 0.45;

    final path = Path()
      ..moveTo(0, cy - shaftHalf)
      ..lineTo(shaftEnd, cy - shaftHalf)
      ..lineTo(shaftEnd, cy - headHalf)
      ..lineTo(w, cy)
      ..lineTo(shaftEnd, cy + headHalf)
      ..lineTo(shaftEnd, cy + shaftHalf)
      ..lineTo(0, cy + shaftHalf)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    if (reversed) {
      canvas.save();
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
      canvas.drawPath(path, paint);
      canvas.restore();
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SolidArrowPainter old) =>
      old.color != color || old.reversed != reversed;
}
