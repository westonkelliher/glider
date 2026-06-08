class_name GliderInput
extends RefCounted
## Control-scheme policy: maps the input map to desired aileron deflection
## targets. Pure — no node access, no state — so remapping never touches the
## flight model.
##
## RL: roll while air_roll held, else yaw. PILOT: roll always on stick,
## yaw on Q/E or LB/RB bumpers.

enum Scheme { RL, PILOT }


## Returns deflection targets in [-1, 1] as (pitch, roll, yaw).
static func read_targets(scheme: Scheme) -> Vector3:
	var pitch := Input.get_axis("move_forward", "move_back")
	var lr := Input.get_axis("move_right", "move_left")
	var roll := 0.0
	var yaw := 0.0
	if scheme == Scheme.RL:
		if Input.is_action_pressed("air_roll"):
			roll = lr
		else:
			yaw = lr
	else: # PILOT
		roll = lr
		yaw = Input.get_axis("yaw_left", "yaw_right")
	return Vector3(pitch, roll, yaw)


static func name_of(scheme: Scheme) -> String:
	return "ROCKET LEAGUE" if scheme == Scheme.RL else "PILOT"
