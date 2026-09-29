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
| Pull | superman / snow angel, table row, pull-up (only planned when the person says they have a pull-up bar; a gym always has one) |
| Vertical push | plank shoulder tap, pike push-up, elevated pike |
| Triceps | chair dip, close push-up, diamond push-up |
| Core (stability) | dead bug, plank, side plank, hollow hold |
| Core (flexion) | crunch / bicycle, leg raise, V-up |

Missing answers fall back to level defaults.

## 3. Weekly structure

* **Split** by number of chosen days: 1-3 full body (advanced 3 = push/pull/legs), 4 upper/lower, 5 push/pull/legs +
  upper/lower, 6 push/pull/legs twice. Days are the weekdays the person picked.
* **Weekly volume targets** (hard sets per muscle per week, before goal scaling):

  | | chest | back | legs | shoulders | arms | core |
  |---|---|---|---|---|---|---|
  | beginner | 6-8 | 6-8 | 8-10 | 4-6 | 4-6 | 4-6 |
  | intermediate | 10-12 | 10-12 | 14-18 | 6-8 | 6-10 | 6-8 |
  | advanced | 12-16 | 12-16 | 16-20 | 8-12 | 8-12 | 6-10 |

  Scaled by goal: build muscle ×1.0, get stronger ×0.85, lose fat ×0.85, general fitness ×0.7. The midpoint is split
  across the sessions that train that muscle. A muscle is only trained in as many sessions as its target justifies
  (2+ sets each), spread evenly over the week, so small targets are not overshot by the two-set minimum. Each
  exercise gets 2-5 sets (compounds first, at most 3 for leg lifts so leg work spreads across several movements).
  If the session then uses under 80% of the time, the planner reruns with the top of the range instead of the middle.
  This is why a beginner's session can be shorter than the minutes they chose: extra volume would not help yet.
* **Time budget.** Session length is a ceiling. If the plan is too long, in order: exercises with more than 3 sets lose
  one, accessories drop to 2 sets, rests shorten by 15% (twice at most, never below 75 s for heavy lifts), accessories
  are dropped, compounds drop to 2 sets, and only then exercises are removed (never below 3; very restricted people are
  padded with safe core, leg or cardio work).
* **Exercise selection** by movement pattern, not by muscle name: squat, lunge, hinge, horizontal/vertical push and
  pull, isolation patterns, core patterns. Filters, in order: equipment owned, body areas to protect, low-impact,
  the user's excluded exercises, minimum level. Then: bodyweight-only or ladder patterns use the person's current rung
  (the rung below is used for variety on other days); loaded patterns take the best equipment. Bodyweight variations are
  never picked above the person's rung, even if the easier ones are excluded (the slot is skipped instead). Fallback
  patterns stay in the same muscle group. **Exercises change only at a block boundary** (the same boundaries as the deload week; restarting a block after a break or a level change also moves to the next variants), never week to week,
  otherwise progression cannot be measured. Different days of the week can use different variants.
* **Warm-up.** Three mobility drills chosen for the day's muscles (about 3 minutes) plus **ramp-up sets** for the first
  loaded compound (50% x 8, 70% x 5, and 85% x 2 when the working weight is 40 kg or more).

## 4. Prescription for one exercise

* **Rep range** (min-max) by goal and role:

  | | build muscle | get stronger | lose fat | general |
  |---|---|---|---|---|
  | loaded compound | 8-12 beginner, 6-10 otherwise | barbell lifts and pull-ups 6-8 / 5-8 / 3-6 (beginner / intermediate / advanced), other compounds 6-8 (advanced 5-8) | 10-15 | 8-12 |
  | loaded isolation | 10-15 | 8-12 | 12-20 | 10-15 |
  | bodyweight ladder (compound) | 8-15 | 5-10 | 10-15 | 8-12 |
  | other bodyweight | 10-20 | 10-20 | 12-20 | 10-20 |
  | timed hold | 20-45 s (beginner 15-30 s) | | | |

* **Rest** by role: heavy compound (max reps 6 or fewer) 150 s, other compound 90-120 s, isolation 60 s,
  bodyweight compound 60 s (other bodyweight moves 45 s), timed core 40 s, cardio 30 s. Fat loss shortens rest by about a third. Age 50+ adds 15% rest and one more rep in reserve.
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

**Bodyweight:** when every set reaches `max` the person moves to the next **rung** (reset to `min`), unless that
rung's exercises are excluded (equipment, protected body area): then the rep ceiling extends by 3 up to 25 and finally
a set is added. Stepping back a rung needs **three** consecutive sessions where most sets fall 3+ reps short of the
minimum. A ladder changes rung at most once every 14 days, so a hard week cannot cause back-and-forth.
**Holds:** same rules in seconds; +5-10 s until 90 s.

