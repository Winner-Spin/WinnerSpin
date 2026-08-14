import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/core/typography/app_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preloads every bundled font before the first application frame', () async {
    final firstLoad = AppFonts.preload();
    final repeatedLoad = AppFonts.preload();

    expect(identical(repeatedLoad, firstLoad), isTrue);
    await expectLater(firstLoad, completes);
  });
}
