import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Glossy candy-style "BUY FEATURE" button. Tapping toggles between an
/// opaque candy face and a translucent glass face — both states share
/// the same shape, gradient family, and embossed lettering.
class BuyFeatureButton extends StatefulWidget {
  final String title;
  final double price;
  final double width;
  final double height;
  final bool disabled;
  final VoidCallback? onTap;

  const BuyFeatureButton({
    super.key,
    this.title = 'BUY FEATURE',
    required this.price,
    this.width = 235,
    this.height = 112,
    this.disabled = false,
    this.onTap,
  });

  String get _formattedPrice => '₺${price.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'),
        (m) => '${m[1]},',
      )}';

  @override
  State<BuyFeatureButton> createState() => _BuyFeatureButtonState();
}

class _BuyFeatureButtonState extends State<BuyFeatureButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  /// Drives the candy ↔ glass transition. 0 = opaque candy, 1 = glass.
  late final AnimationController _glassCtrl;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 130),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
    _glassCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    _glassCtrl.dispose();
    super.dispose();
  }

  void _toggleGlass() {
    if (_glassCtrl.status == AnimationStatus.completed ||
        _glassCtrl.status == AnimationStatus.forward) {
      _glassCtrl.reverse();
    } else {
      _glassCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.height * 0.32;
    final w = widget.width;
    final h = widget.height;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        _toggleGlass();
        widget.onTap?.call();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedBuilder(
          animation: _glassCtrl,
          builder: (context, _) {
            final g = Curves.easeInOut.transform(_glassCtrl.value);
            // Lerp helper: opaque value at g=0, glass value at g=1.
            double mix(double opaque, double glass) =>
                opaque + (glass - opaque) * g;

            return Container(
              width: w,
              height: h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFF7BC4)
                        .withValues(alpha: mix(0.94, 0.32)),
                    const Color(0xFFE93491)
                        .withValues(alpha: mix(0.96, 0.40)),
                    const Color(0xFFB91E6E)
                        .withValues(alpha: mix(0.97, 0.52)),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: const Color(0xFF8F1555)
                      .withValues(alpha: mix(0.92, 0.85)),
                  width: 2.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4A0A2C)
                        .withValues(alpha: mix(0.50, 0.40)),
                    blurRadius: 24,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: const Color(0xFFFF7BC4)
                        .withValues(alpha: mix(0.50, 0.30)),
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
                          borderRadius: BorderRadius.circular(radius),
                          gradient: RadialGradient(
                            center: const Alignment(0.0, -0.35),
                            radius: 0.95,
                            colors: [
                              const Color(0xFFFFE3F1)
                                  .withValues(alpha: mix(0.40, 0.0)),
                              const Color(0xFFFFE3F1)
                                  .withValues(alpha: mix(0.14, 0.0)),
                              const Color(0xFFFFE3F1).withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Top-left specular point.
                    Positioned(
                      top: h * 0.10,
                      left: w * 0.09,
                      child: Container(
                        width: w * 0.20,
                        height: h * 0.22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(h),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white
                                  .withValues(alpha: mix(0.92, 0.20)),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.85],
                          ),
                        ),
                      ),
                    ),

                    // Mid-top organic blob — opaque mode only.
                    Positioned(
                      top: h * 0.04,
                      left: w * 0.36,
                      child: Container(
                        width: w * 0.28,
                        height: h * 0.24,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(h),
                          gradient: RadialGradient(
                            colors: [
                              Colors.white
                                  .withValues(alpha: mix(0.42, 0.0)),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.95],
                          ),
                        ),
                      ),
                    ),

                    // Top-right ambient glow.
                    Positioned(
                      top: h * 0.04,
                      right: w * 0.06,
                      child: Container(
                        width: w * 0.40,
                        height: h * 0.46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(h),
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFFFFD8EC)
                                  .withValues(alpha: mix(0.85, 0.10)),
                              const Color(0xFFFF9CCF).withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.95],
                          ),
                        ),
                      ),
                    ),

                    // Bottom inner shadow — opaque mode only (fades out so
                    // glass mode can stay see-through).
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: h * 0.55,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF4D0830)
                                  .withValues(alpha: mix(0.45, 0.0)),
                              const Color(0xFF4D0830)
                                  .withValues(alpha: mix(0.18, 0.0)),
                              const Color(0xFF4D0830).withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.45, 1.0],
                          ),
                        ),
                      ),
                    ),

                    // Inner edge glow ring — opaque mode bright, glass mode
                    // softens to keep the contour readable but not bright.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius - 2),
                            border: Border.all(
                              color: const Color(0xFFFFD9EC)
                                  .withValues(alpha: mix(0.85, 0.30)),
                              width: 1.8,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Inner pink highlight stroke.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(radius - 4),
                            border: Border.all(
                              color: const Color(0xFFFF9CCF)
                                  .withValues(alpha: mix(0.85, 0.85)),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Title + price — fades to ~0.55 in glass mode so the
                    // label reads as part of the see-through surface.
                    Center(
                      child: Opacity(
                        opacity: mix(1.0, 0.55),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: w * 0.06),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _EmbossedText(
                                  text: widget.title,
                                  fontSize: h * 0.20,
                                  strokeWidth: 2.8,
                                  letterSpacing: 0.8,
                                  fillColor: Colors.white,
                                ),
                              ),
                              SizedBox(height: h * 0.03),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _EmbossedText(
                                  text: widget._formattedPrice,
                                  fontSize: h * 0.30,
                                  strokeWidth: 4.2,
                                  letterSpacing: 0.8,
                                  fillColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Two-layer text: a soft pink-mauve stroke layer behind a cream fill
/// layer creates the embossed casino-game look that a single shadow
/// can't reproduce.
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
              ..color = const Color(0xFF8B2258),
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
                color: Color(0xFF6E1A4B),
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
