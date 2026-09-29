# Changelog

All notable changes. The project is young: until 1.0 is tagged, this lists what has landed on `main`.

## Unreleased

### Added
- Adaptive training engine (placement, movement patterns, weekly volume per muscle, double progression, bodyweight ladders, blocks and deloads, comebacks, readiness, "why" explanations). Specified in `docs/ENGINE.md`.
- Onboarding, exercise swaps by reason ("too hard", "it hurts", "no equipment"…), Apple Health sync, animated exercise demonstrations, YouTube form links.
- English, Spanish and Portuguese (Brazil), including exercise names and instructions.
- History of every workout, per-exercise progress chart, week-in-review card.
- Backup and restore (JSON) and CSV export.
- Optional training-day reminders (local notifications).
- Pull-up bar option: pull-ups are only planned for people who have a bar.
- Text follows the iOS text-size setting.
- CI: Linux engine tests, translation completeness check, iOS build and tests, screenshots of the real app in three languages.

### Fixed (found by fuzzing the engine)
- Regular trainers were treated as returning from a break whenever an exercise rotated back in.
- A deload week could be heavier than the last logged lift; light barbell loads were inflated to the minimum.
- Exercise rotation and deload weeks were on different schedules.
- Above-level lifts could be suggested to beginners; sessions dated in the future were counted as recent.
