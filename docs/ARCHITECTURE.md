# Architecture

EN English | [TR Türkçe](ARCHITECTURE_TR.md)

This document describes Winner Spin's current application structure, runtime flow, persistence boundaries, and performance-oriented services.

---

## 1. Architectural Style

Winner Spin uses a **feature-first layered MVVM architecture with Clean Architecture-inspired boundaries**.

The main goals are:

- keep slot math independent of Flutter widgets and Firebase;
- expose external storage through repository contracts;
- keep screens focused on layout and interaction;
- move state orchestration into a ViewModel and focused controllers;
- isolate animation sequencing from deterministic game results;
- make authentication, recovery, audio, and engine behavior testable.

This is a pragmatic architecture, not a strict dependency-injection framework. The domain layer remains independent, while some presentation composition points select default concrete adapters. GameViewModel and SlotPersistenceController accept injected dependencies for tests but construct local/Firebase implementations when none are supplied.

---

## 2. Repository Structure

~~~text
lib/
  app/
    app.dart
  core/
    audio/
    firebase/
    format/
    network/
    widgets/
  features/
    auth/
      data/repositories/
      domain/
        models/
        repositories/
        services/
      presentation/
        models/
        viewmodels/
        views/
    slot/
      data/repositories/
      domain/
        engine/
        enums/
        models/
        repositories/
        services/
      presentation/
        audio/
        models/
        navigation/
        services/
        ui_controllers/
        viewmodels/
          controllers/
        views/
  firebase_options.dart
  main.dart

test/
  app/
  core/
  firebase/
  features/
  *_test.dart
~~~

### Layer Responsibilities

| Layer | Responsibility |
| --- | --- |
| app | Application root, authentication gate, and global lifecycle observation |
| core | Cross-feature audio, connectivity, formatting, and reusable widgets |
| auth/domain | Authentication contract, auth models, and password-reset policy |
| auth/data | Firebase Authentication, Firestore profile, and callable-function adapter |
| slot/domain | Slot rules, engine, pool model, result models, and persistence contracts |
| slot/data | Firestore pool and local-file repository implementations |
| presentation | Screens, ViewModels, state controllers, animation controllers, and asset/audio services |
| functions | Callable account-deletion backend |

Dependency direction is strongest around the domain layer:

~~~text
Presentation ──> Domain contracts/models <── Data implementations
                         │
                         └── Slot engine
~~~

Data and presentation may depend on Flutter/Firebase packages. Slot domain code does not depend on UI widgets or Firebase implementations.

---

## 3. Application Startup and Global Lifecycle

main.dart performs startup work before rendering the first screen:

1. initializes Flutter bindings;
2. loads the persisted ambient-music preference;
3. configures the shared application audio context;
4. initializes Firebase;
5. activates App Check with Debug/Play Integrity on Android and Debug/App Attest on Apple platforms;
6. enables immersive system UI;
7. starts parsing the multiplier-bomb Lottie asset without blocking runApp;
8. launches WinnerSpinApp.

WinnerSpinApp owns the application-wide lifecycle observer. Any state other than resumed pauses ambient music; returning to resumed requests playback only when music was requested and the persisted preference is enabled. This responsibility is intentionally at the app root so Login, Register, Email Verification, and Game screens behave consistently.

---

## 4. Authentication and Navigation

The root authentication gate resolves one of three destinations:

~~~text
No authenticated user
  └── LoginScreen

Authenticated, email not verified
  └── EmailVerificationScreen

Authenticated, email verified
  └── GameScreen
~~~

### Registration

1. The presentation ViewModel validates user input.
2. Firebase Authentication creates the email/password account.
3. A users/{uid} Firestore profile is created with initial player state.
4. Firebase sends its built-in email verification link.
5. The user remains on EmailVerificationScreen until the verified claim is observed.

The verification screen reloads the Firebase user when the application resumes and enforces a 60-second resend cooldown.

### Sign-In and Profile Operations

