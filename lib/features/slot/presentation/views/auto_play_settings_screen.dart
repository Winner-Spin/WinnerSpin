import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/ui_click_sound.dart';
import '../viewmodels/game_viewmodel.dart';
import 'widgets/spring_popup_card.dart';

class AutoPlaySettingsScreen extends StatefulWidget {
  const AutoPlaySettingsScreen({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  State<AutoPlaySettingsScreen> createState() => _AutoPlaySettingsScreenState();
}

class _AutoPlaySettingsScreenState extends State<AutoPlaySettingsScreen> {
  static const Color _panelColor = Color(0xFFF0CDE6);
  static const Color _panelAccent = Color(0xFFE2BED8);
  static const Color _textColor = Color(0xFF2C2530);

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
              child: Container(color: Colors.black.withValues(alpha: 0.42)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 18),
                Expanded(
                  child: Align(
                    alignment: Alignment.center,
                    child: SpringPopupCard(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.92,
                          maxHeight: MediaQuery.of(context).size.height * 0.46,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: _panelColor,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 28,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(26),
                            child: Column(
                              children: [
                                _buildHeader(context),
                                Expanded(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      22,
                                      42,
                                      22,
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
                                            color: _textColor,
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
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6D7EB),
        border: Border(
          bottom: BorderSide(color: _textColor.withValues(alpha: 0.10)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'AUTO SPIN',
            style: GoogleFonts.barlowCondensed(
              fontSize: 27,
              fontWeight: FontWeight.w900,
              color: _textColor,
              letterSpacing: 1.2,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                UiClickSound.play();
                Navigator.of(context).pop();
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _panelAccent.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 30, color: _textColor),
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
              inactiveTrackColor: _textColor.withValues(alpha: 0.18),
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
              color: _textColor,
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
