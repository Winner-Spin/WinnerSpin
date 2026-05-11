import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/slot_engine.dart';
import 'package:winner_spin/features/slot/domain/models/pool_state.dart';

void main() {
  test('forceFsTrigger awards scatter payout in totalWin', () {
    final pool = PoolState(totalBetsPlaced: 100000, totalPaidOut: 50000, totalSpins: 200);
    const bet = 100.0;

    int count4 = 0, count5 = 0, count6 = 0;
    double totalWin4 = 0, totalWin5 = 0, totalWin6 = 0;

    for (int i = 0; i < 100; i++) {
      final result = SlotEngine.spin(pool, bet, forceFsTrigger: true);
      switch (result.scatterCount) {
        case 4:
          count4++;
          totalWin4 += result.totalWin;
          break;
        case 5:
          count5++;
          totalWin5 += result.totalWin;
          break;
        case 6:
          count6++;
          totalWin6 += result.totalWin;
          break;
      }
      print('Spin $i: scatters=${result.scatterCount} totalWin=${result.totalWin} scatterPayout=${result.scatterPayout}');
      if (i > 10) break;
    }
  });

  test('depleted pool forceFsTrigger still awards scatter payout', () {
    final pool = PoolState(totalBetsPlaced: 10000, totalPaidOut: 50000, totalSpins: 200);
    const bet = 100.0;

    for (int i = 0; i < 5; i++) {
      final result = SlotEngine.spin(pool, bet, forceFsTrigger: true);
      print('Depleted spin $i: scatters=${result.scatterCount} totalWin=${result.totalWin} scatterPayout=${result.scatterPayout}');
    }
  });
}