- Unverified users are redirected to verification instead of entering the game.
- Profile data is observed from users/{uid}.
- Avatar changes are validated against the symbol registry before being saved.
- Password-reset requests are reserved in Firestore and limited to once every 24 hours.
- Full account deletion reauthenticates the player, archives the retained
  disclaimer evidence to disclaimerAcceptances/{uid}, deletes users/{uid} and
  only then removes the Firebase Authentication user. The order is dictated by
  the security rules: the document may only be deleted by its owner, so the
  auth user has to outlive it. A failure at the last step is surfaced instead
  of rolled back, because recreating the profile would be a `create` and the
  rules only accept a fresh 10,000-coin document there. Retrying completes the
  deletion.

### Disclaimer Archive Retention

For an allowed `disclaimerAcceptances/{uid}` create, Security Rules require
`archivedAt` to equal `request.time`. A client therefore cannot forge, backdate,
or future-date that field. The create-once rule and denied client updates mean
the value cannot be changed after creation; this does not make a broader claim
about when the owner initiates the create request.

Retention is not automated. Authorized administrators perform a manual review
at least once every three months and remove records at the four-years-six-months
early operational cutoff in
[the manual retention runbook](DISCLAIMER_RETENTION_RUNBOOK.md). Missing or
malformed timestamps are reviewed separately and are never assumed eligible.

---

## 5. Game Components and State Management

GameScreen hosts the game screen's UI components and connects them to GameViewModel. GameViewModel coordinates gameplay state and process flows, delegating each responsibility to focused controllers instead of collecting all behavior in one class.

### Responsibility Groups

| Responsibility | Main components |
| --- | --- |
| Player state | BalanceController, PlayerSessionController, AnteController, FreeSpinsController |
| Spin lifecycle | SpinRoundController, SlotSpinStartController, SpinLifecycleController |
| Engine execution | SpinExecutionController, SlotSpinFlowController |
| Result processing | TumbleSequenceController, SpinResultSettlementController, SlotSpinCompletionController |
| Persistence | SlotPersistenceController, SlotSessionHydrationController, SlotSessionLifecycleController |
| Automated play | AutoSpinController, SlotAutoSpinFlowController, FreeSpinAutoPlayController |
| Visual presentation | GridController and UI controllers for wins, overlays, Free Spins, and multipliers |
| Audio and haptics | GameFeedbackController and focused feedback helpers |

Presentation controllers sequence animations and overlays but do not recalculate the engine result. The calculated SpinResult remains the single source of truth.

---

## 6. Spin Execution Flow

The standard normal/Free Spin path is:

~~~text
Player or autoplay requests a spin
  → availability and balance guards
  → bet/Free Spin start state is reserved
  → SpinExecutionController calls compute
  → SlotEngine runs on a temporary background isolate
  → PoolState and SpinResult return to the UI isolate
  → exact recovery snapshot is written
  → reels, tumbles, multipliers, and win presentation run
  → result is settled into balance/history/pool
  → remote state is persisted
  → recovery snapshot is cleared when safe
~~~

The compute boundary moves grid generation and tumble simulation away from the UI isolate. Flutter animation, audio, and widget state stay on the main isolate.

Quick Stop changes presentation timing only. It does not reroll or replace the already calculated result.

---

## 7. Persistence Model

### Firebase

| Location | Stored data |
| --- | --- |
| Firebase Authentication | User identity and verified-email claim |
| users/{uid} | Username, email, avatar, balance, last win, and Free Spins state |
| users/{uid}.pool | totalBetsPlaced, totalPaidOut, and totalSpins |

Pool runtime values such as balance, expected pool, and current mode are derived from the stored counters. Pool counters are normally saved after 10 recorded paid spins and are also flushed by relevant session/lifecycle operations.

### Local Application Files

| Repository/store | Purpose |
| --- | --- |
| LocalGameHistoryRepository | The player's full history per user (written every spin) |
| FirestoreGameHistoryRepository | Newest 10 entries only, as a `gameHistory` array on the user document, written only when the app closes |
| LocalSpinRecoveryRepository | Pending calculated spin snapshot per user |
| LocalFirstLaunchDisclaimerRepository | First-launch disclaimer acknowledgement |
| AmbientMusicPreferenceStore | Ambient-music enabled/disabled preference |

History, spin recovery, and music preference use a temporary file followed by replacement/rename. Repository-side operation queues serialize writes where ordering matters. These are local atomic-write protections; they do not make separate Firestore operations a distributed transaction.

---

## 8. Interrupted-Spin Recovery

