import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/engine_runtime.dart';
import 'package:winner_spin/features/slot/domain/engine/rtp_config.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';
import 'package:winner_spin/features/slot/domain/enums/game_mode.dart';

class _ForcedModePoolState extends PoolState {
  final GameMode forcedMode;
  _ForcedModePoolState(this.forcedMode)
    : super(totalBetsPlaced: 1000000000000, totalSpins: 50);
  @override
  GameMode get currentMode => forcedMode;
}

void main() {
  test('Per-mode RTP measurement — 5M spins each', () {
    const totalSpinsPerMode = 5000000;
    const betAmount = 100.0;

    final results = <GameMode, _ModeStats>{};

    for (final mode in GameMode.values) {
      resetEngineRngForTesting(1000 + mode.index);
      final pool = _ForcedModePoolState(mode);
      final stats = _ModeStats();

      int fsRemaining = 0;

      for (int i = 0; i < totalSpinsPerMode; i++) {
        final isFs = fsRemaining > 0;

        if (isFs) {
          fsRemaining--;
          stats.fsSpins++;
        } else {
          pool.recordBet(betAmount);
          stats.totalWagered += betAmount;
          stats.baseSpins++;
        }

        final result = SlotEngine.spin(pool, betAmount, isFreeSpins: isFs);
        pool.recordPayout(result.totalWin);
        stats.totalPaidOut += result.totalWin;

        if (isFs) stats.totalFsPayout += result.totalWin;
        if (result.totalWin > 0) stats.winningSpins++;
        if (result.totalWin > stats.maxSingleWin) {
          stats.maxSingleWin = result.totalWin;
        }

        if (result.freeSpinsTriggered) {
          if (result.isRetrigger) {
            stats.retriggers++;
            fsRemaining += 5;
          } else {
            stats.initialTriggers++;
            fsRemaining += 10;
          }
        }
      }

      results[mode] = stats;
    }

    final buf = StringBuffer();
    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('         PER-MODE RTP MEASUREMENT — 5M spins each');
    buf.writeln('═══════════════════════════════════════════════════════════════');
    buf.writeln('');
    buf.writeln('Funded-profile targets with visible payout math');
    buf.writeln('');
    buf.writeln('Mode      | RTP     | Target  | Hit Rate | FS%   | Avg FS   | Max Win  | Delta');
    buf.writeln('----------|---------|---------|----------|-------|----------|----------|-------');

    for (final mode in GameMode.values) {
      final s = results[mode]!;
      final rtp = (s.totalPaidOut / s.totalWagered) * 100;
      final hitRate = (s.winningSpins / (s.baseSpins + s.fsSpins)) * 100;
      final fsPercent = (s.fsSpins / (s.baseSpins + s.fsSpins)) * 100;
      final avgFsRound = s.initialTriggers > 0
          ? (s.totalFsPayout / s.initialTriggers) / betAmount
          : 0;
      final maxWinX = s.maxSingleWin / betAmount;
      final target = RtpConfig.modeTargetRtp[mode]! * 100;
      final delta = rtp - target;
      final deltaSign = delta >= 0 ? '+' : '';

      buf.writeln(
        '${mode.name.padRight(9)} | '
        '${rtp.toStringAsFixed(2).padLeft(6)}% | '
        '${target.toStringAsFixed(2).padLeft(6)}% | '
        '${hitRate.toStringAsFixed(2).padLeft(5)}%   | '
        '${fsPercent.toStringAsFixed(2).padLeft(4)}% | '
        '${avgFsRound.toStringAsFixed(1).padLeft(7)}x | '
        '${maxWinX.toStringAsFixed(0).padLeft(7)}x | '
        '$deltaSign${delta.toStringAsFixed(2).padLeft(5)}',
      );
    }

    buf.writeln('');
    buf.writeln('═══════════════════════════════════════════════════════════════');

    // ignore: avoid_print
    print(buf.toString());

    for (final mode in GameMode.values) {
      final stats = results[mode]!;
      final rtp = stats.totalPaidOut / stats.totalWagered * 100;
      final target = RtpConfig.modeTargetRtp[mode]! * 100;
      final tolerance = switch (mode) {
        GameMode.generous || GameMode.jackpot => 2.0,
        _ => 1.0,
      };
      expect(rtp, closeTo(target, tolerance));
    }
  });
}

class _ModeStats {
  double totalWagered = 0;
  double totalPaidOut = 0;
  double totalFsPayout = 0;
  double maxSingleWin = 0;
  int baseSpins = 0;
  int fsSpins = 0;
  int winningSpins = 0;
  int initialTriggers = 0;
  int retriggers = 0;
}
