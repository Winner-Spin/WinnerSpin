import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/engine_runtime.dart';
import 'package:winner_spin/features/slot/domain/engine/rtp_config.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/enums/game_mode.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';

const _baseSpins = int.fromEnvironment(
  'RTP_CALIBRATION_SPINS',
  defaultValue: 10000,
);
const _bet = 100.0;
const _calibrationReserve = 1000000000000.0;
const _buyRounds = int.fromEnvironment(
  'RTP_CALIBRATION_BUYS',
  defaultValue: 1000,
);
const _seedBase = int.fromEnvironment(
  'RTP_CALIBRATION_SEED',
  defaultValue: 1000,
);
const _modeFilter = String.fromEnvironment('RTP_CALIBRATION_MODE');

class _FundedModePoolState extends PoolState {
  _FundedModePoolState(this.mode)
    : super(totalBetsPlaced: _calibrationReserve, totalSpins: 50);

  final GameMode mode;

  @override
  GameMode get currentMode => mode;
}

void main() {
  test('reports funded per-mode RTP components for weight calibration', () {
    final rows = <String>[];
    double weightedRtp = 0;

    for (final mode in GameMode.values.where(
      (mode) => _modeFilter.isEmpty || mode.name == _modeFilter,
    )) {
      resetEngineRngForTesting(_seedBase + mode.index);
      final pool = _FundedModePoolState(mode);
      final stats = _runPaidSpins(pool);
      final target = RtpConfig.modeTargetRtp[mode]! * 100;
      weightedRtp += stats.rtp * _sessionWeight(mode);

      rows.add(
        '${mode.name.padRight(9)} | '
        '${stats.rtp.toStringAsFixed(2).padLeft(7)}% | '
        '${target.toStringAsFixed(2).padLeft(6)}% | '
        '${stats.baseRtp.toStringAsFixed(2).padLeft(7)}% | '
        '${stats.fsRtp.toStringAsFixed(2).padLeft(7)}% | '
        '${stats.triggerRate.toStringAsFixed(3).padLeft(6)}% | '
        '${stats.averageFsRound.toStringAsFixed(1).padLeft(7)}x',
      );

      expect(stats.totalPayout, isNonNegative);
      if (_baseSpins >= 5000000) {
        final tolerance = switch (mode) {
          GameMode.generous || GameMode.jackpot => 2.0,
          _ => 1.0,
        };
        expect(stats.rtp, closeTo(target, tolerance));
      }
    }

    // ignore: avoid_print
    print(
      '\nFUNDED PER-MODE CALIBRATION '
      '($_baseSpins paid spins/mode, seed $_seedBase)\n'
      'Mode      | Total RTP | Target  | Base RTP  | FS RTP    | Trigger | Avg FS\n'
      '----------|-----------|---------|-----------|-----------|---------|--------\n'
      '${rows.join('\n')}\n'
      'Weighted funded RTP: ${weightedRtp.toStringAsFixed(2)}%\n',
    );
  });

  test('reports live pool RTP with mode selection and guards enabled', () {
    resetEngineRngForTesting(_seedBase + 10000);
    final modeCounts = <GameMode, int>{for (final mode in GameMode.values) mode: 0};
    final stats = _runPaidSpins(
      PoolState(modeRandom: Random(_seedBase + 20000)),
      modeCounts: modeCounts,
    );
    final totalModeSpins = modeCounts.values.fold<int>(0, (sum, value) => sum + value);
    final modeDistribution = GameMode.values
        .map(
          (mode) =>
              '${mode.name} '
              '${(modeCounts[mode]! / totalModeSpins * 100).toStringAsFixed(1)}%',
        )
        .join(' | ');

    // ignore: avoid_print
    print(
      '\nLIVE POOL CALIBRATION '
      '($_baseSpins paid spins, seed $_seedBase)\n'
      'RTP: ${stats.rtp.toStringAsFixed(2)}% | '
      'Base: ${stats.baseRtp.toStringAsFixed(2)}% | '
      'FS: ${stats.fsRtp.toStringAsFixed(2)}% | '
      'Trigger: ${stats.triggerRate.toStringAsFixed(3)}%\n'
      '$modeDistribution\n',
    );

    expect(stats.totalPayout, isNonNegative);
    if (_baseSpins >= 5000000) {
      expect(stats.rtp, closeTo(96.5, 1.0));
    }
  });

  test('reports live ante RTP with visible payout math', () {
    resetEngineRngForTesting(_seedBase + 30000);
    final stats = _runAntePaidSpins(
      PoolState(modeRandom: Random(_seedBase + 40000)),
    );

    // ignore: avoid_print
    print(
      '\nANTE CALIBRATION ($_baseSpins paid spins, seed $_seedBase)\n'
      'RTP: ${stats.rtp.toStringAsFixed(2)}% | '
      'Base: ${stats.baseRtp.toStringAsFixed(2)}% | '
      'FS: ${stats.fsRtp.toStringAsFixed(2)}% | '
      'Trigger: ${stats.triggerRate.toStringAsFixed(3)}%\n',
    );

    expect(stats.totalPayout, isNonNegative);
    if (_baseSpins >= 5000000) {
      expect(stats.rtp, closeTo(96.5, 1.0));
    }
  });

  test('reports live Buy FS RTP including the visible trigger spin', () {
    resetEngineRngForTesting(_seedBase + 50000);
    final stats = _runBuyRounds(
      PoolState(modeRandom: Random(_seedBase + 60000)),
    );

    // ignore: avoid_print
    print(
      '\nBUY FS CALIBRATION ($_buyRounds buys, seed $_seedBase)\n'
      'RTP: ${stats.rtp.toStringAsFixed(2)}% | '
      'Trigger spin: ${stats.baseRtp.toStringAsFixed(2)}% | '
      'FS: ${stats.fsRtp.toStringAsFixed(2)}% | '
      'Avg round: ${stats.averageFsRound.toStringAsFixed(1)}x\n',
    );

    expect(stats.totalPayout, isNonNegative);
    if (_buyRounds >= 100000) {
      expect(stats.rtp, closeTo(96.5, 1.0));
    }
  });

  test('reports funded Buy FS RTP before live guard truncation', () {
    resetEngineRngForTesting(_seedBase + 70000);
    final pool = PoolState(
      totalBetsPlaced: _calibrationReserve,
      totalPaidOut: _calibrationReserve * PoolState.targetRTP,
      totalSpins: 50,
      modeRandom: Random(_seedBase + 80000),
    );
    final stats = _runBuyRounds(pool);

    // ignore: avoid_print
    print(
      '\nFUNDED BUY FS CALIBRATION ($_buyRounds buys, seed $_seedBase)\n'
      'RTP: ${stats.rtp.toStringAsFixed(2)}% | '
      'Trigger spin: ${stats.baseRtp.toStringAsFixed(2)}% | '
      'FS: ${stats.fsRtp.toStringAsFixed(2)}% | '
      'Avg round: ${stats.averageFsRound.toStringAsFixed(1)}x\n',
    );

    expect(stats.totalPayout, isNonNegative);
    if (_buyRounds >= 100000) {
      expect(stats.rtp, closeTo(96.5, 1.0));
    }
  });

  test('reports funded Buy FS RTP for each forced pool mode', () {
    final rows = <String>[];
    for (final mode in GameMode.values) {
      resetEngineRngForTesting(_seedBase + 90000 + mode.index);
      final stats = _runBuyRounds(_FundedModePoolState(mode));
      rows.add('${mode.name}: ${stats.rtp.toStringAsFixed(2)}%');
      expect(stats.totalPayout, isNonNegative);
      if (_buyRounds >= 50000) {
        expect(stats.rtp, closeTo(96.5, 2.5));
      }
    }

    // ignore: avoid_print
    print(
      '\nFUNDED BUY FS BY MODE ($_buyRounds buys/mode, seed $_seedBase)\n'
      '${rows.join(' | ')}\n',
    );
  });
}

