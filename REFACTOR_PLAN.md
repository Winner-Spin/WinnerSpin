# WinnerSpin — Architectural Refactor Plan

> **Goal:** Migrate the existing flat `lib/` structure to **feature-first layered
> MVVM with Clean Architecture boundaries** — pure domain (incl. math engine),
> abstract repository contracts, concrete data implementations, and presentation.
> One responsibility per file. The math engine is feature-frozen (4 modes
> calibrated to ~96.5% RTP) and serves as a regression detector during migration.

---

## 📐 Architectural Style — Honest Naming

Earlier draft of this plan called the target "Clean Architecture" but didn't
fully follow that pattern. Per code review feedback, the target is more
accurately:

> **Feature-First Layered MVVM with Clean Architecture boundaries**

What we **DO** adopt from Clean Architecture:
- **Pure domain** — `domain/` has zero Flutter / Firebase imports.
- **Repository abstractions** — `domain/repositories/` defines interfaces;
  `data/repositories/` implements them. Presentation depends on the interface.
- **Dependency direction enforced** — `presentation → domain ← data`.

What we **DO NOT** adopt (deliberately, to avoid over-engineering for project size):
- **Use cases / interactors** — A slot-game ViewModel orchestrating an engine
  is not complex enough to warrant per-action interactor classes. ViewModels
  call repositories + engine directly.
- **Data mappers / DTOs** — Firestore documents map 1:1 to domain models for
  this project. Adding a separate DTO layer + mappers would be churn without
  payoff. Re-evaluate if a second backend is ever introduced.

If the project later needs swappable backends, async use cases, or complex
business rules, the repository boundary is the right place to graft those on.

---

## 📊 Current State — Why Refactor

| File | Lines | Problem |
| --- | --- | --- |
| `lib/services/slot_engine.dart` | **1,036** | God object: math constants, ante/buy overrides, grid generation, tumble simulation, multiplier collection, pool guard, forced chains — all in one file |
| `lib/views/game_screen.dart` | **791** | God component: layout + balance UI + bet controls + ante toggle + buy button + spin button + reels + settings — single widget tree |
| `lib/viewmodels/game_viewmodel.dart` | **425** | Mixed concerns: user data + grid state + balance + bet + ante + FS + auth flow + pool persistence |
| `lib/widgets/slot_reel.dart` | **399** | Two unrelated classes (`SlotReel` column + `_TumbleCell`) in one file |
| `lib/models/slot_symbol.dart` | **243** | Contains `GameMode` enum (engine concern, not symbol model) |

### Symptoms
- Hard to find "where is X handled" — changes ripple through god classes.
- New feature work (e.g., buy bonus) couples to too many concerns at once.
- Onboarding a new dev requires reading 1,036 lines to understand the engine.
- Test isolation is non-obvious — what code path is being verified?
- Verbose calibration-history comments survived past their useful life
  (e.g., `_anteFsMultiplierScale` ships a multi-line "calibration journey"
  log that belonged in the WSPIN-128 commit message, not in the source).

---

## 🎯 Target Architecture

