# Loose ends

All code changes committed + pushed to `with-ball` (5 commits: arena flicker, camera modes, glider tune, ball tune, HUD).

## Should act on
- **`build/` (100 MB) is untracked** — it's Windows export output. Add `build/` (or `/build/`) to `.gitignore` so it never gets committed. **Recommend doing this.**
- **Untracked docs**: `MULTIPLAYER_ROADMAP.md`, `rocket_league_values_reference.md` — commit these if you want them tracked, else they'll keep showing as dirty.
- **`responses/*.md`** — these are my `-v` report outputs. Gitignore `responses/` too, probably.

## Worth a glance
- **Goal-zone flicker** (blue/orange) — I fixed it the same way as the walls but you only re-tested the walls. Confirm the goals are clean now.
- **HUD wording**: "Q/E yaw" only applies in **Pilot** scheme; in **RL** scheme A/D already yaws. Minor, but the line is slightly scheme-dependent.
- **Free-cam pitch is unclamped** (the `clamp(...)` line is commented out in `camera_rig.gd`) — you can roll the view past vertical. Intentional?
- **Floor collision re-enabled** — glider now lands/collides with the ground again. Assuming that's the intent.

## Clean
- Camera mode switching, input actions, and `ball` NodePath wiring all consistent across `project.godot` / `main.tscn` / `camera_rig.gd`.
