import 'package:flutter/material.dart';

import '../../../../../domain/models/symbol_registry.dart';

class TumbleGlowPalette {
  const TumbleGlowPalette({
    required this.sweep,
    required this.sparkle,
    required this.particle,
  });

  final List<Color> sweep;
  final Color sparkle;
  final Color particle;

  static const _yellow = TumbleGlowPalette(
    sweep: [
      Color(0xFFFFB300),
      Color(0xFFFFE082),
      Color(0xFFFFFFFF),
      Color(0xFFFFE082),
      Color(0xFFFFB300),
    ],
    sparkle: Color(0xFFFFF8E1),
    particle: Color(0xFFFFD54F),
  );

  static const _purple = TumbleGlowPalette(
    sweep: [
      Color(0xFF6A1B9A),
      Color(0xFFCE93D8),
      Color(0xFFFFFFFF),
      Color(0xFFCE93D8),
      Color(0xFF6A1B9A),
    ],
    sparkle: Color(0xFFE1BEE7),
    particle: Color(0xFFBA68C8),
  );

  static const _green = TumbleGlowPalette(
    sweep: [
      Color(0xFF2E7D32),
      Color(0xFFA5D6A7),
      Color(0xFFFFFFFF),
      Color(0xFFA5D6A7),
      Color(0xFF2E7D32),
    ],
    sparkle: Color(0xFFC8E6C9),
    particle: Color(0xFF66BB6A),
  );

  static const _orange = TumbleGlowPalette(
    sweep: [
      Color(0xFFEF6C00),
      Color(0xFFFFB74D),
      Color(0xFFFFFFFF),
      Color(0xFFFFB74D),
      Color(0xFFEF6C00),
    ],
    sparkle: Color(0xFFFFE0B2),
    particle: Color(0xFFFFA726),
  );

  static const _red = TumbleGlowPalette(
    sweep: [
      Color(0xFFB71C1C),
      Color(0xFFEF9A9A),
      Color(0xFFFFFFFF),
      Color(0xFFEF9A9A),
      Color(0xFFB71C1C),
    ],
    sparkle: Color(0xFFFFCDD2),
    particle: Color(0xFFEF5350),
  );

  static const _pink = TumbleGlowPalette(
    sweep: [
      Color(0xFFAD1457),
      Color(0xFFF48FB1),
      Color(0xFFFFFFFF),
      Color(0xFFF48FB1),
      Color(0xFFAD1457),
    ],
    sparkle: Color(0xFFFCE4EC),
    particle: Color(0xFFF06292),
  );

  static const _cyan = TumbleGlowPalette(
    sweep: [
      Color(0xFF006064),
      Color(0xFF80DEEA),
      Color(0xFFFFFFFF),
      Color(0xFF80DEEA),
      Color(0xFF006064),
    ],
    sparkle: Color(0xFFB2EBF2),
    particle: Color(0xFF4DD0E1),
  );

  static const _gold = TumbleGlowPalette(
    sweep: [
      Color(0xFFFF6F00),
      Color(0xFFFFCA28),
      Color(0xFFFFFFFF),
      Color(0xFFFFCA28),
      Color(0xFFFF6F00),
    ],
    sparkle: Color(0xFFFFE082),
    particle: Color(0xFFFFB300),
  );

  static TumbleGlowPalette forPath(String path) {
    final id = SymbolRegistry.byPath(path)?.id;
    switch (id) {
      case 'banana':
        return _yellow;
      case 'grapes':
        return _purple;
      case 'watermelon':
      case 'green_bear':
        return _green;
      case 'peach':
        return _orange;
      case 'apple':
      case 'strawberry':
      case 'heart':
        return _red;
      case 'pink_bear':
        return _pink;
      case 'cupcake':
        return _cyan;
      case 'multi_2x':
      case 'multi_3x':
      case 'multi_5x':
      case 'multi_10x':
      case 'multi_25x':
      case 'multi_50x':
      case 'multi_100x':
        return _gold;
      default:
        return _yellow;
    }
  }
}
