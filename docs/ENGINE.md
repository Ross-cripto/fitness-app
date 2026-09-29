# Training engine specification

This is what the app does to build and adapt a plan. Every rule here is implemented in `Momentum/Engine/` (pure
Swift, no UI) and covered by tests in `MomentumTests/`. There is no account, no network and no AI service. Every
decision is a deterministic rule that can be explained to the user, and the app does explain them in each exercise's
"why" line.

## 1. What the engine knows about a person

| Input | Where it comes from | Used for |
|---|---|---|
| Goal: build muscle, get stronger, lose fat, general fitness | Onboarding | Rep ranges, rest, weekly volume, cardio finisher |
| Training history (never / <6 mo / 6-24 mo / 2+ yrs) and recent frequency | Onboarding | Starting level |
| Quick strength check (push-ups, squats, plank, pull-ups; each optional) | Onboarding | Starting **rung** on each progression ladder |
| Days available (actual weekdays) and minutes per session | Onboarding | Split, session length |
| Equipment: none / dumbbells (+ heaviest pair) / full gym | Onboarding | Exercise pool, load caps, load steps |
| Body areas to protect: knees, lower back, shoulders, wrists; low-impact only | Onboarding | Hard exclusion of stressful exercises |
| Sex (optional), age, weight, height | Onboarding | Starting-weight estimate, rest, calories |
| Logged sets: reps, load, seconds, per-exercise effort, session feedback | Every workout | Progression, fatigue, level |
| Readiness today: great / normal / low | Before a workout | Volume and progression for that session |

## 2. Placement (first plan)

**Level** = `history (0-3) + recent frequency (0-3)`: 0-2 beginner, 3-4 intermediate, 5-6 advanced, except advanced
requires 2+ years of history. The optional check then adjusts it once: a beginner with at least 3 "strong" markers
(15+ push-ups, 30+ squats, 60 s plank, 3+ pull-ups) becomes intermediate; anyone whose provided markers are all weak
(3 or fewer push-ups **and** plank under 20 s) is placed one level lower. People overestimate themselves; the check
catches it.

**Rungs.** Bodyweight movements form ladders (easiest to hardest). The check chooses where on each ladder to start:

| Ladder | Rungs |
|---|---|
| Push | wall push-up, knee push-up, push-up, decline push-up |
| Squat | bodyweight squat / wall sit, jump squat |
| Lunge | reverse lunge, split squat |
| Hinge | glute bridge, single-leg bridge |
| Pull | superman / snow angel, table row, pull-up |
| Vertical push | plank shoulder tap, pike push-up, elevated pike |
| Triceps | chair dip, close push-up, diamond push-up |
| Core (stability) | dead bug, plank, side plank, hollow hold |
| Core (flexion) | crunch / bicycle, leg raise, V-up |

Missing answers fall back to level defaults.

## 3. Weekly structure

* **Split** by number of chosen days: 1-3 full body (advanced 3 = push/pull/legs), 4 upper/lower, 5 push/pull/legs +
  upper/lower, 6 push/pull/legs twice. Days are the weekdays the person picked.
* **Weekly volume targets** (hard sets per muscle per week):

  | | chest | back | legs | shoulders | arms | core |
  |---|---|---|---|---|---|---|
  | beginner | 6-8 | 6-8 | 8-10 | 4-6 | 4-6 | 4-6 |
  | intermediate | 10-12 | 10-12 | 12-14 | 6-8 | 6-10 | 6-8 |
  | advanced | 12-16 | 12-16 | 14-18 | 8-12 | 8-12 | 6-10 |

  Scaled by goal: build muscle ×1.0, get stronger ×0.85, lose fat ×0.85, general fitness ×0.7. The midpoint is split
  across the sessions that train that muscle. Each exercise gets 2-5 sets (compounds first). This is why a beginner's
  session can be shorter than the minutes they chose: extra volume would not help yet, and the plan says so.
* **Time budget.** Session length is a ceiling. If the plan is too long, accessory sets drop to 2, then the
  lowest-priority exercises are removed (never below 3 exercises).
* **Exercise selection** by movement pattern, not by muscle name: squat, lunge, hinge, horizontal/vertical push and
  pull, isolation patterns, core patterns. Filters, in order: equipment owned, body areas to protect, low-impact,
  the user's excluded exercises, minimum level. Then: bodyweight-only or ladder patterns use the person's current rung
  (chosen variant rotates by block); loaded patterns take the best equipment. **Exercises change only at a block
  boundary**, never week to week, otherwise progression cannot be measured.
