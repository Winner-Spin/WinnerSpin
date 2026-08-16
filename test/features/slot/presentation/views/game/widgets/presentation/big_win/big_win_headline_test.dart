import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/presentation/views/game/widgets/presentation/big_win/big_win_headline.dart';

void main() {
  testWidgets('paints every star foreground separately from its glow', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BigWinStarsRow())),
      ),
    );

    expect(find.byType(BigWinStar), findsNWidgets(4));

    for (var i = 0; i < 4; i++) {
      final foreground = tester.widget<Icon>(
        find.byKey(ValueKey('big-win-star-foreground-$i')),
      );
      expect(foreground.color, BigWinStar.color);
      expect(foreground.shadows, isNull);
    }

    final firstStarIcons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byType(BigWinStar).first,
        matching: find.byType(Icon),
      ),
    );
    expect(firstStarIcons, hasLength(2));
    expect(firstStarIcons.first.color, Colors.transparent);
    expect(firstStarIcons.first.shadows, hasLength(2));
  });
}
