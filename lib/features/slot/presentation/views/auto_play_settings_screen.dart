import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';

class AutoPlaySettingsScreen extends StatefulWidget {
  const AutoPlaySettingsScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<AutoPlaySettingsScreen> createState() => _AutoPlaySettingsScreenState();
}

class _AutoPlaySettingsScreenState extends State<AutoPlaySettingsScreen> {
  static const List<int> _spinCounts = [
    10,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
    100,
  ];

  int _spinCountIndex = 9;

  int get _spinCount => _spinCounts[_spinCountIndex];

  void _startAutoPlay() {
    widget.viewModel.startAutoSpin(
      _spinCount,
      speedMultiplier: widget.viewModel.speedMultiplier,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Container(color: Colors.transparent),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.48,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.93),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          child: Column(
                            children: [
                              _buildHeader(context),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    76,
                                    20,
                                    24,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'AUTOSPIN COUNT',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.barlowCondensed(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      _buildSpinCountSlider(),
                                      const SizedBox(height: 40),
                                      _buildStartButton(),
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
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'AUTOMATIC PLAY SETTINGS',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFE5A800),
                  letterSpacing: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 30,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final disabled =
            widget.viewModel.isBusy || widget.viewModel.isAutoSpinning;
        return GestureDetector(
          onTap: disabled
              ? null
              : () {
                  UiClickSound.play();
                  _startAutoPlay();
                },
          child: Opacity(
            opacity: disabled ? 0.55 : 1,
            child: Container(
              width: double.infinity,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF00C76A),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.32),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'START AUTOPLAY ($_spinCount)',
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSpinCountSlider() {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF00C76A),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.34),
              trackHeight: 3,
              thumbColor: const Color(0xFF00C76A),
              overlayColor: const Color(0xFF00C76A).withValues(alpha: 0.18),
              thumbShape: const _SettingsToggleSliderThumbShape(),
            ),
            child: Slider(
              min: 0,
              max: (_spinCounts.length - 1).toDouble(),
              divisions: _spinCounts.length - 1,
              value: _spinCountIndex.toDouble(),
              onChanged: (value) {
                setState(() => _spinCountIndex = value.round());
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '$_spinCount',
            textAlign: TextAlign.right,
            style: GoogleFonts.barlowCondensed(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsToggleSliderThumbShape extends SliderComponentShape {
  const _SettingsToggleSliderThumbShape();

  static const Size _thumbSize = Size(36, 30);

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => _thumbSize;

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    final rect = Rect.fromCenter(
      center: center,
      width: _thumbSize.width,
      height: _thumbSize.height,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(rrect.shift(const Offset(0, 2)), shadowPaint);

    canvas.drawRRect(rrect, Paint()..color = const Color(0xFF13DF70));

    final linePaint = Paint()
      ..color = const Color(0xFF008A3D)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    const spacing = 7.0;
    for (var i = -1; i <= 1; i++) {
      final x = center.dx + i * spacing;
      canvas.drawLine(
        Offset(x, center.dy - 6),
        Offset(x, center.dy + 6),
        linePaint,
      );
    }
  }
}
