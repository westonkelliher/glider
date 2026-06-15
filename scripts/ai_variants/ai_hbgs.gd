extends AiBase
## goalside arc + handbrake SLOW. First locked step of the one-at-a-time build
## (see METHOD.md). Base striker, plus:
##   - goalside: when caught on the wrong side of the ball, arc around to a
##     behind-the-ball waypoint instead of lunging (suppress slow while arcing).
##   - handbrake slow: bleed speed when close but poorly lined up, to re-set a
##     clean strike.
##
## NOTE: handbrake's BRAKE was tried here too and dropped — ablation (n=32) on the
## current physics showed brake helps vs handbrake but hurts more vs goalside,
## net negative. slow+arc beats BOTH pure handbrake (+12, W16-7) and pure goalside
## (+12, W13-4) on goal differential. Revisit brake as its own tuned step later.

const ARC_TRIGGER := 0.05    # below this behindness we're "goalside"
const ARC_LATERAL := 16.0    # how far to swing out sideways
const ARC_BACK := 14.0       # how far behind the ball the waypoint sits

var _arcing: bool = false


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var behindness: float = ctx["behindness"]
	if behindness < ARC_TRIGGER:
		_arcing = true
		return _goalside_arc(ctx["gp"], ctx["bp"], ctx["shoot_dir"], behindness)
	_arcing = false
	return super._compute_aim(glider, ball, ctx)


## goalside's arc-around waypoint: lateral offset (shorter way round) + standoff
## behind the ball, both scaled by how far on the goal side we are.
func _goalside_arc(gp: Vector3, bp: Vector3, shoot_dir: Vector3, behindness: float) -> Vector3:
	if shoot_dir.length() < 0.01:
		var b: Vector3 = bp
		b.y = bp.y - 1.0
		return b
	var left: Vector3 = Vector3.UP.cross(shoot_dir)
	if left.length() < 0.01:
		var p: Vector3 = bp - shoot_dir * ARC_BACK
		p.y = bp.y - 1.0
		return p
	left = left.normalized()

	var from_ball: Vector3 = Vector3(gp.x - bp.x, 0.0, gp.z - bp.z)
	var side: float = signf(from_ball.dot(left))
	if side == 0.0:
		side = 1.0

	var goalside_amt: float = clampf(-behindness, 0.0, 1.0)
	var lateral: float = ARC_LATERAL * (0.5 + 0.5 * goalside_amt)
	var back: float = ARC_BACK * (0.6 + 0.4 * goalside_amt)
	var aim: Vector3 = bp + left * side * lateral - shoot_dir * back
	aim.y = bp.y - 1.0
	return aim


# handbrake slow: bleed speed when close but poorly lined up, to re-set a strike.
# Suppressed while arcing so we keep momentum through the goalside swing.
func _decide_slow(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	if _arcing:
		return 0.0
	var dist: float = ctx["dist"]
	var behindness: float = ctx["behindness"]
	var speed: float = ctx["speed"]
	if dist > 16.0 or speed < 12.0:
		return 0.0
	if behindness > 0.5:
		return 0.0
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())
	if facing > 0.6:
		return 0.0
	var amount: float = 0.6 + rng.randf_range(-0.15, 0.15)
	return clampf(amount, 0.0, 1.0)
