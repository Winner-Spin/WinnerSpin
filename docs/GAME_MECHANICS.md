# Game Mechanics

EN English | [TR Türkçe](GAME_MECHANICS_TR.md)

This document describes Winner Spin's current slot rules, payout calculation, Free Spins flow, pool modes, and player controls.

---

## 1. Engine Overview

Winner Spin uses a custom Dart slot engine. A spin is calculated as a complete SpinResult before reel and win animations present it.

The engine is responsible for:

- selecting the current pool mode;
- building mode-aware symbol weights;
- generating safe or winning grids;
- resolving pay-anywhere wins and tumbles;
- collecting final-grid multipliers;
- evaluating scatter payout and Free Spins;
- applying pool affordability and maximum-win guards;
- returning the exact visible payout.

SpinExecutionController calls the engine through Flutter compute. Engine math runs on a temporary background isolate; animations and player interaction remain on the UI isolate.

---

## 2. Grid and Pay-Anywhere Wins

The grid contains 6 columns and 5 rows:

~~~text
6 × 5 = 30 symbol positions
~~~

Regular-symbol wins use a **pay-anywhere count mechanic**. Position adjacency is not required. Every occurrence of the same regular symbol across the entire grid is counted:

- fewer than 8: no regular-symbol payout;
- 8–9: 8-symbol payout tier;
- 10–11: 10-symbol payout tier;
- 12 or more: 12+ payout tier.

Some internal model names retain the term ClusterWin, but the current engine does not perform connected/spatial cluster detection.

### Regular-Symbol Payouts

All values are multipliers of the selected base bet.

| Symbol ID | 8–9 | 10–11 | 12+ |
| --- | ---: | ---: | ---: |
| banana | 0.25× | 0.75× | 2× |
| grapes | 0.40× | 0.90× | 4× |
| watermelon | 0.50× | 1× | 5× |
| peach | 0.80× | 1.20× | 8× |
| apple | 1× | 1.50× | 10× |
| strawberry | 1.50× | 2× | 12× |
| pink_bear | 2× | 5× | 15× |
| green_bear | 5× | 10× | 25× |
| heart | 10× | 25× | 50× |

---

## 3. Tumble / Cascade Resolution

The engine resolves a winning grid as follows:

~~~text
1. Count every regular symbol across the grid
2. Find all symbol types with 8+ occurrences
3. Calculate each matching-symbol payout
4. Remove all winning regular symbols
5. Apply gravity
6. Fill empty positions
7. Repeat until no regular-symbol win remains
8. Read multipliers and scatters from the final resolved grid
9. Return the complete SpinResult
~~~

Each TumbleStep stores:

- the winning asset paths;
- the post-refill grid;
- the tumble win amount;
- per-symbol win records with their winning positions.

The engine may use mode and Free Spins profiles when deciding symbol weights and whether to seed another winning count. The shown payout still comes from the symbols that are actually returned.

---

## 4. Scatter Payouts and Free Spins

The cupcake is the scatter symbol. Scatter payout is based on the final resolved grid and is a multiplier of the selected base bet:

| Scatter count | Payout |
| --- | ---: |
| 0–3 | 0× |
| 4 | 3× |
| 5 | 5× |
| 6+ | 100× |

Free Spins awards:

~~~text
Base game:    4+ scatters → 10 Free Spins
Free Spins:   3+ scatters → 5 additional Free Spins
~~~

The engine reports both award types in SpinResult. A base-game trigger is marked as an initial award of 10 Free Spins, while a trigger during an active Free Spins round is marked as a retrigger worth 5 additional spins. The presentation layer reads this distinction to show the correct 10-spin or +5 popup, update the remaining count at the intended time, and pause autoplay until the player acknowledges the award.

### Free Spins Presentation and Autoplay

1. The transition and award popup are shown.
2. Free Spins autoplay remains paused until the player acknowledges the popup.
3. Subsequent Free Spins start automatically after reel, tumble, multiplier, and win presentation guards finish.
4. A retrigger's +5 is reflected when the +5 award popup is shown.
5. After the final presentation, the accumulated round summary is displayed.

The center minus/plus controls are hidden during Free Spins. The spin control is disabled as an input but remains visible and displays the remaining Free Spins count.

---

## 5. Multiplier Collection and Final Payout

Supported multiplier symbols:

~~~text
2×, 3×, 5×, 10×, 25×, 50×, 100×
~~~

Multiplier symbols on the final resolved grid are summed. They are not multiplied by one another. When no multiplier is present, the base win uses a factor of 1.

The exact calculation is:

~~~text
baseWin = sum of every tumble's regular-symbol wins
finalMultiplier = sum of visible final-grid multiplier values
totalWin = baseWin × max(1, finalMultiplier) + scatterPayout
~~~

Scatter payout is added after the regular-symbol multiplication and is not multiplied by the collected multiplier.

The engine's totalWin is the amount credited and the amount stored for interruption recovery. No second random payout replaces the visible symbol result.

---

## 6. Result Generation and Pool Guard

For each spin, the engine:

1. derives the current GameMode from PoolState;
2. adjusts symbol weights for the mode and Free Spins state;
3. evaluates a configured win/Free Spins trigger path;
4. generates and resolves candidate grids;
5. accepts a result only when it fits the applicable payout ceiling;
6. falls back to a safe grid if a valid candidate cannot be produced.