## 6. Autoregulation

* **Session feedback** (too easy / just right / too hard) moves a difficulty offset from -3 to +3, but only after
  **two agreeing ratings in a row** (finishing under 60% of the planned sets counts immediately). At +2 or more the
  first two compound lifts get an extra set, at -2 or less one fewer. Passing the ends changes the person's level
  up or down and resets the offset, at most once every four weeks.
* **Per-exercise effort** (easy / good / hard) feeds the progression table above.
* **Fatigue score** over the last 3 sessions in the last two weeks: 2 points per "too hard", 2 per session under 75%
  complete, 1 per exercise where most sets missed `min` (at most 2 per session). **5 or more, from at least two bad
  sessions**, triggers an automatic deload for the rest of that week. It never fires in the first two weeks or before
  four sessions exist, and not twice within 21 days.
* **Deload week** is the last week of every block (beginner 6 weeks, intermediate 5, advanced 4) or triggered by
  fatigue: sets x0.6 (minimum 2, and progression never adds a set), loads x0.9 of the weight last lifted (never heavier than it), cue "leave 4 in the tank". The next block starts after it.
* **Comeback**, measured **per movement** (days since that exercise, or another variation of the same movement, was last
  logged): 10-20 days loads x0.95, 21-34 x0.85, 35-59 x0.75, 60+ x0.65. It only applies after a real break, meaning a gap
  of 14 days or more in training since that movement was last done. Someone who keeps training but rotates or drops an
  exercise is not "coming back". A gap of 14+ days since the last session also removes one set from sets of three or more
  and restarts the block (exercises rotate to the next variants). Sessions dated in the future are ignored, and logs of
  exercises that no longer exist are skipped.
* **Readiness today.** *Low:* one set fewer on exercises with 3+ sets, no load increases that session, +15% rest.
  *Great/normal:* as planned.

## 7. Alternatives ("I can't do this")

Any exercise can be swapped from the workout screen or mid-workout. The person picks a reason and the engine
suggests replacements in the same movement pattern first (other patterns of the same muscle only when fewer than
three fit), never crossing between compound and isolation moves:

| Reason | What is offered |
|---|---|
| Too hard | Easier versions first (lower rung, gentler equipment such as machine or bodyweight), smallest step down first. Never harder ones. |
| Too easy | Harder variations. Never easier ones. For weighted lifts the honest answer is often "add weight", which the app already does. |
| It hurts | Asks where; excludes everything that stresses those areas (and impact moves for knees). Offers to keep protecting those areas from now on. |
| No equipment | Only exercises needing less equipment, closest first (barbell to dumbbells before bodyweight). |
| Don't like it | Same movement first, then same muscles. |

Comparison rules: bodyweight exercises compare by rung and level; loaded lifts compare by equipment demand (barbell,
then dumbbell, then machine/cable) because load can always be changed; a loaded exercise swapped for its bodyweight
version counts as easier. Suggestions respect equipment, protected areas, low-impact, excluded exercises and the
person's rung. Each suggestion carries a one-line reason.

The person chooses how long a swap lasts: this workout only, from now on (remembered preference), or never show the
original again. If nothing fits, the sheet says so and offers to skip the exercise for today.

## 8. What the person sees

* Every exercise carries a one-line reason ("Up 2 kg: you hit 12 reps on every set", "Deload week: lighter to
  recover", "Comeback: 15% lighter after 3 weeks off").
* Weekly volume by muscle against the target range (Progress tab).
* Estimated one-rep max per lift (Epley: weight x (1 + reps / 30)) and personal records.
* Messages after each workout when something changes (rung up, level up, deload).

## 9. Safety rules

* Body areas marked as problems remove every exercise tagged as stressing them; nothing is "modified" silently.
* "Low impact only" removes all jumping and impact exercises.
* Deadlift, back squat and other high-skill barbell lifts require intermediate level, in the plan, in swap suggestions (even for "too easy") and in remembered swap preferences.
* The app is not medical advice. Onboarding says so and recommends seeing a professional for pain.

## 10. Languages

The engine is language-independent: every decision (which exercise, how many sets, which load) is computed from ids and numbers, and only the sentences it shows are looked up in the current language (English, Spanish, Portuguese). Changing the language never changes a plan. A test plans the same weeks in each language and checks the exercises are identical. Exercise names and instructions are looked up by exercise id; the YouTube search uses the translated name so Spanish and Portuguese users get videos in their language. Weekday and month names follow the chosen language, and weights, dates and decimals use its formatting.
