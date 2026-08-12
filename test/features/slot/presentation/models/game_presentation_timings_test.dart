import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/models/game_presentation_timings.dart';

void main() {
  test('waits 200 ms after the post-win pulse before the next free spin', () {
    expect(
      GamePresentationTimings.freeSpinPostWinHold -
          GamePresentationTimings.freeSpinPostWinPulse,
      const Duration(milliseconds: 200),
    );
  });

  test('uses the selected speed only for flight durations', () {
    const base = Duration(milliseconds: 900);

    expect(GamePresentationTimings.flightSpeedFactorFor(1), 1.0);
    expect(GamePresentationTimings.flightSpeedFactorFor(2), 1.125);
    expect(GamePresentationTimings.flightSpeedFactorFor(3), 1.25);
    expect(GamePresentationTimings.flightDurationForSpeed(base, 1), base);
    expect(
      GamePresentationTimings.flightDurationForSpeed(base, 2),
      const Duration(milliseconds: 800),
    );
    expect(
      GamePresentationTimings.flightDurationForSpeed(base, 3),
      const Duration(milliseconds: 720),
    );
  });

  test('clamps unsupported speed levels to the available range', () {
    const base = Duration(milliseconds: 600);

    expect(GamePresentationTimings.flightDurationForSpeed(base, 0), base);
    expect(
      GamePresentationTimings.flightDurationForSpeed(base, 4),
      const Duration(milliseconds: 480),
    );
  });
}
