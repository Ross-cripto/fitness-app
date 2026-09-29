# Roadmap

What Momentum needs next, in priority order. Everything here keeps the [ground rules](../CONTRIBUTING.md): offline, private, explainable, safe, three languages.

Status: ✅ done · 🚧 in progress · ⬜ not started · 💬 needs a decision

## 1. Be a good open-source project

| | Item | Why |
|---|---|---|
| ✅ | Contributing guide, code of conduct, privacy statement, issue and PR templates | People need to know how to help and what the app promises |
| 💬 | **Choose a license** | Without one the code is "source available", not open source. The maintainer must pick (MIT/Apache-2.0 for maximum reuse, GPL-3.0/AGPL to keep forks open) |
| ✅ | Architecture overview (`docs/ARCHITECTURE.md`) | Where things live and how data flows, for new contributors |
| 🚧 | Screenshots from the real app in CI instead of mockups | Shows what the app looks like, and catches layout regressions in three languages |

## 2. Own your data

| | Item | Why |
|---|---|---|
| ✅ | Backup and restore (one JSON file) and CSV export of workout history | An app that keeps everything on the device must let people move it, back it up, and leave |
| ⬜ | Automatic local backup before schema changes | Never lose a history to an update |

## 3. See your training

| | Item | Why |
|---|---|---|
| ✅ | History screen: every past workout, its sets, delete | Today only the selected day is visible |
| ✅ | Per-exercise chart (estimated 1RM / reps over time) | The evidence that the plan works |
| ✅ | Weekly review card: what was planned vs done, what the engine will change next week | Makes the adaptation visible and trustworthy |

## 4. Stay consistent

| | Item | Why |
|---|---|---|
| ✅ | Training-day reminders (local notifications, no server) | The biggest driver of consistency; must be opt-in and quiet |
| ⬜ | Rest timer that survives the app being backgrounded (local notification + haptic) | Currently ticks only while the app is open |
| ⬜ | Home-screen widget: next workout and streak | |

## 5. Better training

| | Item | Why |
|---|---|---|
| 🚧 | Property-based tests in CI ✅ (`InvariantTests`: random people over 12 simulated weeks; safety, load caps, determinism, adaptation limits, swap rules). Next: cover comeback/deload rules and multi-language output | A one-off fuzz run found eight real bugs; this keeps them fixed. Run more with `INVARIANT_SEED=… INVARIANT_CASES=300 swift test --filter InvariantTests` |
| ⬜ | Review `ENGINE.md` against sports-science sources, with citations | The rules should be defensible, not just plausible |
| ⬜ | Balance session lengths across the week (a beginner's plan showed ~14, ~23 and ~32 minutes on three days) | Even days feel fairer and match the time the person set |
| ⬜ | Exercise library as data files (JSON) instead of Swift | Lets non-programmers add exercises and translations by pull request |
| ⬜ | More exercises (target ~150): kettlebell, bands, TRX, cardio machines | Equipment beyond bodyweight/dumbbells/gym |
| 🚧 | Equipment profiles: pull-up bar ✅; bands, kettlebells, bench, "hotel gym" ⬜ | Precise plans for real home setups |
| ⬜ | Custom exercises and your own notes per exercise | Everyone has a movement the library lacks |
| ⬜ | Conditions and life stages presets (older adults, returning after injury, postpartum) written with professional review | Needs expert input, not just code |
| ⬜ | Program templates (5×5, upper/lower, push/pull/legs) as alternatives to the automatic split | Some people want a known program |
| ⬜ | Running/walking intervals and simple cardio plans | Fitness is more than lifting |

## 6. Reach

| | Item | Why |
|---|---|---|
| 🚧 | Accessibility pass: Dynamic Type ✅ (up to AX2, screenshot-tested); VoiceOver walkthrough of the workout player ⬜; contrast audit ⬜ | The app is for everyone |
| ⬜ | More languages (French, German, Italian, Chinese, Hindi...) | The translation tooling is ready; needs native speakers |
| ⬜ | Native-speaker review of Spanish and Portuguese | Current text is AI-written |
| ⬜ | Apple Watch companion (log sets from the wrist) | |
| ⬜ | Android or a shared engine (the engine is pure Swift and could be ported or wrapped) | Most of the world uses Android; a real decision, not a quick task |

## How this list is used

The maintainers (and the assistant that started the project) work through it top to bottom, one small verified step at a time: implement, test, push, read CI, then pick the next item and re-order the list if something new matters more. Opinions welcome: open an issue.
