import 'package:flutter_test/flutter_test.dart';
import 'package:winner_spin/features/slot/domain/models/symbol_registry.dart';

void main() {
  test('profile avatars contain game items but exclude multiplier bombs', () {
    final avatars = SymbolRegistry.profileAvatars;

    expect(avatars, isNotEmpty);
    expect(avatars.every((symbol) => !symbol.isMultiplier), isTrue);
    expect(avatars.map((symbol) => symbol.id), contains('cupcake'));
    expect(avatars.map((symbol) => symbol.id), contains('pink_bear'));
    expect(avatars.map((symbol) => symbol.id), isNot(contains('multi_2x')));
    expect(
      avatars.length,
      SymbolRegistry.all.where((symbol) => !symbol.isMultiplier).length,
    );
  });

  test('accepts only English avatar ids', () {
    expect(SymbolRegistry.byId('pink_bear')?.id, 'pink_bear');
    expect(SymbolRegistry.byId('heart')?.id, 'heart');
    expect(SymbolRegistry.byId('unsupported_avatar'), isNull);
  });
}