* **Warm-up.** Three mobility drills chosen for the day's muscles (about 3 minutes) plus **ramp-up sets** for the first
  loaded compound (50% x 8, 70% x 5, and 85% x 2 when the working weight is 40 kg or more).

## 4. Prescription for one exercise

* **Rep range** (min-max) by goal and role:

  | | build muscle | get stronger | lose fat | general |
  |---|---|---|---|---|
  | loaded compound | 8-12 beginner, 6-10 otherwise | 6-8 / 5-8 / 3-6 | 10-15 | 8-12 |
  | loaded isolation | 10-15 | 8-12 | 12-20 | 10-15 |
  | bodyweight ladder | 8-15 | 5-10 | 12-20 | 10-15 |
  | timed hold | 20-45 s (beginner 15-30 s) | | | |

* **Rest** by role: heavy compound (max reps 6 or fewer) 150 s, other compound 90-120 s, isolation 60 s,
  bodyweight 60 s, timed core 40 s, cardio 30 s. Fat loss shortens rest by about a third. Age 50+ adds 15%.
* **Effort cue (reps in reserve)** by position in the block: week 1 leave 3 in the tank, week 2 leave 2, later weeks
  leave 1-2 (beginners never below 2), deload week leave 4.
* **Starting load** = typical ratio to body weight x level factor x sex factor x age factor x 0.85 (start light),
  rounded to the equipment's step and capped at the heaviest dumbbell the person owns.

## 5. Progression (after each session, per exercise)

Double progression with the reps from the last time that exercise was logged. `min`/`max` = the rep range.

| Situation (sets at the working load) | Next time |
|---|---|
| Every set reached `max` | Add one load step (two if every set beat `max` by 3+ and it did not feel hard). Reps reset to `min`. If the exercise felt **hard** even though the range was hit, repeat the load to consolidate. |
| Every set reached `min` but not `max` | Same load, aim for **one more rep** than the weakest set. |
| Only one set below `min` | Same load, target `min`. |
| Most sets below `min` | Repeat the load once. Two sessions in a row: drop 10%. If reps were 4+ under `min` (load was badly estimated): drop 10% immediately. |
| Marked **easy** and every set within 1 rep of `max` | Treated as reaching `max` (progress early). |
| Already at the heaviest dumbbell | Stop adding load; extend reps up to 20. |

Load steps: dumbbells 1 kg (<10 kg), 2 kg (<30 kg), 2.5 kg above; barbell and machine 2.5 kg upper body, 5 kg legs.

**Bodyweight:** when every set reaches `max` the person moves to the next **rung** (reset to `min`). If there is no
next rung available (equipment, protected body area), the rep ceiling extends by 3 up to 25. Two failed sessions in
a row on a rung move them one rung back. **Holds:** same rules in seconds; +5-10 s until 60 s, then next rung.

## 6. Autoregulation

* **Session feedback** (too easy / just right / too hard) moves a difficulty offset from -3 to +3 (also -1 if
  fewer than 60% of the planned sets were completed). At +2 or more main lifts get one extra set, at -2 or less one
  fewer. Passing the ends changes the person's level up or down and resets the offset.
* **Per-exercise effort** (easy / good / hard) feeds the progression table above.
* **Fatigue score** over the last 3 sessions: 2 points per "too hard", 2 per session under 75% complete, 1 per exercise
  where most sets missed `min`. **5 or more** triggers an automatic deload for the rest of that week.
* **Deload week** is the last week of every block (beginner 6 weeks, intermediate 5, advanced 4) or triggered by
  fatigue: sets x0.6 (minimum 2), loads x0.9, cue "leave 4 in the tank". The next block starts after it.
* **Comeback.** Days since the last workout: 10-20 loads x0.95, 21-34 x0.85, 35-59 x0.75, 60+ x0.65, and one set fewer.
  A gap of 14+ days also restarts the block.
* **Readiness today.** *Low:* one set fewer on exercises with 3+ sets, no load increases that session, +15% rest.
  *Great/normal:* as planned.

## 7. What the person sees

* Every exercise carries a one-line reason ("Up 2 kg: you hit 12 reps on every set", "Deload week: lighter to
  recover", "Comeback: 15% lighter after 3 weeks off").
* Weekly volume by muscle against the target range (Progress tab).
* Estimated one-rep max per lift (Epley: weight x (1 + reps / 30)) and personal records.
* Messages after each workout when something changes (rung up, level up, deload).

## 8. Safety rules

* Body areas marked as problems remove every exercise tagged as stressing them; nothing is "modified" silently.
* "Low impact only" removes all jumping and impact exercises.
* Deadlift, back squat and other high-skill barbell lifts require intermediate level.
* The app is not medical advice. Onboarding says so and recommends seeing a professional for pain.
