# Glider Refactor Opportunities

`glider_body.gd` (288 lines) is a god-object doing 5 jobs. `camera_rig.gd` and
`world.gd` are fine as-is. Split by responsibility:

## 1. Pause menu → `ui/pause_menu.gd` (+scene)  ~80 lines out
`_build_menu`, `_refresh_menu_labels`, `_on_tuning_pressed`, `_on_control_pressed`,
`_open_menu`, `_close_menu` are pure UI plumbing built imperatively in code.
Move to its own scene+script; expose `tuning_toggled` / `control_toggled` /
`resumed` signals. The glider shouldn't know how to lay out a VBox.

## 2. HUD readout → `ui/hud.gd`  (the `_pot_label` code)
Label creation in `_ready` + the per-frame `_pot_label.text = ...` update.
Trivial node that just listens for pot-height/mode. Decouples render from physics.

## 3. Flight tuning → `flight_tuning.gd` as a `Resource` (.tres)
The `Mode` enum + `PRESETS` dict + the ~10 mirrored `var X: float` fields +
`_apply_tuning()` are config, not behavior. A `Resource` lets you tune presets in
the inspector and drops the brittle `set(key, ...)` string-keyed copy loop.

## 4. Control input → `glider_input.gd` (or keep as a clean method)
`adjust_ailerons` + the `Scheme` enum (RL vs PILOT) own all input mapping and
surface-deflection visuals. Separable from the energy/physics model so control
remapping never touches flight math.

## 5. What remains in `glider_body.gd`: the actual flight model
The pot-height energy integration in `_physics_process` — the real, unique core.
After the above it's ~60 focused lines.

## Dead code to delete first (free win, no design needed)
- `interstep()` — stub that `return 0.` with a TODO; never called.
- `TURN_SPEED`, `JUMP_VELOCITY`, `PH_MARGIN` — unused constants.
- The ~25 commented-out lines at the end of `_physics_process` and scattered.

## Suggested order
Delete dead code → extract HUD → extract pause menu → extract tuning Resource →
(optional) split input. Each step is independent and testable.
