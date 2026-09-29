# Momentum

A free, fully offline iOS fitness app. No account, no ads, no subscription, no server. Everything (plans, history, weights) is stored on the device.

Built with SwiftUI and Swift Charts. Requires iOS 17+.

## What it does

- **Personal plan from day one.** Onboarding asks for level (beginner / intermediate / advanced), goal (build muscle / lose fat / stay fit), days per week, session length, equipment (none / dumbbells / full gym) and body stats.
- **Daily programs.** A weekly schedule is generated from those answers: full body, upper/lower, or push/pull/legs depending on days per week. Exercises rotate every week so it doesn't go stale.
- **Adaptive.**
  - After each workout you rate it *too easy / just right / too hard*. That moves an intensity dial that changes sets, reps, hold times and rest.
  - Push the dial far enough and your level changes automatically (up or down).
  - Finishing less than 60% of a session counts as "too hard" whatever you tapped.
  - Come back after 10+ days off and the next sessions are eased down.
- **Your weights matter.** Starting weights are estimated from body weight, level and exercise. After that they follow your logs: hit every rep and it goes up, fall well short and it drops, otherwise it holds. Metric or imperial.
- **Progress.** Weekly calories and minutes against what your plan asked for, daily-minutes chart, body-weight trend, personal records, workout streak.
- **Workout player.** Per-set reps/weight steppers, timed holds, rest timer, screen stays awake, swap any exercise for an alternative.
- **Animated demonstrations.** Every one of the 74 exercises has a looping figure animation showing the actual movement, with props (bench, chair, bar, dumbbells, barbell, cables). They play in the workout player, the workout list and the exercise sheet. Drawn in code from bundled data, so they work offline; they respect *Reduce Motion*.
- **Explore.** Searchable library of 74 exercises with animation and step-by-step instructions.
- **Quick workouts.** 10-minute blast, wall/no-equipment full body, mobility & stretch.

The UI follows the three reference screens: Workouts home (streak, stats, workout cards), Workout detail (dark hero, exercise list with swap, *Start Workout*), and Progress (date strip, Calorie and Duration cards).

## Run it

You need a Mac with Xcode 15.3+ (this project was written for Xcode 16).

```sh
brew install xcodegen
xcodegen generate      # creates Momentum.xcodeproj from project.yml
open Momentum.xcodeproj
```

Pick an iPhone simulator (or your device) and press Run. To install on your own iPhone for free, select your Apple ID under *Signing & Capabilities → Team* (a free Apple ID works; the app just needs re-installing every 7 days).

Run the tests with `⌘U`, or:

```sh
xcodebuild test -project Momentum.xcodeproj -scheme Momentum \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

A GitHub Actions workflow (`.github/workflows/ios.yml`) builds and runs the tests on every push.

## Project layout

```
Momentum/
  App/          App entry point, root + tab view
  Models/       Data types and the built-in exercise library
  Engine/       PlanGenerator (weekly plan), AdaptiveEngine (difficulty), WeightAdvisor (progressive overload)
  Store/        AppStore: state + JSON persistence in Documents/
  Design/       Theme, shared components, FigureView (animation renderer) and MotionData (generated)
  Views/        Onboarding, Workouts, Progress, Explore, Settings
MomentumTests/  Unit tests for the engine
tools/          Python authoring + preview tools for the exercise animations
project.yml     XcodeGen project definition
```

`Engine/` and `Models/` have no UI dependencies, so the training logic is easy to test and tweak.

## Tweaking the training logic

- Add or edit exercises in `Models/ExerciseLibrary.swift`. `loadRatio` is a typical working weight as a fraction of body weight (per hand for dumbbells).
- Change splits and muscle order in `DayFocus` (`Engine/PlanGenerator.swift`).
- Change how fast the app adapts in `AdaptiveEngine.evaluate`.

## Known limitations

- Exercise demos are stylised stick-figure animations, not video. Workout cards use gradients. See `tools/README.md` to edit or add animations.
- Calories are estimates from MET values, not measured.
- No Apple Health / Watch integration yet (steps from the reference design were replaced by completed sets, since they need HealthKit).
- Data lives only on the device. Deleting the app deletes your history.
