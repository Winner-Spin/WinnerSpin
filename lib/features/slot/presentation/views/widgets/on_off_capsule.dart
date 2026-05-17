import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'solid_arrow_painter.dart';

class OnOffCapsule extends StatelessWidget {
  const OnOffCapsule({super.key, required this.isOn, required this.height});

  final bool isOn;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height * 2.7;
    final knobHeight = height * 0.92;
    final knobWidth = height * 1.05;
    final padding = height * 0.02;
    const animationDuration = Duration(milliseconds: 220);
    const animationCurve = Curves.easeInOut;

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.32),
                Colors.black.withValues(alpha: 0.22),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.30),
              width: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedPositioned(
                duration: animationDuration,
                curve: animationCurve,
                left: isOn ? 0 : knobWidth,
                right: isOn ? knobWidth : 0,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: animationDuration,
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
                duration: animationDuration,
                curve: animationCurve,
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: Container(
                    width: knobWidth,
                    height: knobHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(knobHeight / 2),
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
                        width: knobHeight * 0.55,
                        height: knobHeight * 0.55,
                        child: CustomPaint(
                          painter: SolidArrowPainter(
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
