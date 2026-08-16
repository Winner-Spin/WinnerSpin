import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/models/game_presentation_guards.dart';

void main() {
  group('completed farm win hold', () {
    test('starts for a newly settled normal spin win', () {
      expect(
        GamePresentationGuards.shouldHoldCompletedFarmWin(
          isInFreeSpins: false,
          lastSpinWasFreeSpin: false,
          isBusy: false,
          hasResult: true,
          lastWin: 125,
          holdScheduledThisSpin: false,
        ),
        isTrue,
      );
    });

    test('does not start outside a completed unscheduled farm win', () {
      const excludedCases = [
        (
          isInFreeSpins: true,
          lastSpinWasFreeSpin: false,
          isBusy: false,
          hasResult: true,
          lastWin: 125.0,
          holdScheduledThisSpin: false,
        ),
        (
          isInFreeSpins: false,
          lastSpinWasFreeSpin: true,
          isBusy: false,
          hasResult: true,
          lastWin: 125.0,
          holdScheduledThisSpin: false,
        ),
        (
          isInFreeSpins: false,
          lastSpinWasFreeSpin: false,
          isBusy: true,
          hasResult: true,
          lastWin: 125.0,
          holdScheduledThisSpin: false,
        ),
        (
          isInFreeSpins: false,
          lastSpinWasFreeSpin: false,
          isBusy: false,
          hasResult: false,
          lastWin: 125.0,
          holdScheduledThisSpin: false,
        ),
        (
          isInFreeSpins: false,
          lastSpinWasFreeSpin: false,
          isBusy: false,
          hasResult: true,
          lastWin: 0.0,
          holdScheduledThisSpin: false,
        ),
        (
          isInFreeSpins: false,
          lastSpinWasFreeSpin: false,
          isBusy: false,
          hasResult: true,
          lastWin: 125.0,
          holdScheduledThisSpin: true,
        ),
      ];

      for (final testCase in excludedCases) {
        expect(
          GamePresentationGuards.shouldHoldCompletedFarmWin(
            isInFreeSpins: testCase.isInFreeSpins,
            lastSpinWasFreeSpin: testCase.lastSpinWasFreeSpin,
            isBusy: testCase.isBusy,
            hasResult: testCase.hasResult,
            lastWin: testCase.lastWin,
            holdScheduledThisSpin: testCase.holdScheduledThisSpin,
          ),
          isFalse,
        );
      }
    });
  });
}
