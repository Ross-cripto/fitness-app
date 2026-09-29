# Contributing to Momentum

Momentum is a free, offline, no-account fitness app. Anyone can read, run, and improve it. This page is the short way in.

## Ground rules for the product

These are what make the app what it is. Changes that break them will not be merged:

1. **Offline and private.** No accounts, no analytics, no ads, no network calls for the app to work. Data stays on the device (Apple Health is opt-in and stays on the device too).
2. **Explainable.** Every decision the engine makes must be a rule that can be written down in [docs/ENGINE.md](docs/ENGINE.md) and shown to the user in one sentence. No black boxes.
3. **Safe by default.** Body areas a person marks as problems are never loaded. Not medical advice; never make medical claims.
4. **Three languages stay complete.** English, Spanish and Portuguese ship together (see *Translations*).

## Set up

```sh
swift test                 # engine + models, works on Linux and macOS, no Xcode needed
brew install xcodegen && xcodegen generate && open Momentum.xcodeproj   # the app (macOS)
```

The code is split so most contributions do not need a Mac:

| Path | What | Needs a Mac |
|---|---|---|
| `Momentum/Models`, `Momentum/Engine` | data types and the training engine (pure Swift) | no |
| `MomentumTests` | tests for the above | no |
| `Tools/EngineSim` | command-line simulator for plans and 16-week runs | no |
| `tools/` | Python scripts: exercise animations, translations, mockups | no |
| `Momentum/Views`, `Store`, `Health`, `Design` | SwiftUI app | yes (CI also builds it) |

## Good first contributions

- **Translate or fix a translation.** Edit `tools/i18n/strings_*.py` or `tools/i18n/exercises.py`, then `python3 tools/i18n/export.py --strict && python3 tools/i18n/export_exercises.py`. Native speakers are very welcome: the current Spanish and Portuguese were written by an AI.
- **Add an exercise.** Add an entry to [`data/exercises.json`](data/exercises.json) (name, steps, muscle, equipment, movement pattern, joint stress, ladder rung; no Swift needed), its Spanish and Portuguese text in `tools/i18n/exercises.py`, and an animation in `tools/motions_*.py`. Then run `python3 tools/exercises/export.py` and `swift test`, which checks that everything lines up.
- **Improve the engine.** Change the rule in `Momentum/Engine`, update `docs/ENGINE.md` in the same commit, add a test that fails without your change, and run `swift run EngineSim sim` to see what it does over 16 weeks. `InvariantTests` throws random people at the engine for 12 simulated weeks; run it with more cases (`INVARIANT_SEED=5 INVARIANT_CASES=300 swift test --filter InvariantTests`) after a change.
- **Pick something from [docs/ROADMAP.md](docs/ROADMAP.md).**

## Making a change

1. Open an issue first for anything bigger than a fix, so we agree on the approach.
2. Keep the change focused; one topic per pull request.
3. `swift test` and, if you touched text, `python3 tools/i18n/export.py --strict` must pass. CI runs both, plus an iOS build and test.
4. New user-facing text goes through `L("English sentence")`, never a bare `Text("...")` (SwiftUI would not find it in our tables). No fragments glued together: use whole sentences with `{0}` placeholders.
5. Describe what changed and why in the pull request. Screenshots help for UI changes.

## Translations

English text is the lookup key. To add a language, see the *Translations* section of the [README](README.md).

## Conduct

Be kind and assume good faith. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
