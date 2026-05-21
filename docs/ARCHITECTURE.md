# Architecture

EN English | [TR Türkçe](ARCHITECTURE_TR.md)

This document describes the architecture, application flow, and technical design decisions used in Winner Spin.

---

## Overview

Winner Spin follows a **Feature-First Layered MVVM architecture with Clean Architecture boundaries**.

The project is organized around features instead of placing every file into only global technical folders. This makes the authentication flow, slot game logic, presentation layer, and persistence logic easier to understand, maintain, test, and extend.

---

## Project Structure

```text
lib/
  app/
    app.dart

  core/
    audio/
    format/
    widgets/

  features/
    auth/
      data/
        repositories/
      domain/
        repositories/
      presentation/
        viewmodels/
        views/

    slot/
      data/
        repositories/
      domain/
        engine/
        enums/
        models/
        repositories/
      presentation/
        audio/
        models/
        navigation/
        services/
        ui_controllers/
        viewmodels/
        views/

  images/
    login_screen/
    register_screen/
    slot_main_screen/

  main.dart
```

---

## Layer Responsibilities

The architecture follows these principles:

- `domain/` contains the slot math, game rules, models, enums, and repository contracts.
- `data/` contains concrete persistence implementations such as Firestore-backed and local repositories.
- `presentation/` contains screens, widgets, ViewModels, UI controllers, audio helpers, navigation helpers, and presentation services.
- The domain layer does not depend on Flutter UI or Firebase implementation details.
- Presentation depends on domain contracts instead of directly owning backend implementation logic.
- Game logic and animated UI behavior are separated as much as possible.

This structure helps keep the game engine testable while allowing the presentation layer to evolve independently.

---

## Application Flow

The app starts by initializing Flutter and Firebase, then launches the root application widget.

The root app checks the current authentication state:

```text
User signed in      -> GameScreen
User not signed in  -> LoginScreen
```

This creates a real application flow instead of opening the slot screen directly.

---

## Authentication

Winner Spin includes Firebase Authentication based login and registration.

The authentication layer uses an abstract `AuthRepository` contract. This keeps authentication behavior separated from the UI and allows the Firebase implementation to stay inside the data layer.

Supported authentication behavior includes:

- User registration
- User login
- User logout
- Current user id access
- User data fetching
- User data watching
- Player state saving
- Firebase auth error mapping

When a new user is created, Firestore stores initial player data such as:

```text
uid
username
email
createdAt
balance
userBalance
freeSpinsRemaining
```

This gives the project a real backend-connected player profile flow instead of making the game a local-only demo.

---

## GameViewModel

`GameViewModel` acts as the main state orchestration layer for the slot screen.

It coordinates smaller controllers responsible for:

- balance state,
- bet changes,
- ante bet state,
- free spin state,
- auto spin state,
- player session,
- pool state,
- persistence,
- game feedback,
- spin lifecycle,
- tumble sequencing,
- result settlement.

This structure keeps the ViewModel focused on coordination instead of placing every gameplay and UI detail into a single large class.

---

## Presentation Layer

The presentation layer includes more than a basic slot grid.

It manages:

- main game screen,
- animated reels,
- bottom control panel,
- bet controls,
- balance display,
- Free Spins overlay,
- Free Spins award sequence,
- Big Win / Super Win overlay,
- flying win text,
- scatter pulse effects,
- multiplier visuals,
- Buy Feature screen,
- Auto Play settings,
- Game Rules screen,
- Game History screen,
- System Settings screen,
- audio and vibration controls.

The UI is separated into screens, widgets, UI controllers, models, services, audio helpers, and navigation helpers so that the main game screen does not own every detail directly.

---

## Firebase & Persistence

The project uses Cloud Firestore for backend-backed player and pool persistence, while lightweight client-only records are handled locally where that keeps the flow simpler.

Firestore is used for:

- player profile data,
- player balance,
- free spins remaining,
- pool state.

Game history is stored through a local file-backed repository, allowing recent play records to remain available to the UI without introducing an additional Firestore collection.

Player state can be saved without forcing the UI to directly communicate with Firebase implementation details.

---

## Assets

The project uses both `assets/` and `lib/images/` for visual and audio resources.

```text
assets/
  audio/
  audio/Items/
  animations/

lib/images/
  login_screen/
  register_screen/
  slot_main_screen/
```

These assets are used for login/register visuals, slot screen symbols, win presentation assets, audio feedback, and Lottie animations.
