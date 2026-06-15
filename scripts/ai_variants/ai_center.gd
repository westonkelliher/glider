extends AiBase
## Centered-shot striker. The baseline's strikes drift WIDE: the ball ends up at
## large |x| past the +-40 goal mouth and sails wide. This variant lines up and
## then commits a strike that drives the ball toward the GOAL-CENTER line (x~0)
## as well as forward, so contact has an inward (toward x=0) component.

const GOAL_HALF_WIDTH := 40.0


## Safe normalize: returns `fallback` for (near) zero-length vectors.
func _norm(v: Vector3, fallback: Vector3) -> Vector3:
	if v.length() < 0.001:
		return fallback
	return v.normalized()


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	var goal: Vector3 = ctx["goal"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var behindness: float = ctx["behindness"]
	var dist: float = ctx["dist"]

	# Horizontal vector from the ball to the goal CENTER (goal.x ~ 0). This is the
	# direction we want the ball to travel; it points straight at the mouth.
	var to_center: Vector3 = _norm(
		Vector3(goal.x - bp.x, 0.0, goal.z - bp.z),
		shoot_dir)

	if behindness > 0.55 and dist < 30.0:
		# Committed: drive THROUGH the ball toward a far point on the goal-center
		# line, so the strike pushes the ball back toward x=0 as it goes forward.
		var aim: Vector3 = bp + to_center * 26.0
		aim.y = bp.y
		return aim

	# Repositioning behind the ball. Pick the standoff so the (standoff -> ball)
	# line points at the goal center. When the ball is wide, bias to the
	# far-from-center side so contact has an inward (toward x=0) component.
	var standoff: Vector3 = bp - to_center * 12.0
	if absf(bp.x) > GOAL_HALF_WIDTH:
		# Ball is wide of the mouth: approach from further out on the wide side so
		# the strike sweeps the ball back inward toward x=0.
		var wide_sign: float = signf(bp.x)
		if wide_sign == 0.0:
			wide_sign = 1.0
		standoff.x += wide_sign * 8.0
	standoff.y = bp.y - 1.0
	return standoff
