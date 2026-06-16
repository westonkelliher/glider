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
	# Stick X with one explicit convention: +1 = right. Both roll and yaw are
	# expressed from this so every "turn right" input shares the same sign as the
	# yaw_left/yaw_right keys (which also give +1 = right).
	var stick_x := Input.get_axis("move_left", "move_right")
	var roll := 0.0
	var yaw := 0.0
	if scheme == Scheme.RL:
		# Default L/R yaws; hold air_roll to roll instead.
		if Input.is_action_pressed("air_roll"):
			roll = -stick_x # bank right on stick-right
		else:
			yaw = stick_x
	else: # PILOT: stick always rolls; dedicated keys/bumpers yaw.
		roll = -stick_x
		yaw = Input.get_axis("yaw_left", "yaw_right")
	return Vector3(pitch, roll, yaw)

## Analog handbrake in [0,1]. Default is FULL brake (1.0); the right trigger
## releases it (1.0 - trigger). The X button (air_brake_flip) INVERTS the
## trigger's sense, so holding X makes the trigger *apply* brake instead —
## i.e. X + full trigger == no-X + no-trigger == full brake (1.0).
static func read_hand_brake() -> float:
	var trigger := Input.get_action_strength("air_brake")
	if Input.is_action_pressed("air_brake_flip"):
		return trigger
	return 1.0 - trigger


static func name_of(scheme: Scheme) -> String:
	return "ROCKET LEAGUE" if scheme == Scheme.RL else "PILOT"
