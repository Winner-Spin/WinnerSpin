import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../audio/ui_click_sound.dart';
import 'embossed_button_text.dart';

final RegExp _priceSeparatorPattern = RegExp(r'(\d)(?=(\d{3})+$)');

class BuyFeatureButton extends StatefulWidget {
  final String title;
  final double price;
  final double width;
  final double height;
  final bool disabled;
  final bool vibrationEnabled;
  final VoidCallback? onTap;

  const BuyFeatureButton({
    super.key,
    this.title = 'BUY FEATURE',
    required this.price,
    this.width = 235,
    this.height = 112,
    this.disabled = false,
    this.vibrationEnabled = true,
    this.onTap,
  });

  String get _formattedPrice => price
      .toStringAsFixed(0)
      .replaceAllMapped(_priceSeparatorPattern, (m) => '${m[1]},');

  @override
  State<BuyFeatureButton> createState() => _BuyFeatureButtonState();
}

class _BuyFeatureButtonState extends State<BuyFeatureButton>
    with TickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scale;

  late final AnimationController _glassCtrl;

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

  @override
  void didUpdateWidget(covariant BuyFeatureButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.disabled && _glassCtrl.value != 0) {
      _glassCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.height * 0.32;
    final w = widget.width;
    final h = widget.height;
    final isDisabled = widget.disabled;
    const g = 0.0;

    double mix(double opaque, double glass) => opaque + (glass - opaque) * g;

    return IgnorePointer(
      ignoring: isDisabled,
      child: Opacity(
        opacity: isDisabled ? 0.55 : 1.0,
        child: RepaintBoundary(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _pressCtrl.forward(),
            onTapUp: (_) {
              _pressCtrl.reverse();
            },
            onTapCancel: () => _pressCtrl.reverse(),
            onTap: () {
              _glassCtrl.reverse();
              UiClickSound.play();
              if (widget.vibrationEnabled) HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            child: ScaleTransition(
              scale: _scale,
              child: AnimatedBuilder(
                animation: _glassCtrl,
                builder: (context, _) {
                  return Container(
                    width: w,
                    height: h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(
                            0xFFFF7BC4,
                          ).withValues(alpha: mix(0.94, 0.32)),
                          const Color(
                            0xFFE93491,
                          ).withValues(alpha: mix(0.96, 0.40)),
                          const Color(
                            0xFFB91E6E,
                          ).withValues(alpha: mix(0.97, 0.52)),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                      border: Border.all(
                        color: const Color(
                          0xFF8F1555,
                        ).withValues(alpha: mix(0.92, 0.85)),
                        width: 2.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF4A0A2C,
                          ).withValues(alpha: mix(0.50, 0.40)),
                          blurRadius: 24,
                          offset: const Offset(0, 14),
                        ),
                        BoxShadow(
                          color: const Color(
                            0xFFFF7BC4,
                          ).withValues(alpha: mix(0.50, 0.30)),
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
                                    const Color(
                                      0xFFFFE3F1,
                                    ).withValues(alpha: mix(0.40, 0.0)),
                                    const Color(
                                      0xFFFFE3F1,
                                    ).withValues(alpha: mix(0.14, 0.0)),
                                    const Color(
                                      0xFFFFE3F1,
                                    ).withValues(alpha: 0.0),
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
                              height: h * 0.22,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(h),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: mix(0.92, 0.20),
                                    ),
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
                              height: h * 0.24,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(h),
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.white.withValues(
                                      alpha: mix(0.42, 0.0),
                                    ),
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
                              height: h * 0.46,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(h),
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(
                                      0xFFFFD8EC,
                                    ).withValues(alpha: mix(0.85, 0.10)),
                                    const Color(
                                      0xFFFF9CCF,
                                    ).withValues(alpha: 0.0),
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
                              height: h * 0.55,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    const Color(
                                      0xFF4D0830,
                                    ).withValues(alpha: mix(0.45, 0.0)),
                                    const Color(
                                      0xFF4D0830,
                                    ).withValues(alpha: mix(0.18, 0.0)),
                                    const Color(
                                      0xFF4D0830,
                                    ).withValues(alpha: 0.0),
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
                                  borderRadius: BorderRadius.circular(
                                    radius - 2,
                                  ),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFFD9EC,
                                    ).withValues(alpha: mix(0.85, 0.30)),
                                    width: 1.8,
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
                                  borderRadius: BorderRadius.circular(
                                    radius - 4,
                                  ),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFFF9CCF,
                                    ).withValues(alpha: mix(0.85, 0.85)),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Center(
                            child: Opacity(
                              opacity: mix(1.0, 0.55),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: w * 0.06,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: EmbossedButtonText(
                                        text: widget.title,
                                        fontSize: h * 0.20,
                                        strokeWidth: 2.8,
                                        letterSpacing: 0.8,
                                        fillColor: Colors.white,
                                        strokeColor: const Color(0xFF8B2258),
                                        shadowColor: const Color(0xFF6E1A4B),
                                      ),
                                    ),
                                    SizedBox(height: h * 0.03),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: EmbossedButtonMoneyText(
                                        text: widget._formattedPrice,
                                        fontSize: h * 0.30,
                                        strokeWidth: 4.2,
                                        letterSpacing: 0.8,
                                        fillColor: Colors.white,
                                        strokeColor: const Color(0xFF8B2258),
                                        shadowColor: const Color(0xFF6E1A4B),
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
          ),
        ),
      ),
    );
  }
}
