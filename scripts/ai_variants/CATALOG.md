# AI variant catalog

Every AI idea is preserved as its own `ai_<name>.gd` (extends `AiBase`). None are
throwaway — they are feature modules to be **combined** into stronger composite
AIs later. Each overrides only specific hooks; that override surface determines
how cleanly two variants can be merged.

## Variants

| Variant | Feature | Hooks overridden | Tourney GD | Rank |
|---|---|---|---:|---:|
| handbrake | handbrake for sharp turns + brake to set up a shot | brake, slow | **+49** | 1 |
| goalside | arc behind the ball when caught on the wrong side | aim | **+43** | 2 |
| fsm | full state machine (combines most ideas below) | aim, boost, brake, slow | **+26** | 3 |
| center | drive the ball at goal-center (fixes wide-drift) | aim | +2 | 4 |
| powerdive | climb for potential energy, then dive-strike | aim, boost | +1 | 5 |
| boost | energy-economical boosting (boost on commit/chase) | boost | −6 | 6 |
| defense | drop goal-side & clear when own goal threatened | aim, boost | −8 | 7 |
| prediction | aim at predicted ball position (intercept) | aim | −10 | 8 |
| opponent | contest/intercept based on opponent position | aim | −10 | 9 |
| kickoff | committed centered first-touch off kickoffs | aim, boost | −15 | 10 |
| wallrec | pop wall-pinned balls back toward center | aim, boost | −18 | 11 |
| base | tuned line-up-then-commit striker (baseline) | (default) | −23 | 12 |
| stallrec | climb to recover when stalled (low+slow) | aim, boost | −31 | 13 |

GD = goal differential over 72 matches each (468-match round-robin, 3 seeds,
both sides, always-on aim noise). Full table: `tests/REPORT.md`; raw data:
regenerate `tests/results.csv` via `tests/tournament.sh` then `tests/rank.py`.

## Composition notes (for merging features later)

Two variants **compose trivially** when their overridden hooks are disjoint —
just combine the overrides in one file:

- `handbrake` (brake+slow) + `boost` (boost) + a single aim variant → no conflict.
  e.g. handbrake's turning + boost's economy + center's aiming is a clean merge.

Variants that share the `aim` hook (center, goalside, prediction, wallrec,
kickoff, defense, opponent, powerdive, stallrec) **conflict** and must be merged
by deciding precedence per situation (a small state machine). `ai_fsm.gd` is the
existing example: it already routes between defend / recover / line-up / commit /
chase and folds in centered shots, goalside arcs, prediction, and wall-unstick.

Practical path to one strong AI: start from `fsm`, then graft the cheap disjoint
wins on top — `handbrake`'s brake/slow logic and `boost`'s economy — since those
don't touch `aim`. Tune the merged result against the field with the harness.
