# AI variant authoring

Each variant is one file: `scripts/ai_variants/ai_<name>.gd`, loaded by name when
a glider's `ai_variant` export is set to `<name>`. A glider with `is_ai = true`
attacks `target_goal` (BLUE = `(0,15,205)` / north / +Z; ORANGE = `(0,15,-205)`).

## Template

```gdscript
extends AiBase

# Override one or more hooks. The base implements a tuned "line up behind the
# ball, then commit a strike through it toward our goal" striker.

func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
    # return a world-space point to fly toward
    return super._compute_aim(glider, ball, ctx)

func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
    return super._decide_boost(glider, ball, ctx, aim)

func _brake_amount(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
    return super._brake_amount(glider, ball, ctx, aim)  # ANALOG [0,1] handbrake:
    # cuts air friction -> sharper turns, bleeds speed. Ramp it, don't flip 0/1.

func _decide_slow(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
    return 0.0    # [0,1] analog decel, good for setting up a shot

func _steer(glider: Glider, aim: Vector3) -> Vector3:
    return super._steer(glider, aim)  # rarely needs overriding
```

## `ctx` keys (see ai_base.gd `_context`)
`bp`, `gp` (ball/glider pos), `goal`, `shoot_dir` (horizontal push dir),
`dist`, `behindness` (1 = lined up behind ball), `nose`, `speed`, `ball_vel`,
`opponent` (the other glider, or null).

## Controls (GliderControls)
`targets = (pitch, roll, yaw)` each in [-1,1]: +pitch=nose up, +yaw=nose right,
+roll=bank right. `boost`=add speed along nose. `slow`=[0,1] decel.
`hand_brake`=[0,1] HANDBRAKE (sharp turns, costs speed).

## Physics notes
- Speed comes from POTENTIAL ENERGY (altitude) or boost. To go fast, dive or
  boost. At low altitude with no boost the craft stalls and can't manoeuvre.
- The big baseline weakness: shots drift WIDE (ball ends up at large |x|, past
  the ±40 goal mouth). Centering shots / recovering wall balls scores more.

## Rules
- The project treats **untyped declarations as errors**. Type every param,
  return, var (`:=` inferred is fine), and `for x: T in ...` loop variable.
- Do NOT add `class_name` to a variant (it's loaded by path).
- `rng` (seeded) and `aim_noise` (default 1.5) are inherited — keep some
  randomness; deterministic AIs make head-to-head results invalid.

## Self-test
```
godot --headless --path <proj> --fixed-fps 60 res://tests/match.tscn -- \
  blue=<name> orange=base seed=1 frames=12000 goals=20
godot --headless ... -- blue=base orange=<name> seed=1 frames=12000 goals=20
```
Look for the `[match] TALLY ...` line. Run several seeds (1..5); a better
variant should out-score base across seeds (as the attacker AND when defending).
```