PoolGuard provides:

- mode-specific base-game and Free Spins payout ceilings;
- Free Spins affordability estimates;
- extra safety factors for Ante and Buy Feature diagnostics;
- a post-warmup payout ceiling based on available pool headroom.

The first 50 recorded paid spins are treated as warmup for mode selection and Free Spins affordability. Mode payout ceilings still exist during warmup.

The Buy Feature's paid forced trigger has a dedicated fallback so the purchased bonus access is honored after payment.

---

## 7. RTP and Pool Modes

PoolState persists only three counters:

~~~text
totalBetsPlaced
totalPaidOut
totalSpins
~~~

It derives:

~~~text
poolBalance = totalBetsPlaced - totalPaidOut
expectedPool = totalBetsPlaced × (1 - 0.965)
actualRTP = totalPaidOut / totalBetsPlaced
~~~

The guarded long-run target is 96.5%. The configured mode profiles are:

| Mode | Calibration target | Purpose |
| --- | ---: | --- |
| recovery | 89.0% | Protect the pool after substantial overpayment |
| tight | 92.0% | Reduce payout pressure |
| normal | 96.5% | Default balanced behavior |
| generous | 98.0% | Raise payout potential while underpaying |
| jackpot | 108.0% | Permit short high-payout periods under specific conditions |

These mode targets are calibration references; they are not read as a guaranteed payout percentage for each short session.

### Mode Selection

- Spins 0–49 use normal mode.
- If actual RTP is more than 10 percentage points below target, jackpot mode is selected.
- If actual RTP is more than 10 percentage points above target, recovery mode is selected.
- Otherwise a session mode is selected for 50–250 spins:

| Mode | Session selection weight |
| --- | ---: |
| normal | 65% |
| generous | 17% |
| tight | 13% |
| jackpot | 3% |
| recovery | 2% |

Firestore stores the counters, not the temporary session-mode choice. After a process restart, the next mode is derived again from the restored counters.

Short runs and individual modes may differ materially from 96.5%. The percentage is a long-run guarded calibration target and is not independently certified.

---

## 8. Buy Feature

Buy Feature costs:

~~~text
price = selected base bet × 100
~~~

The live UI checks the player's displayed balance. After payment:

- the paid amount is charged;
- a base-game calculation is sent with forced Free Spins trigger enabled;
- a 4+ scatter result is produced;
- 10 Free Spins begin after the award presentation is acknowledged.

PoolGuard.canAffordBuyFs remains available for diagnostics and stress tests, but it is not the live Buy Feature UI gate.

---

## 9. Ante Bet

Ante Bet changes cost and trigger probability:

~~~text
spin cost = selected base bet × 1.25
base Free Spins trigger probability = configured rate × 2
~~~

An additional calibration scale is applied to Free Spins hit frequency for a round entered through Ante. It does not alter the visible symbol payout table or replace totalWin.

Ante applies only to a base-game entry. If that spin starts a Free Spins round, the round retains its Ante origin flag until it ends.

---

## 10. Auto Spin and Quick Stop

### Normal Auto Spin

Normal Auto Spin tracks:

- requested and remaining spin count;
- 1×–3× presentation speed;
- balance availability;
- active spin/tumble state;
- manual stop;
- completion and continuation guards.

A normal auto-spin count is consumed when its paid spin starts.

### Free Spins Autoplay

Free Spins use a separate presentation controller. It does not consume the normal Auto Spin counter and cannot start while an award acknowledgement or another presentation stage is pending.

### Quick Stop

A tap during reel movement shortens the current visual sequence and presents the already calculated result sooner. It does not change the symbols, payout, multiplier, pool state, or recovery snapshot.

### Virtual CREDIT

The settings flow includes a virtual CREDIT top-up screen. It only increases the Firestore-backed in-game balance and does not process a real-money purchase or create real-world value.

---

## 11. Settlement and Interruption Recovery

In normal presentation, the win reaches the displayed/remote balance when the spin completion sequence settles the result. That timing is intentionally kept after the tumble and multiplier presentation.

For standard normal and active Free Spin paths, an exact recovery snapshot is written after calculation and before presentation completes. If the process is terminated:

- the stored totalWin is used;
- resulting balance, Free Spins, and pool counters are restored;
- history is recorded once using spinId;
- no new engine result is generated for that completed spin.

The paid Buy Feature trigger spin currently follows its dedicated forced-trigger path and is outside the recovery-journal preparation path.

---

## 12. Tests and Calibration

Fast regression coverage includes:

- multiplier collection and payout behavior;
- forced Buy Feature scatter results;
- Free Spins award/autoplay state;
- settlement and exact interrupted-spin recovery;
- controller and widget behavior.

Long-running diagnostics include:

- general and per-mode RTP simulations;
- mode-weight calibration;
- Ante and bought-bonus RTP;
- realistic player mixes;
- tumble distribution;
- whale/clustering stress scenarios.

Run long simulations explicitly when engine weights, payout tables, pool logic, Ante, or Buy Feature changes. They are not intended as a fast smoke suite for presentation-only work.
