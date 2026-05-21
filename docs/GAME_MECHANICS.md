# Game Mechanics

EN English | [TR Türkçe](GAME_MECHANICS_TR.md)

This document describes the slot game engine, its subsystems, and the gameplay mechanics used in Winner Spin.

---

## Slot Game Engine

The core gameplay logic starts from a custom slot engine.

The slot engine is responsible for:

- generating the slot grid,
- deciding whether a spin should win,
- producing safe grids,
- producing winning grids,
- detecting cluster wins,
- running tumble/cascade sequences,
- calculating total win,
- applying multiplier values,
- checking scatter payouts,
- triggering Free Spins,
- handling Free Spins retriggers,
- applying pool safety limits,
- adapting behavior according to the current game mode.

The game uses a **6-column x 5-row** slot grid:

```text
Columns: 6
Rows:    5
Total:   30 symbols
```

---

## Engine Modules

The slot engine is split into smaller engine modules instead of keeping every responsibility inside a single file.

Important engine files include:

| File | Responsibility |
| --- | --- |
| `slot_engine.dart` | Main spin orchestration and gameplay result generation |
| `grid_generator.dart` | Safe grid and winning grid generation |
| `tumble_simulator.dart` | Cascade/tumble simulation and cluster win evaluation |
| `multiplier_collector.dart` | Multiplier symbol collection |
| `pool_guard.dart` | Pool safety checks and payout protection |
| `chain_forcer.dart` | Controlled chain/cascade forcing behavior |
| `weighted_random.dart` | Weighted random selection utilities |
| `spin_task.dart` | Spin task modeling |
| `rtp_config.dart` | RTP-related configuration |
| `ante_config.dart` | Ante Bet configuration |
| `buy_config.dart` | Buy Feature configuration |
| `engine_runtime.dart` | Runtime engine state and execution support |

This separation makes the slot engine easier to debug, test, and extend.

---

## Cascade / Tumble Mechanics

Winner Spin uses a cascade-style slot mechanic.

The tumble flow works like this:

```text
1. Generate the initial grid
2. Count regular symbols
3. Detect winning clusters
4. Remove winning symbols
5. Apply gravity
6. Fill empty cells
7. Repeat until no more winning cluster exists
8. Collect multipliers
9. Evaluate scatters
10. Return final spin result
```

A regular symbol creates a cluster win when it appears at least **8 times** on the grid.

Each tumble step stores:

- winning symbol paths,
- grid state after the tumble,
- win amount,
- cluster win data,
- winning positions.

This makes the gameplay more dynamic than a simple one-spin symbol replacement system.

---

## Free Spins

Free Spins are triggered by scatter symbols.

Base game trigger rule:

```text
4+ scatters -> Free Spins
```

Free Spins retrigger rule:

```text
3+ scatters during Free Spins -> Retrigger
```

Free Spins are integrated into the same slot engine flow, but the engine can adjust hit rate, chain probability, multiplier behavior, and scatter trigger behavior depending on whether the spin is a base spin or a free spin.

---

## Multiplier Collection

The project includes multiplier symbols that increase the final payout potential.

Example multiplier values:

```text
2x
3x
5x
10x
25x
50x
100x
```

Multiplier collection is handled separately from the tumble simulation. This keeps multiplier behavior isolated and makes the engine easier to maintain.

The final win calculation follows this general idea:

```text
finalWin = baseWin * finalMultiplier + scatterPayout
```

---

## RTP & Pool System

Winner Spin includes an RTP-aware pool system.

The pool state stores the core counters used by the engine:

```text
totalBetsPlaced
totalPaidOut
totalSpins
```

From those counters, the engine derives runtime values such as:

```text
poolBalance
expectedPool
currentMode
```

The target RTP is designed around:

```text
96.5%
```

The engine uses the stored counters and derived pool values to determine the current game mode and adjust behavior.

Available game modes:

| Mode | Purpose |
| --- | --- |
| `normal` | Default balanced gameplay mode |
| `generous` | Increases payout potential when the game is underpaying |
| `tight` | Reduces payout pressure when needed |
| `jackpot` | Allows more aggressive payout potential under specific pool conditions |
| `recovery` | Protects the pool after overpaying |

This makes the game logic more advanced than a purely random symbol generator.

---

## Pool Guard

The Pool Guard protects the game economy by checking whether certain outcomes are affordable.

It is used for:

- maximum win calculation,
- Free Spins affordability,
- payout safety,
- recovery behavior,
- pool floor protection.

It also exposes a Buy Feature affordability helper for diagnostics and stress scenarios. In the current in-game flow, the Buy Feature purchase is gated by the player's displayed balance, and the paid feature then forces the initial Free Spins trigger so direct bonus access is honored.

This prevents regular spin outcomes from producing unlimited or unsafe payouts without checking the current pool state.

---

## Buy Feature

Winner Spin includes a Buy Feature flow.

The Buy Feature allows the player to directly buy access to a Free Spins round by paying a fixed multiplier of the selected bet amount.

The current game flow checks whether the player can afford the displayed Buy Feature price. Once the purchase is paid, the spin is sent to the engine as a forced Free Spins trigger, while the separate pool affordability helper remains available for diagnostics and stress-test scenarios.

This feature makes the gameplay closer to modern slot game mechanics where players can choose between normal spins and direct bonus access.

---

## Ante Bet

The project includes an Ante Bet mode.

Ante Bet changes the spin behavior by increasing the Free Spins trigger potential while affecting the cost/risk profile of the spin.

This feature allows the player to choose between normal spins and a higher-risk feature-enhanced spin mode.

---

## Auto Spin

Winner Spin includes Auto Spin controls.

Auto Spin is handled through presentation and ViewModel state so that repeated spins can continue while still respecting game conditions such as:

- balance,
- free spin state,
- spin completion,
- win presentation,
- quick stop,
- auto spin continuation guards.

This prevents automatic spins from running without considering the current gameplay state.

---

## Quick Stop

The game supports Quick Stop interaction.

When the player taps during reel animation, the animation flow can be shortened and the result can be presented faster.

This improves the game feel and gives the player more control over spin pacing.
