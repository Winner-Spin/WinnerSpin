import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/format/money_format.dart';
import '../../audio/ui_click_sound.dart';
import 'embossed_button_text.dart';
import 'on_off_capsule.dart';

class DoubleChanceButton extends StatefulWidget {
  final double betAmount;
  final bool isOn;
  final bool disabled;
  final bool vibrationEnabled;
  final VoidCallback onTap;
  final double width;
  final double height;

  const DoubleChanceButton({
    super.key,
    required this.betAmount,
    required this.isOn,
    required this.disabled,
    this.vibrationEnabled = true,
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
              UiClickSound.play();
              if (widget.vibrationEnabled) HapticFeedback.lightImpact();
              widget.onTap();
            },
      onTapCancel: disabled ? null : () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Opacity(
          opacity: disabled ? 0.55 : 1.0,
          child: RepaintBoundary(
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
                        vertical: h * 0.02,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: h * 0.02),
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
                                      child: EmbossedButtonText(
                                        text: 'BET',
                                        fontSize: h * 0.16,
                                        strokeWidth: 2.6,
                                        letterSpacing: 0.5,
                                        fillColor: Colors.white,
                                        strokeColor: const Color(0xFF053C14),
                                        shadowColor: const Color(0xFF053C14),
                                      ),
                                    ),
                                    SizedBox(width: h * 0.04),
                                    EmbossedButtonMoneyText(
                                      text: formatMoney(widget.betAmount),
                                      fontSize: h * 0.20,
                                      strokeWidth: 2.6,
                                      letterSpacing: 0.5,
                                      fillColor: const Color(0xFFFFC93C),
                                      strokeColor: const Color(0xFF053C14),
                                      shadowColor: const Color(0xFF053C14),
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
                              EmbossedButtonText(
                                text: 'DOUBLE CHANCE',
                                fontSize: h * 0.13,
                                strokeWidth: 2.3,
                                letterSpacing: 0.6,
                                fillColor: Colors.white,
                                strokeColor: const Color(0xFF053C14),
                                shadowColor: const Color(0xFF053C14),
                              ),
                              EmbossedButtonText(
                                text: 'TO WIN FEATURE',
                                fontSize: h * 0.13,
                                strokeWidth: 2.3,
                                letterSpacing: 0.6,
                                fillColor: Colors.white,
                                strokeColor: const Color(0xFF053C14),
                                shadowColor: const Color(0xFF053C14),
                              ),
                              SizedBox(height: h * 0.04),
                              OnOffCapsule(isOn: widget.isOn, height: h * 0.31),
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
      ),
    );
  }
}
