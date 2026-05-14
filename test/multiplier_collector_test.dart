import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/engine/multiplier_collector.dart';

void main() {
  test('visible multiplier total is used unchanged', () {
    const visibleTotal = 2.0;

    expect(MultiplierCollector.finalize(visibleTotal), visibleTotal);
  });
}