```
lib/
├── main.dart
├── firebase_options.dart
│
├── app/                                  # Root app config
│   ├── app.dart                          # MaterialApp + theme + routes
│   └── routes.dart                       # Centralized route table
│
├── core/                                 # Shared infrastructure
│   ├── constants/
│   │   └── slot_dimensions.dart          # 6×5 grid, FS award counts
│   └── utils/
│       ├── weighted_random.dart          # Generic weighted-pick helper
│       └── grid_utils.dart               # deepCopy, gravity, fillEmpty
│
└── features/
    ├── auth/                             # Auth feature module
    │   ├── domain/
    │   │   ├── models/                   # Pure user / session models
    │   │   └── repositories/
    │   │       └── auth_repository.dart  # ABSTRACT contract
    │   ├── data/
    │   │   ├── services/
    │   │   │   └── firebase_auth_service.dart   # Firebase wrapper
    │   │   └── repositories/
    │   │       └── firebase_auth_repository.dart # IMPLEMENTS contract
    │   └── presentation/
    │       ├── viewmodels/
    │       │   ├── login_viewmodel.dart
    │       │   └── register_viewmodel.dart
    │       └── views/
    │           ├── login_screen.dart
    │           └── register_screen.dart
    │
    └── slot/                             # Slot game feature module
        ├── domain/                       # Pure Dart — no Flutter / Firebase
        │   ├── enums/
        │   │   ├── game_mode.dart
        │   │   └── symbol_tier.dart
        │   ├── models/
        │   │   ├── slot_symbol.dart
        │   │   ├── symbol_registry.dart
        │   │   ├── pool_state.dart
        │   │   ├── tumble_step.dart
        │   │   └── spin_result.dart
        │   ├── engine/
        │   │   ├── slot_engine.dart           # Public orchestrator API
        │   │   ├── rtp_config.dart            # All RTP calibration constants
        │   │   ├── ante_config.dart           # Ante override params
        │   │   ├── buy_config.dart            # Buy bonus override params
        │   │   ├── grid_generator.dart
        │   │   ├── tumble_simulator.dart
        │   │   ├── multiplier_collector.dart
        │   │   ├── pool_guard.dart
        │   │   └── chain_forcer.dart
        │   └── repositories/
        │       └── pool_repository.dart       # ABSTRACT contract
        ├── data/
        │   ├── services/
        │   │   └── firestore_pool_service.dart    # Firestore wrapper
        │   └── repositories/
        │       └── firestore_pool_repository.dart # IMPLEMENTS contract
        └── presentation/
            ├── viewmodels/
            │   ├── game_viewmodel.dart       # Top-level orchestrator
            │   ├── balance_controller.dart   # Balance + bet state
            │   ├── ante_controller.dart      # Ante toggle + ante-FS state
            │   └── free_spins_controller.dart # FS counter + buy state
            └── views/
                ├── game_screen.dart          # Main layout (composition only)
                └── widgets/
                    ├── slot_reel.dart        # Column animation
                    ├── tumble_cell.dart      # Single cell (own file)
                    ├── spin_button.dart
                    ├── balance_display.dart
                    ├── bet_controls.dart
                    ├── ante_toggle.dart
                    └── buy_fs_button.dart
```

### Dependency Direction (Enforced)

```
   presentation/  ─────►  domain/  ◄─────  data/
   (ViewModels,           (Engine,         (Firestore,
    Views)                 Repos:abstract)  Repos:impl)
```

- `domain/` has **no imports** from `presentation/` or `data/`.
- `data/` imports `domain/` (to implement contracts).
- `presentation/` imports `domain/` (to call engine + repository contracts).
- `presentation/` does **not** import `data/` directly — concrete repository
  is wired at app startup via simple constructor injection.

### Design Principles

1. **Feature-first, not layer-first.** Auth and slot are independent feature
   modules; each carries its own domain/data/presentation slice.
2. **One responsibility per file.** Open a file expecting one concern.
3. **Domain is pure.** No Flutter or Firebase imports under `domain/`.
4. **ViewModels orchestrate, don't compute.** Math stays in `domain/engine/`.
5. **Widgets are composition.** `game_screen.dart` becomes a thin layout.
6. **Comments earn their place.** See "Comment Hygiene" below.

---

## ✂️ Comment Hygiene — Standards for the Refactor

The math engine ships with calibration-history comments that helped during
tuning but no longer earn their keep. **Strip these as part of the refactor.**

### Remove
- **Calibration journey logs** ("0.75 → 93.80% RTP, 0.85 → 99.73%, …").
  Belongs in commit messages and PR descriptions, not source code.
- **What-the-code-does narration** ("This function does X then Y then Z" when
  the function body is 5 lines).
