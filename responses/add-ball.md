# Adding a Ball with SumoSoccer-style collisions

## What SumoSoccer actually does (`ball.gd` / `physics_handler.gd`)
It does **not** trust Godot's solver. The pattern:
1. A central `physics_handler` (an autoload-ish `Node`) owns every dynamic body and steps them in lockstep each `_physics_process`: clear → `_handle_physics` (detect+resolve) → `_handle_velocity` (apply).
2. Each body uses `move_and_slide()` **only to detect** contacts, then immediately reverts `position`/`velocity` to the pre-move values.
3. Collisions are resolved manually with the impulse-based elastic formula:
   `j = -(1+e)·(v_rel·n) / (1/m₁ + 1/m₂)`, dispatched by type (`is Wall` → reflect, `is Ball`/`is Sumo` → exchange impulse).
4. "Clippers" push overlapping bodies apart along the contact normal so nothing tunnels/sticks.

That formula is **dimension-agnostic** — it ports to 3D unchanged (just `Vector3`).

## Plan for glider (3D)
- **`ball.tscn`**: `CharacterBody3D` + `SphereShape3D` + a mesh. `class_name Ball`.
- **`ball.gd`**: gravity + ground bounce + the detect-revert-resolve loop above. Treat the glider as the "other" body (give `GliderBody` a `mass` and `class_name Glider`).
- **Glider side**: the glider already ends `_physics_process` with `move_and_slide()`. Easiest integration: after its move, check `get_slide_collision_count()` for the ball and apply the same impulse to its `velocity`. The ball reads the glider's `velocity`/`mass` to compute the exchange.
- **Order matters**: resolve in one place so both bodies see consistent pre-step velocities. Either reuse SumoSoccer's central-handler pattern, or let the ball be the sole resolver (it reads glider velocity, mutates both) since there's only one of each.

## Adapt / drop
- **Drop the spin/curve system** initially (`rotation_velocity`, `add_spin`, `CURVE_FACTOR`) — it's a 2D scalar spin; 3D needs a `Vector3` angular velocity and isn't core to "ball bounces off glider."
- **Walls → ground/terrain**: replace 1920×1080 bounds with the floor plane + out-of-bounds reset.
- **Tunables to copy**: `MASS`, `BOUNCE_FACTOR_REFLECTION`, `DAMPING`/`DECELERATION`. The glider's mass vs ball mass sets how much a hit deflects the craft.

## Smallest first step
Make `ball.gd` self-contained: gravity, floor bounce, and on contact with `GliderBody` apply the impulse exchange to both velocities. No central handler needed for one ball. Add the handler only if you later want many balls colliding with each other.
