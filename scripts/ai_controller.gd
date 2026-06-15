class_name AiController
extends RefCounted
## First-cut AI: fly to a standoff point behind the ball (relative to the BLUE
## goal) so striking the ball drives it toward the goal.
##
## NOTE: the per-axis SIGN constants below are PROVISIONAL. The mapping from
## glider-local target direction to (pitch, roll, yaw) deflection targets has
## not been verified against the flight model's rotation conventions, so a test
## harness will tune these later. They are isolated as consts to make flipping
## any one axis a one-character change.
const PITCH_SIGN := 1.0
const YAW_SIGN := 1.0
const ROLL_SIGN := 1.0

## Aim at the mouth of the BLUE goal (world +Z side).
const BLUE_GOAL := Vector3(0.0, 15.0, 205.0)


func sample(glider: Glider, _scheme: GliderInput.Scheme) -> GliderControls:
	var ctl := GliderControls.new()
	var ball: Node3D = glider.get_tree().get_first_node_in_group("ball")
	if ball == null:
		return ctl

	# Striker logic, all in the horizontal plane: the direction we want to send
	# the ball is ball -> goal. To do that cleanly we (1) line up BEHIND the ball
	# on that line, then (2) once lined up, COMMIT by aiming through the ball
	# toward the goal so we strike it square. This stops the craft orbiting the
	# ball and keeps shots centred on the goal mouth instead of drifting wide.
	var bp: Vector3 = ball.global_position
	var gp: Vector3 = glider.global_position
	var ball_flat := Vector3(bp.x, 0.0, bp.z)
	var goal_flat := Vector3(BLUE_GOAL.x, 0.0, BLUE_GOAL.z)
	var shoot_dir: Vector3 = (goal_flat - ball_flat).normalized()  # push the ball this way
	var standoff := 12.0
	var dist: float = gp.distance_to(bp)
	# How directly are we behind the ball (1.0 = perfectly lined up to shoot)?
	var from_ball_flat: Vector3 = (Vector3(gp.x, 0.0, gp.z) - ball_flat)
	var behindness: float = from_ball_flat.normalized().dot(-shoot_dir) if from_ball_flat.length() > 0.1 else -1.0

	var aim: Vector3
	if behindness > 0.55 and dist < 30.0:
		# Committed: drive through the ball toward the goal.
		aim = bp + shoot_dir * 25.0
		aim.y = bp.y
	else:
		# Reposition behind the ball, slightly low so we lift it forward on contact.
		aim = bp - shoot_dir * standoff
		aim.y = bp.y - 1.0

	var desired: Vector3 = aim - glider.global_position
	# Glider-local direction to target: +X right, +Y up, forward = -Z.
	# Normalize AFTER the inverse so the basis's uniform scale cancels and we get
	# a true unit direction (otherwise steering authority is shrunk by 1/scale).
	var local: Vector3 = (glider.global_transform.basis.inverse() * desired).normalized()

	ctl.targets = Vector3(
		clampf(PITCH_SIGN * local.y, -1.0, 1.0),       # pitch: nose toward target vertically
		clampf(ROLL_SIGN * local.x * 0.5, -1.0, 1.0),  # roll: gentle bank into the turn
		clampf(YAW_SIGN * local.x, -1.0, 1.0),         # yaw: turn toward target horizontally
	)

	# Energy management: speed comes from potential energy (altitude) or boost.
	# Boost whenever we're slow or far AND roughly pointed at the aim point, so
	# the craft keeps enough energy to manoeuvre near the ball instead of stalling.
	var nose_dir: Vector3 = (glider.global_transform.basis * Vector3.FORWARD).normalized()
	var facing: float = nose_dir.dot(desired.normalized())
	var slow_or_far: bool = glider.velocity.length() < 26.0 or desired.length() > 40.0
	ctl.boost = slow_or_far and facing > 0.3

	ctl.slow = 0.0  # TODO: brake/slow when overshooting or too close to the ball.
	ctl.braked = false
	return ctl
