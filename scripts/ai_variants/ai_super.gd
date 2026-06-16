extends AiBase
## SUPER striker. The first attempt grafted everything onto fsm's state machine
## and finished 4th: great midfield control, but it couldn't FINISH (lowest
## goals-for in the field). The tournament data is blunt about why — the winners
## (handbrake +14, goalside +14) just drive the plain BASE strike relentlessly
## through the ball, while fsm's machine (+4) and center's aggressive
## goal-centring (-10) make play tentative near goal.
##
## So this version layers ONLY the proven wins onto the base striker, in order:
##   1. RECOVER  (from fsm) — the one no-downside state: if stalled (low + slow),
##                climb to regain energy. Pure safety; nothing else in the field
##                has it.
##   2. GOALSIDE (rank 2) — when caught on the wrong side of the ball, arc around
##                to a behind-the-ball waypoint instead of lunging.
##   3. base strike for everything else (the line-up-then-commit core that
##                handbrake/goalside both build on and that actually scores).
##   4. CENTER   (rank 4, negative on its own) folded in MINIMALLY: only nudge the
##                committed strike toward goal-centre when the ball is genuinely
##                wide of the mouth, so we don't sail it into the side wall — but
##                we don't bias every shot (that was what made center passive).
##   5. handbrake (rank 1) brake + slow, attached directly with their standalone
##                thresholds; only suppressed while RECOVERing (braking = stall).

# goalside arc tuning.
const ARC_TRIGGER := 0.05    # below this behindness we're "goalside"
const ARC_LATERAL := 16.0
const ARC_BACK := 14.0
# center wide-correction.
const GOAL_HALF_WIDTH := 40.0

# Set each frame so brake/slow can suppress themselves while recovering/arcing.
var _recovering: bool = false
var _arcing: bool = false


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var gp: Vector3 = ctx["gp"]
	var speed: float = ctx["speed"]
	var bp: Vector3 = ctx["bp"]

	# 1. RECOVER (fsm): stalled — too low AND too slow, or pinned on a wall. Climb
	# and build energy, steering back toward arena centre if we're near a wall.
	var near_wall: bool = absf(gp.x) > 108.0 or absf(gp.z) > 188.0
	var stalled: bool = (gp.y < 22.0 and speed < 16.0) or (near_wall and speed < 18.0)
	_recovering = stalled
	if stalled:
		var flat: Vector3
		if near_wall:
			flat = Vector3(-gp.x, 0.0, -gp.z)
		else:
			var fwd: Vector3 = ctx["nose"]
			flat = Vector3(fwd.x, 0.0, fwd.z)
		if flat.length() < 0.1:
			flat = -ctx["shoot_dir"]
		flat = flat.normalized()
		var aim: Vector3 = gp + flat * 30.0
		aim.y = gp.y + 40.0
		return aim

	# 2. GOALSIDE: wrong side of the ball -> arc around rather than lunge. Mark it
	# so brake/slow back off and let the arc flow instead of fighting it.
	var behindness: float = ctx["behindness"]
	if behindness < ARC_TRIGGER:
		_arcing = true
		return _goalside_arc(gp, bp, ctx["shoot_dir"], behindness)
	_arcing = false

	# 3. base strike (line up / commit), then 4. center wide-correction.
	var aim: Vector3 = super._compute_aim(glider, ball, ctx)
	return _center_correct(aim, ctx)


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


## center, folded in MINIMALLY: only when the ball is wide of the goal mouth,
## rotate the committed aim a bit toward the goal-centre line so the strike
## sweeps the ball back toward x~0 instead of into the side wall. Repositioning
## (aim behind the ball) is left untouched so we don't go passive.
func _center_correct(aim: Vector3, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	if absf(bp.x) <= GOAL_HALF_WIDTH:
		return aim
	# Only adjust the committed strike (aim is out past the ball toward goal).
	var goal: Vector3 = ctx["goal"]
	var committed: bool = ctx["behindness"] > 0.55 and ctx["dist"] < 30.0
	if not committed:
		return aim
	var to_center: Vector3 = Vector3(goal.x - bp.x, 0.0, goal.z - bp.z)
	if to_center.length() < 0.1:
		return aim
	to_center = to_center.normalized()
	# Blend the existing strike direction toward goal-centre; the wider the ball,
	# the stronger (capped) the inward correction.
	var strike: Vector3 = Vector3(aim.x - bp.x, 0.0, aim.z - bp.z)
	var reach: float = strike.length()
	if reach < 0.1:
		return aim
	strike = strike.normalized()
	var wide: float = clampf((absf(bp.x) - GOAL_HALF_WIDTH) / 40.0, 0.0, 1.0)
	var cw: float = lerpf(0.0, 0.45, wide)
	var blended: Vector3 = (strike * (1.0 - cw) + to_center * cw)
	if blended.length() < 0.1:
		return aim
	blended = blended.normalized()
	var out: Vector3 = bp + blended * reach
	out.y = aim.y
	return out


# Analog handbrake; suppressed (0) while recovering or arcing goalside.
func _brake_amount(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	if _recovering:
		return 0.0
	var speed: float = ctx["speed"]
	if speed < 15.0:
		return 0.0
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	# While arcing goalside, let the arc do the repositioning — don't also
	# handbrake-pivot, or the two fight and we stall the turn.
	if _arcing:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())
	var threshold: float = 0.3 + rng.randf_range(-0.05, 0.05)
	return smoothstep(threshold + 0.25, threshold - 0.25, facing)


func _decide_slow(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	if _recovering or _arcing:
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