double _sessionWeight(GameMode mode) {
  switch (mode) {
    case GameMode.recovery:
      return 0.02;
    case GameMode.tight:
      return 0.13;
    case GameMode.normal:
      return 0.65;
    case GameMode.generous:
      return 0.17;
    case GameMode.jackpot:
      return 0.03;
  }
}

_ModeStats _runPaidSpins(
  PoolState pool, {
  Map<GameMode, int>? modeCounts,
}) {
  double basePayout = 0;
  double fsPayout = 0;
  int triggers = 0;
  int fsSpins = 0;

  for (int spin = 0; spin < _baseSpins; spin++) {
    pool.recordBet(_bet);
    _recordMode(pool, modeCounts);
    final result = SlotEngine.spin(pool, _bet);
    pool.recordPayout(result.totalWin);
    basePayout += result.totalWin;

    if (!result.freeSpinsTriggered) continue;
    triggers++;

    int remaining = 10;
    while (remaining > 0) {
      remaining--;
      fsSpins++;
      _recordMode(pool, modeCounts);
      final fsResult = SlotEngine.spin(pool, _bet, isFreeSpins: true);
      pool.recordPayout(fsResult.totalWin);
      fsPayout += fsResult.totalWin;
      if (fsResult.freeSpinsTriggered && fsResult.isRetrigger) {
        remaining += 5;
      }
    }
  }

  return _ModeStats(
    wagered: _baseSpins * _bet,
    basePayout: basePayout,
    fsPayout: fsPayout,
    triggers: triggers,
    fsSpins: fsSpins,
  );
}

