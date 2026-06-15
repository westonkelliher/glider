extends AiBase
## Wall-recovery striker. The baseline pins the ball against a side wall and
## taps it uselessly along the wall (ball stuck at |x| ~ 100+). When the ball
## is near a side wall, this variant lines up on the WALL side of the ball
## (between ball and the near wall) and strikes inward+forward so the ball pops
## back toward field centre (x -> 0) and toward our goal, instead of along the
## wall. Away from the walls it behaves exactly like the base striker.

const FIELD_HALF_X := 120.0   # side walls at x = +/-120
const GOAL_HALF_X := 40.0     # goal mouth is x in [-40, 40]
const WALL_NEAR := 85.0       # treat ball as "on the wall" past this |x|
const REACH_X := 113.0        # never aim outside/behind the wall


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	if absf(bp.x) <= WALL_NEAR:
		return super._compute_aim(glider, ball, ctx)

	var goal: Vector3 = ctx["goal"]
	var gp: Vector3 = ctx["gp"]
	var dist: float = ctx["dist"]
	var wall_sign: float = signf(bp.x)
	if wall_sign == 0.0:
		wall_sign = 1.0
	var fwd_sign: float = signf(goal.z - bp.z)   # +1 if our goal is in +z
	if fwd_sign == 0.0:
		fwd_sign = 1.0

	# Desired exit direction for the ball: strongly toward centre (-wall_sign x)
	# and forward toward our goal (fwd_sign z). Bias toward centre so we clear
	# the wall first, then carry goalward.
	var exit_flat := Vector3(-wall_sign * 1.3, 0.0, fwd_sign * 1.0)
	if exit_flat.length() < 0.001:
		exit_flat = Vector3(-wall_sign, 0.0, 0.0)
	exit_flat = exit_flat.normalized()

	# How lined up we already are to strike inward (1 = perfectly behind ball
	# on the exit line). from_ball points from ball to our glider.
	var from_ball := Vector3(gp.x - bp.x, 0.0, gp.z - bp.z)
	var lined: float = -1.0
	if from_ball.length() > 0.1:
		lined = from_ball.normalized().dot(-exit_flat)

	var aim: Vector3
	if lined > 0.45 and dist < 32.0:
		# Committed: drive THROUGH the ball along the exit direction.
		aim = bp + exit_flat * 26.0
	else:
		# Reposition behind the ball on the wall side (between ball and wall),
		# so the next strike pushes inward. Going "behind" the exit line means
		# moving toward the wall (larger |x|), so clamp to stay reachable.
		aim = bp - exit_flat * 16.0
		aim.x = bp.x + wall_sign * 6.0   # nudge to the wall side of the ball

	# Hard clamp x so the approach/aim never sits inside or behind the wall.
	aim.x = clampf(aim.x, -REACH_X, REACH_X)
	aim.y = bp.y - 1.0
	return aim


func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var bp: Vector3 = ctx["bp"]
	# Near a wall, commit a bit harder to actually pop the ball off it.
	if absf(bp.x) > WALL_NEAR:
		var desired: Vector3 = aim - glider.global_position
		if desired.length() < 0.001:
			return false
		var facing: float = ctx["nose"].dot(desired.normalized())
		return facing > 0.2 and ctx["speed"] < 34.0
	return super._decide_boost(glider, ball, ctx, aim)
