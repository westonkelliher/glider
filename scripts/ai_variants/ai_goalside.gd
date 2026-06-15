extends AiBase

# GOALSIDE: never get caught on the wrong side of the ball.
# If we're on the GOAL side of the ball (behindness < 0 -> a strike now would
# knock the ball away from / sideways to goal), don't lunge at it. Instead aim
# at a waypoint that ARCS around the ball: offset laterally (perpendicular to
# shoot_dir, picking the shorter way around) and pulled back behind the ball.
# Once we're behind it again (behindness positive), commit normally via super.

const ARC_TRIGGER := 0.05    # below this behindness we consider ourselves goalside
const LATERAL_OFF := 16.0    # how far to swing out sideways
const BACK_OFF := 14.0       # how far behind the ball the waypoint sits


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var behindness: float = ctx["behindness"]
	if behindness >= ARC_TRIGGER:
		return super._compute_aim(glider, ball, ctx)

	var bp: Vector3 = ctx["bp"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	if shoot_dir.length() < 0.01:
		return super._compute_aim(glider, ball, ctx)

	# Horizontal "left" relative to shoot_dir (perpendicular in the XZ plane).
	var left: Vector3 = Vector3.UP.cross(shoot_dir)
	if left.length() < 0.01:
		return super._compute_aim(glider, ball, ctx)
	left = left.normalized()

	# Which side of the shoot line are we on? Pick the shorter way around so we
	# swing out toward the side we're already on rather than crossing the ball.
	var gp: Vector3 = ctx["gp"]
	var from_ball: Vector3 = Vector3(gp.x - bp.x, 0.0, gp.z - bp.z)
	var side: float = signf(from_ball.dot(left))
	if side == 0.0:
		side = 1.0

	# Blend: deeper on the goal side (behindness more negative) -> swing wider
	# and stay further back; as we round behind it, ease the lateral offset off.
	var goalside_amt: float = clampf(-behindness, 0.0, 1.0)
	var lateral: float = LATERAL_OFF * (0.5 + 0.5 * goalside_amt)
	var back: float = BACK_OFF * (0.6 + 0.4 * goalside_amt)

	var aim: Vector3 = bp + left * side * lateral - shoot_dir * back
	aim.y = bp.y - 1.0
	return aim
