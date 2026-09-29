# Architecture

A map of the code for people who want to change it. For *what the training engine decides and why*, read [ENGINE.md](ENGINE.md).

## The one idea

The app is split in two halves that only talk through plain data types:

```
Momentum/
  Models/    data types + the exercise library + localization        ┐ pure Swift, no UI,
  Engine/    every training decision (plan, progress, adapt, swap)    ┘ builds on Linux (SwiftPM)
  Store/     AppStore (state + one JSON file), launch modes, reminders   ┐
  Health/    Apple Health                                                │ needs Apple frameworks
  Design/    theme, components, the figure animation renderer            │ (built on macOS only)
  Views/     SwiftUI screens                                             ┘
```

`Package.swift` builds only `Models` and `Engine` (plus the generated animation data), so all logic can be tested with `swift test` anywhere, without Xcode. The Xcode project is generated from `project.yml` by XcodeGen and contains everything.

## Data flow

```
UserProfile ──┐
sessions[]  ──┼─► PlanGenerator ─► Workout ─► WorkoutDetailView ─► ActiveWorkoutView
weights[]   ──┘        ▲                                                   │ finishes
                       │                                                   ▼
                AdaptiveEngine.apply ◄──────────────── WorkoutSession (what was really done)
                (level, rungs, deloads, comeback)
```

- **`AppStore`** is the single source of truth (`@MainActor ObservableObject`). It owns `profile`, `sessions` and `weights`, saves them to one JSON file in Documents after every change, and exposes plan and statistics helpers to the views. There is no database and no network.
- **`PlanGenerator`** is a pure function of `(profile, history, date)`. Given the same inputs it always returns the same workout, which is what makes it testable and explainable.
- **`AdaptiveEngine.apply`** takes a finished session and returns an updated profile (level, rungs, difficulty offset, block restarts) plus messages to show.
- **`Alternatives.suggest`** powers the swap sheet.
- **`Reminders.plan`** decides which local notifications to schedule; `ReminderScheduler` puts them on the system.
- **`Backup`** exports and restores everything as a versioned JSON file, and exports CSV.

## Localization

English text is the key: `L("Up {0} kg", 2)`. Tables live in `tools/i18n/*.py` and are compiled into Swift by `tools/i18n/export.py`. The active language is `Loc.language`, set by `AppStore` from the profile or the phone. See the README's *Translations* section.

## Exercises

`ExerciseLibrary` (what an exercise is), `ExerciseMetaTable` (movement pattern, joint stress, ladder rung), `MotionData` (generated animation keyframes from `tools/`), `ExerciseTranslations` (generated). `swift test` checks these agree.

## Testing

| Layer | How |
|---|---|
| Engine, models, backup, reminders, localization | `swift test` (170+ tests, Linux or macOS) |
| Whole plans over time | `swift run EngineSim sim` |
| SwiftUI compiles, unit tests in the app target | CI: `ios.yml` |
| Screens in all three languages, launch smoke test | CI: `screenshots.yml` (UI tests with demo data; PNGs land on the `ci-screenshots` branch) |
| Translations complete | CI: `core.yml` `translations` job |

Launch arguments for tests and demos are in `Store/LaunchMode.swift`; `Engine/DemoData.swift` builds six weeks of realistic history using the engine itself.

## Adding things

- **A screen:** a SwiftUI view in `Views/`, wrap text in `L()`, add its strings to a `tools/i18n/strings_*.py` file, run `python3 tools/i18n/export.py --strict`.
- **Stored data:** add a field to `UserProfile` (tolerant `init(from:)` keeps old saves loading) or a new type in `PersonalData`, and cover the backup round trip in `BackupTests`.
- **An engine rule:** change `Engine/`, describe it in `ENGINE.md`, add a test, run `EngineSim sim`.