- **Section headers** that decorate but don't add information
  (`// ─── INITIALIZATION ───` followed by a single line of init).
- **Multi-line philosophical asides** ("Sweet Bonanza inspired this approach
  because of …"). Tie those to commit messages instead.

### Keep
- **Why this value, not what it is.** A single-line "why we chose 0.80" beats
  a 6-line journey log.
- **Non-obvious invariants.** "MUST stay > 1.0 or scatter math breaks."
- **Hidden-coupling notes.** "Mirrored in `_anteFsConfig`; update both."
- **Public API doc-comments** (`///` on exported classes/methods) — keep
  but tighten to one or two lines.

### Style Standard

```dart
// ✗ TOO VERBOSE — was useful during tuning, no longer earns its place
/// Scaling factor applied to the COLLECTED MULTIPLIER SUM during FS spins
/// of an ante-triggered round. Calibration journey:
///   1.00 → 100.00% RTP (no scaling, baseline 2× ante)
///   0.85 →  99.73% RTP (FS rounds avg 82.8x — barely affected)
///   0.80 →  ~96.5% target (interpolated midpoint, FS rounds avg ~78x)
///   0.75 →  93.80% RTP (over-corrected, FS rounds avg 73x)
/// Player still sees the advertised 2× FS chance and identical visuals —
/// only the statistical multiplier sum shifts across many rounds.
static const double _anteFsMultiplierScale = 0.80;

// ✓ CONCISE — same information density, none of the bloat
/// Offsets the 2× ante trigger rate so ante RTP holds at ~96.5%.
/// Player sees identical visuals; only the statistical multiplier sum drops.
static const double _anteFsMultiplierScale = 0.80;
```

Comment cleanup is an explicit deliverable of every phase that touches a file.

---

## 🛡️ Math Engine Safety Strategy

The math engine is **feature-frozen**. Refactor must NOT change any constant
or branching condition — only file location and comment density.

### Verification After Every Phase

```bash
flutter test test/rtp_simulation_test.dart        # Farm RTP
flutter test test/ante_bet_rtp_test.dart          # Ante RTP
flutter test test/buy_bonus_rtp_test.dart         # Buy RTP
flutter test test/mixed_farm_ante_rtp_test.dart   # Mixed scenarios
flutter test test/realistic_player_rtp_test.dart  # 500K cycles realistic
flutter test test/whale_clustering_stress_test.dart # Whale stress
flutter analyze lib/                               # Lint / type clean
```

### Pass Criteria (Per Phase)

- All RTP tests within ±1.0% of 96.5% target.
- Mode distribution within ±2.0% of (65 / 17 / 13 / 3 / 2).
- `flutter analyze` returns "No issues found".
- All existing tests still compile and pass.

If any test breaks, **revert that phase's commit** and investigate.

---

## 📋 Phase Plan — One Commit Per Phase (Granular)

Per project preference, every phase ends with a commit so revert is trivial
and progress is visible. If a phase is large, it MAY be split further into
sub-commits — each sub-commit must independently pass the test suite.

| # | Phase | Scope | Commits |
| --- | --- | --- | --- |
| **0** | **Comment hygiene baseline** | Strip calibration journeys + redundant comments from `slot_engine.dart`, `pool_state.dart`, `slot_symbol.dart`. No structural changes. | 1 |
| **1** | **Domain enums + models split** | One file per type: `game_mode`, `symbol_tier`, `slot_symbol`, `symbol_registry`, `tumble_step`, `spin_result`, `pool_state`. Re-export from old paths during transition. | 1–2 |
| **2** | **Engine decomposition** | Break `slot_engine.dart` into `rtp_config`, `ante_config`, `buy_config`, `grid_generator`, `tumble_simulator`, `multiplier_collector`, `pool_guard`, `chain_forcer`. `slot_engine.dart` becomes a thin orchestrator. | 2–3 |
| **3** | **Repository abstractions** | Define `auth_repository` and `pool_repository` interfaces in `domain/`. Move existing services under `data/services/` and add concrete `data/repositories/` implementations. Wire via constructor injection. | 1–2 |
| **4** | **ViewModel decomposition** | Split `GameViewModel` into `balance_controller`, `ante_controller`, `free_spins_controller`. Top-level VM composes them. | 1–2 |
| **5** | **View widget extraction** | Pull `spin_button`, `balance_display`, `bet_controls`, `ante_toggle`, `buy_fs_button` out of `game_screen.dart`. Move `_TumbleCell` to its own file. | 1–2 |
| **6** | **Folder migration** | Move everything under `app/`, `core/`, `features/auth/`, `features/slot/`. Update all import paths. | 1 |
| **7** | **Final verification** | Run all RTP tests, `flutter analyze`, manual smoke on emulator. Sign-off. | 1 |

### Estimated Effort

- Phase 0: ~30 min (mechanical comment strip)
- Phase 1: ~30 min
- Phase 2: ~2 hours (largest)
- Phase 3: ~1 hour
- Phase 4: ~1.5 hours
- Phase 5: ~1 hour
- Phase 6: ~30 min (path updates)
- Phase 7: ~30 min

**Total:** ~7.5 hours of focused work, spread over 8–14 commits.

---

## 🌿 Branch Strategy

```bash
git checkout -b refactor/clean-mvvm
# ... do all phases on this branch ...
# Each phase ends with at least one commit — push regularly
git push -u origin refactor/clean-mvvm
# When done:
gh pr create --base main --head refactor/clean-mvvm
```

**Why a feature branch:**
- `main` stays production-ready throughout.
- Easy to abandon or pause if priorities shift.
- One PR for end-to-end review of the architectural change.

---

## 📦 Commit Naming Convention

```
WSPIN-131 chore(engine): comment hygiene — strip calibration journeys
WSPIN-132 refactor(slot): split domain enums + models into individual files
WSPIN-133 refactor(engine): extract RTP / ante / buy configs into own files
WSPIN-134 refactor(engine): split grid_generator + tumble_simulator from engine
WSPIN-135 refactor(engine): extract multiplier_collector + pool_guard + chain_forcer
WSPIN-136 refactor(slot): introduce abstract repositories + concrete impls
WSPIN-137 refactor(viewmodel): split GameViewModel into focused controllers
WSPIN-138 refactor(views): extract widgets from game_screen + split tumble_cell
WSPIN-139 refactor(arch): migrate to feature-first folder structure
WSPIN-140 chore(refactor): final verification + import-path cleanup
```

Numbers are illustrative — adjust to actual ticket IDs as you go. Each commit
must independently leave the test suite passing.

---

## ✅ Definition of Done

- [ ] No file in `lib/` exceeds ~250 lines (target: ~150 average).
- [ ] Each file has one clear responsibility (file name = job description).
- [ ] All RTP tests pass with deviations < ±1.0%.
- [ ] `flutter analyze lib/` is clean.
- [ ] No engine constant or branching condition changed (math frozen).
- [ ] No calibration-journey or what-the-code-does comments remain.
- [ ] `domain/` directory has zero Flutter / Firebase imports.
- [ ] Repositories: contracts in `domain/`, impls in `data/`, wiring via DI.
- [ ] Manual smoke test on emulator: spin, ante toggle, buy bonus, FS round.
- [ ] Final folder tree matches the target architecture above.

---

## 🚦 Out of Scope (For This Refactor)

These are valuable but separate workstreams — do NOT mix into this refactor:

- UI/UX polish (animations, big-win celebrations, sound, haptic feedback)
- New features (settings menu, history view, leaderboard)
- Production hardening (i18n, accessibility, anti-fraud, analytics)
- Performance optimization (texture atlases, frame pacing)
- Test coverage expansion beyond RTP suite
- Use cases / interactor layer (see "Architectural Style" — out of scope by
  design; revisit if business rules grow)
