# Scenario tests (fast AI tuning)

Drops one AI into 10 fixed micro-situations — 5 **shot** (score in +Z goal) and
5 **keeper** (stop a ball launched at the −Z goal) — each repeated `reps` times
with ±7% jitter (abs floor: pos 2.0, vel 1.0) on ball/glider position+velocity.
All reps run in ONE headless process, so it's ~100× faster than playing games.
Same `seed` ⇒ identical setups across variants ⇒ fair A/B.

## Run

```sh
bash tests/scenarios.sh                    # default set: hbgs handbrake goalside base, reps=40 seed=1
bash tests/scenarios.sh hbgs handbrake     # pick variants (any ai_<name>.gd)
REPS=80 SEED=3 bash tests/scenarios.sh hbgs    # more reps / different jitter set
DETAIL=1 bash tests/scenarios.sh hbgs           # also print per-scenario rates
```

Or one variant directly:
```sh
godot --headless --path . --fixed-fps 60 res://tests/scenarios.tscn -- variant=hbgs reps=40 seed=1
```

## Reading output

- `s=<name> ... rate=R avg_frames=F` — success fraction per scenario; `avg_frames`
  = mean frames-to-goal for shots (lower = quicker finish; −1 = keeper/none).
- `SUMMARY ... shots=S keeps=K overall=O` — mean rate over the 5 shots, 5 keeps,
  and all 10. **Compare `shots`/`keeps`/`overall` between variants to tune.**

## Tuning workflow

1. Baseline the current AI. 2. Change one thing. 3. Re-run at the same SEED and
   a high REPS (≥40); a real change moves the rate clearly past run-to-run noise.
   Confirm across a couple of seeds. 4. Keep full-game round-robin as the final
   transfer check — scenarios are uncontested (no opponent), so they measure raw
   skill, not contested play.

## Editing scenarios

Edit the `scenarios` array in `tests/scenarios.gd` (pos/vel/speed per setup) and
`shot_frames`/`keep_frames` budgets. Aim each scenario for a mid-range baseline
rate (~0.15–0.85) so there's headroom to show both gains and regressions.
`shot_wrongside` is intentionally ~0% (a broken-skill improvement target).