_ModeStats _runAntePaidSpins(PoolState pool) {
  const anteCost = _bet * 1.25;
  double basePayout = 0;
  double fsPayout = 0;
  int triggers = 0;
  int fsSpins = 0;

  for (int spin = 0; spin < _baseSpins; spin++) {
    pool.recordBet(anteCost);
    final result = SlotEngine.spin(pool, _bet, anteBet: true);
    pool.recordPayout(result.totalWin);
    basePayout += result.totalWin;

    if (!result.freeSpinsTriggered) continue;
    triggers++;
    int remaining = 10;
    while (remaining > 0) {
      remaining--;
      fsSpins++;
      final fsResult = SlotEngine.spin(
        pool,
        _bet,
        isFreeSpins: true,
        anteBet: true,
      );
      pool.recordPayout(fsResult.totalWin);
      fsPayout += fsResult.totalWin;
      if (fsResult.freeSpinsTriggered && fsResult.isRetrigger) {
        remaining += 5;
      }
    }
  }

  return _ModeStats(
    wagered: _baseSpins * anteCost,
    basePayout: basePayout,
    fsPayout: fsPayout,
    triggers: triggers,
    fsSpins: fsSpins,
    paidRounds: _baseSpins,
  );
}

_ModeStats _runBuyRounds(PoolState pool) {
  double triggerPayout = 0;
  double fsPayout = 0;
  int fsSpins = 0;

  for (int buy = 0; buy < _buyRounds; buy++) {
    pool.recordBet(_bet * SlotEngine.buyFeaturePriceMultiplier);
    final triggerResult = SlotEngine.spin(
      pool,
      _bet,
      buyFs: true,
      forceFsTrigger: true,
    );
    pool.recordPayout(triggerResult.totalWin);
    triggerPayout += triggerResult.totalWin;

    int remaining = triggerResult.freeSpinsTriggered ? 10 : 0;
    while (remaining > 0) {
      remaining--;
      fsSpins++;
      final fsResult = SlotEngine.spin(
        pool,
        _bet,
        isFreeSpins: true,
        buyFs: true,
      );
      pool.recordPayout(fsResult.totalWin);
      fsPayout += fsResult.totalWin;
      if (fsResult.freeSpinsTriggered && fsResult.isRetrigger) {
        remaining += 5;
      }
    }
  }

  return _ModeStats(
    wagered: _buyRounds * _bet * SlotEngine.buyFeaturePriceMultiplier,
    basePayout: triggerPayout,
    fsPayout: fsPayout,
    triggers: _buyRounds,
    fsSpins: fsSpins,
    paidRounds: _buyRounds,
  );
}

void _recordMode(PoolState pool, Map<GameMode, int>? modeCounts) {
  if (modeCounts == null) return;
  final mode = pool.currentMode;
  modeCounts[mode] = modeCounts[mode]! + 1;
}

class _ModeStats {
  const _ModeStats({
    required this.wagered,
    required this.basePayout,
    required this.fsPayout,
    required this.triggers,
    required this.fsSpins,
    int? paidRounds,
  }) : paidRounds = paidRounds ?? _baseSpins;

  final double wagered;
  final double basePayout;
  final double fsPayout;
  final int triggers;
  final int fsSpins;
  final int paidRounds;

  double get totalPayout => basePayout + fsPayout;
  double get rtp => totalPayout / wagered * 100;
  double get baseRtp => basePayout / wagered * 100;
  double get fsRtp => fsPayout / wagered * 100;
  double get triggerRate => triggers / paidRounds * 100;
  double get averageFsRound =>
      triggers == 0 ? 0 : (fsPayout / triggers) / _bet;
}
