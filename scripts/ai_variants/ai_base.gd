class_name AiBase
extends RefCounted
## Base AI striker. Variants subclass this and override one or more hook methods.
## The default behaviour is the tuned "line up behind the ball, then commit a
## strike through it toward our goal" striker.
##
## CONTROL CONVENTIONS (verified in play):
##   ctl.targets = (pitch, roll, yaw), each in [-1, 1].
##     +pitch = nose up,  +yaw = nose right,  +roll = bank right.
##   ctl.boost  = add energy/speed along the nose.
##   ctl.slow   = [0,1] analog decel (bleed speed; good to set up a shot).
##   ctl.hand_brake = HANDBRAKE [0,1]. Cuts air friction so the craft pivots MUCH
##     more sharply (great for snapping around mid-course) at the cost of speed.
##     Use it for hard turns, not cruising.
##
## RANDOMNESS: every AI gets a seeded `rng` and a nonzero `aim_noise` so play is
## stochastic — deterministic AIs make head-to-head results meaningless.

const PITCH_SIGN := 1.0
const YAW_SIGN := 1.0
const ROLL_SIGN := 1.0

## Per-controller RNG, seeded by the harness/spawner.
var rng := RandomNumberGenerator.new()
## Std-dev (world units) of gaussian jitter added to the aim point each frame.
var aim_noise := 1.5


func sample(glider: Glider, _scheme: int) -> GliderControls:
	var ctl := GliderControls.new()
	var ball: Node3D = glider.get_tree().get_first_node_in_group("ball")
	if ball == null:
		return ctl
	var ctx: Dictionary = _context(glider, ball)
	var aim: Vector3 = _compute_aim(glider, ball, ctx)
	if aim_noise > 0.0:
		aim += Vector3(rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise), rng.randfn(0.0, aim_noise))
	ctl.targets = upright_roll(glider, _steer(glider, aim))
	ctl.boost = _decide_boost(glider, ball, ctx, aim)
	ctl.hand_brake = clampf(_brake_amount(glider, ball, ctx, aim), 0.0, 1.0)
	ctl.slow = _decide_slow(glider, ball, ctx, aim)
	return ctl


## Commonly-needed quantities, so overrides stay short. Keys:
##   bp, gp (Vector3 ball/glider pos), goal (Vector3 our target goal),
##   shoot_dir (Vector3, horizontal dir to push the ball), dist (float),
##   behindness (float, 1=perfectly lined up behind ball to shoot),
##   nose (Vector3), speed (float), ball_vel (Vector3), opponent (Glider or null).
func _context(glider: Glider, ball: Node3D) -> Dictionary:
	var bp: Vector3 = ball.global_position
	var gp: Vector3 = glider.global_position
	var goal: Vector3 = glider.target_goal
	var ball_flat := Vector3(bp.x, 0.0, bp.z)
	var goal_flat := Vector3(goal.x, 0.0, goal.z)
	var shoot_dir: Vector3 = (goal_flat - ball_flat).normalized()
	var from_ball: Vector3 = Vector3(gp.x, 0.0, gp.z) - ball_flat
	var behindness: float = -1.0
	if from_ball.length() > 0.1:
		behindness = from_ball.normalized().dot(-shoot_dir)
	var opponent: Node = null
	for g: Node in glider.get_tree().get_nodes_in_group("glider"):
		if g != glider:
			opponent = g
			break
	return {
		"bp": bp, "gp": gp, "goal": goal,
		"shoot_dir": shoot_dir,
		"dist": gp.distance_to(bp),
		"behindness": behindness,
		"nose": (glider.global_transform.basis * Vector3.FORWARD).normalized(),
		"speed": glider.velocity.length(),
		"ball_vel": ball.velocity,
		"opponent": opponent,
	}


## Where to fly. Override this for most aim/positioning ideas.
func _compute_aim(_glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var behindness: float = ctx["behindness"]
	var dist: float = ctx["dist"]
	var aim: Vector3
	if behindness > 0.55 and dist < 21.0:
		aim = bp + shoot_dir * 17.5   # committed: drive through the ball toward goal
		aim.y = bp.y
	else:
		aim = bp - shoot_dir * 8.4   # reposition behind the ball
		aim.y = bp.y - 1.0
	return aim


## Map a world-space aim point to (pitch, roll, yaw) targets.
func _steer(glider: Glider, aim: Vector3) -> Vector3:
	var desired: Vector3 = aim - glider.global_position
	# Normalize AFTER the inverse so the basis's uniform scale cancels.
	var local: Vector3 = (glider.global_transform.basis.inverse() * desired).normalized()
	return Vector3(
		clampf(PITCH_SIGN * local.y, -1.0, 1.0),
		clampf(ROLL_SIGN * local.x * 0.5, -1.0, 1.0),
		clampf(YAW_SIGN * local.x, -1.0, 1.0),
	)


## Drive the roll target toward flying upright, proportional to how far the
## craft is banked from level. Replaces the steering bank (which is what sends
## the AI inverted) — yaw still handles turning, so the craft just looks sane.
## Returns `targets` with its roll (y) component overwritten.
static func upright_roll(glider: Glider, targets: Vector3) -> Vector3:
	var basis: Basis = glider.global_transform.basis.orthonormalized()
	var nose: Vector3 = -basis.z
	# World-up projected into the plane perpendicular to the nose (the roll plane).
	var up_proj: Vector3 = Vector3.UP - Vector3.UP.dot(nose) * nose
	if up_proj.length() < 0.05:
		return targets   # nose near-vertical: roll is ill-defined, leave it alone
	up_proj = up_proj.normalized()
	# Signed bank angle of the craft's up-vector from level, about the nose axis.
	var angle: float = basis.y.signed_angle_to(up_proj, nose)
	targets.y = clampf(-angle / (PI * 0.5), -1.0, 1.0)
	return targets


func _decide_boost(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var desired: Vector3 = aim - glider.global_position
	var facing: float = ctx["nose"].dot(desired.normalized())
	var slow_or_far: bool = ctx["speed"] < 26.0 or desired.length() > 28.0
	return slow_or_far and facing > 0.3


## ANALOG handbrake [0,1]: the engine lerps both wing-retraction and turn-rate
## continuously on this (glider_body: target_extension / rrate), so we return a
## smooth amount, NOT a 0/1 flag. Brake hardest when the aim has fallen off the
## nose (a sharp pivot is needed) and we're fast enough that braking helps the
## turn instead of stalling. Variants override this for state-specific braking.
func _brake_amount(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())   # 1 aligned, -1 opposed
	# Ramp in as the aim drifts off the nose (facing 0.5 -> 0, -0.3 -> full brake).
	var turn: float = smoothstep(0.5, -0.3, facing)
	# Gate by speed: braking while slow just stalls us (fade in over 12..22 u/s).
	var fast: float = smoothstep(12.0, 22.0, ctx["speed"])
	return turn * fast


func _decide_slow(_glider: Glider, _ball: Node3D, _ctx: Dictionary, _aim: Vector3) -> float:
	return 0.0