For standard normal and Free Spin paths, a recovery snapshot is prepared after compute returns and before the result presentation completes.

The snapshot contains:

- a unique spinId and timestamp;
- the exact calculated win amount;
- the resulting player balance;
- remaining and accumulated Free Spins state;
- a pending +10 initial award or +5 retrigger when applicable;
- Ante/Buy round flags;
- the resulting pool counters;
- the history bet and history identity.

If the operating system terminates the process during presentation, startup loads this snapshot before normal play continues. The application restores the absolute resulting values, persists them, and records history once using spinId. It does not recalculate the symbols or win.

In the normal completion path, the snapshot is finalized after settlement. When a Free Spins award popup is pending, the snapshot remains until the award is acknowledged so the next launch can restore the correct popup and state.

Current scope: the recovery journal protects standard normal spins and active Free Spins. The paid Buy Feature trigger spin follows its dedicated forced-trigger flow and is not currently prepared through the recovery journal.

---

## 9. Free Spins Presentation Flow

Free Spins use engine state and a separate presentation sequence:

1. a base result awards 10 spins or an active round retriggers 5;
2. the award transition and popup are presented;
3. autoplay remains paused until the user acknowledges the popup;
4. subsequent spins start automatically after all current presentation guards clear;
5. a retrigger becomes visible when its +5 popup is shown;
6. the summary is shown after the final spin presentation completes.

The disabled spin control remains a display surface for the remaining count during this mode; Free Spins do not depend on manual spin-button input.

---

## 10. Audio Architecture

### Ambient Music

AmbientMusicService is an application-scope singleton with serialized synchronization:

- playback requests, lifecycle changes, preference changes, and recovery requests are coalesced;
- only one ambient player is maintained;
- background states pause playback;
- resumed playback respects the saved preference;
- failures are log-throttled and use one delayed recovery path;
- a replacement player is created only when recovery requires it.

### Sound Effects

Short effects use BoundedAudioPool:

- low-latency playback mode where appropriate;
- explicit maximum concurrent playback;
- timed stop/release;
- bounded idle players;
- preload support;
- safe disposal and throttled debug logging.

UI click and multiplier-bomb effects are preloaded during startup/game initialization. This avoids repeatedly constructing unbounded media players during long sessions.

---

## 11. Image and Animation Lifecycle

The asset pipeline avoids decoding every source image at full size immediately:

- normal and Free Spins backgrounds decode to the device's physical width without exceeding source width;
- opening-grid symbols are precached first;
- remaining symbols are loaded in batches of three after a delay;
- symbol images use a 256-pixel decode width;
- multiplier labels use a 384-pixel decode width;
- critical popup and multiplier assets are loaded early;
- the Free Spins summary image is loaded for the relevant flow and explicitly evicted afterward;
- the Free Spins background is prepared during game startup;
- expensive playfield regions are isolated with repaint boundaries where appropriate.

The bomb Lottie composition is parsed early, while its visual sequencing and pooled sound playback remain presentation concerns.

---

## 12. Testing Strategy

The repository currently contains 45 Dart test files and a Firestore Security Rules emulator suite covering:

- authentication ViewModels and verification UI;
- password-reset limits;
- application audio lifecycle and persisted preference;
- bounded audio pools;
- image-provider decode decisions;
- slot controllers and Free Spins presentation;
- exact interrupted-spin recovery and settlement;
- Firestore account isolation, initial-profile integrity, and server-owned collections;
- disclaimer archive create-once and server-timestamp Security Rules;
- symbol registry and multiplier assets;
- RTP, mode calibration, Ante, Buy Feature, tumble distribution, and stress simulations.

Run focused unit/widget tests for normal development. Run `npm run test:firestore` when Firestore rules, authentication persistence, or Firebase data paths change. Root-level math simulations can execute millions of spins and should be selected explicitly when engine weights, payout rules, pool logic, Ante, or Buy Feature behavior changes.

---

## 13. Known Architectural Boundaries

- The application is mobile-focused because local persistence directly uses dart:io.
- Some concrete repositories are selected in presentation composition points; the project is not a strict pure-Clean-Architecture implementation.
- Firestore player, pool, and local recovery writes are coordinated but are not one distributed atomic transaction.
- Mode calibration targets are simulation references, not runtime guarantees for a short session.
