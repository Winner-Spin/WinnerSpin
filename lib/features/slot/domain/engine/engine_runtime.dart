import 'dart:math';

/// Shared runtime constants and RNG for engine sub-modules.
/// Re-exported via `SlotEngine.columns` / `SlotEngine.rows` for callers
/// outside the engine (e.g. ViewModel).

const int kEngineColumns = 6;
const int kEngineRows = 5;
const int kEngineTotalSlots = kEngineColumns * kEngineRows;

/// Single Random instance shared across grid-generation, weighted picks,
/// chain forcing, and trigger rolls within a spin.
final Random engineRng = Random();
