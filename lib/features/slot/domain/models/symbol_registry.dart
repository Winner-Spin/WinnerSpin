import '../enums/game_mode.dart';
import 'slot_symbol.dart';
import '../enums/symbol_tier.dart';

class SymbolRegistry {
  SymbolRegistry._();

  static const String defaultProfileAvatarId = 'pink_bear';

  static const List<SlotSymbol> all = [
    // Low tier
    SlotSymbol(
      id: 'banana',
      assetPath: 'lib/images/slot_main_screen/Items/muz.png',
      baseWeight: 35,
      tier: SymbolTier.low,
      payouts: {8: 0.25, 10: 0.75, 12: 2.0},
      displayScale: 1.12,
    ),
    SlotSymbol(
      id: 'grapes',
      assetPath: 'lib/images/slot_main_screen/Items/uzum.png',
      baseWeight: 30,
      tier: SymbolTier.low,
      payouts: {8: 0.40, 10: 0.90, 12: 4.0},
    ),
    SlotSymbol(
      id: 'watermelon',
      assetPath: 'lib/images/slot_main_screen/Items/karpuz.png',
      baseWeight: 28,
      tier: SymbolTier.low,
      payouts: {8: 0.50, 10: 1.00, 12: 5.0},
      displayScale: 1.12,
    ),

    // Mid tier
    SlotSymbol(
      id: 'peach',
      assetPath: 'lib/images/slot_main_screen/Items/seftali.png',
      baseWeight: 22,
      tier: SymbolTier.mid,
      payouts: {8: 0.80, 10: 1.20, 12: 8.0},
    ),
    SlotSymbol(
      id: 'apple',
      assetPath: 'lib/images/slot_main_screen/Items/Apple.png',
      baseWeight: 18,
      tier: SymbolTier.mid,
      payouts: {8: 1.00, 10: 1.50, 12: 10.0},
      displayScale: 1.12,
    ),

    // High tier
    SlotSymbol(
      id: 'strawberry',
      assetPath: 'lib/images/slot_main_screen/Items/cilek.png',
      baseWeight: 14,
      tier: SymbolTier.high,
      payouts: {8: 1.50, 10: 2.00, 12: 12.0},
    ),
    SlotSymbol(
      id: 'pink_bear',
      assetPath: 'lib/images/slot_main_screen/Items/pembe_ayi.png',
      baseWeight: 10,
      tier: SymbolTier.high,
      payouts: {8: 2.00, 10: 5.00, 12: 15.0},
    ),
    SlotSymbol(
      id: 'green_bear',
      assetPath: 'lib/images/slot_main_screen/Items/yesil_ayi.png',
      baseWeight: 7,
      tier: SymbolTier.high,
      payouts: {8: 5.00, 10: 10.00, 12: 25.0},
    ),
    SlotSymbol(
      id: 'heart',
      assetPath: 'lib/images/slot_main_screen/Items/Kalp.png',
      baseWeight: 4,
      tier: SymbolTier.high,
      payouts: {8: 10.00, 10: 25.00, 12: 50.0},
    ),

    // Scatter
    SlotSymbol(
      id: 'cupcake',
      assetPath: 'lib/images/slot_main_screen/Items/cupCake.png',
      baseWeight: 8,
      tier: SymbolTier.scatter,
      scatterPayouts: {4: 3.0, 5: 5.0, 6: 100.0},
      displayScale: 1.40,
    ),

    // Multipliers
    SlotSymbol(
      id: 'multi_2x',
      assetPath: 'lib/images/slot_main_screen/Items/2x.png',
      baseWeight: 0.30,
      tier: SymbolTier.multiplier,
      multiplierValue: 2,
    ),
    SlotSymbol(
      id: 'multi_3x',
      assetPath: 'lib/images/slot_main_screen/Items/3x.png',
      baseWeight: 0.20,
      tier: SymbolTier.multiplier,
      multiplierValue: 3,
    ),
    SlotSymbol(
      id: 'multi_5x',
      assetPath: 'lib/images/slot_main_screen/Items/5x.png',
      baseWeight: 0.13,
      tier: SymbolTier.multiplier,
      multiplierValue: 5,
    ),
    SlotSymbol(
      id: 'multi_10x',
      assetPath: 'lib/images/slot_main_screen/Items/10x.png',
      baseWeight: 0.07,
      tier: SymbolTier.multiplier,
      multiplierValue: 10,
    ),
    SlotSymbol(
      id: 'multi_25x',
      assetPath: 'lib/images/slot_main_screen/Items/25x.png',
      baseWeight: 0.025,
      tier: SymbolTier.multiplier,
      multiplierValue: 25,
    ),
    SlotSymbol(
      id: 'multi_50x',
      assetPath: 'lib/images/slot_main_screen/Items/50x.png',
      baseWeight: 0.012,
      tier: SymbolTier.multiplier,
      multiplierValue: 50,
    ),
    SlotSymbol(
      id: 'multi_100x',
      assetPath: 'lib/images/slot_main_screen/Items/100x.png',
      baseWeight: 0.0025,
      tier: SymbolTier.multiplier,
      multiplierValue: 100,
    ),
  ];

  static final Map<String, SlotSymbol> _byPath = {
    for (final s in all) s.assetPath: s,
  };

  static final Map<String, SlotSymbol> _byId = {
    for (final symbol in all) symbol.id: symbol,
  };

  static final List<SlotSymbol> profileAvatars = List.unmodifiable(
    all.where((symbol) => !symbol.isMultiplier),
  );

  static SlotSymbol? byPath(String path) => _byPath[path];

  static SlotSymbol? byId(String id) => _byId[id];

  static bool isProfileAvatar(String id) {
    final symbol = byId(id);
    return symbol != null && !symbol.isMultiplier;
  }

  static const Map<GameMode, Map<SymbolTier, double>> weightMultipliers = {
    GameMode.recovery: {
      SymbolTier.low: 1.4,
      SymbolTier.mid: 1.1,
      SymbolTier.high: 0.5,
      SymbolTier.scatter: 0.6,
      SymbolTier.multiplier: 0.2,
    },
    GameMode.tight: {
      SymbolTier.low: 1.2,
      SymbolTier.mid: 0.95,
      SymbolTier.high: 0.5,
      SymbolTier.scatter: 0.8,
      SymbolTier.multiplier: 0.4,
    },
    GameMode.normal: {
      SymbolTier.low: 1.0,
      SymbolTier.mid: 1.0,
      SymbolTier.high: 1.0,
      SymbolTier.scatter: 1.0,
      SymbolTier.multiplier: 1.0,
    },
    GameMode.generous: {
      SymbolTier.low: 0.85,
      SymbolTier.mid: 1.1,
      SymbolTier.high: 1.3,
      SymbolTier.scatter: 1.2,
      SymbolTier.multiplier: 1.5,
    },
    GameMode.jackpot: {
      SymbolTier.low: 0.7,
      SymbolTier.mid: 1.2,
      SymbolTier.high: 1.8,
      SymbolTier.scatter: 1.5,
      SymbolTier.multiplier: 2.5,
    },
  };
}
