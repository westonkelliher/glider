extends AiBase
## Finite-state-machine striker. Each frame we pick a state from the context and
## drive aim/boost/brake/slow off it. States, in priority order:
##   RECOVER : stalled (low altitude AND low speed) -> climb + boost to regain
##             potential energy. Hysteresis keeps it from flip-flopping.
##   DEFEND  : ball in our defensive half / heading at our own goal -> get
##             goal-side of the ball and clear it back upfield.
##   LINEUP  : on the wrong side of the ball (behindness < 0) -> arc around to a
##             behind-the-ball point; handbrake when badly misaligned.
##   COMMIT  : lined up behind and close -> centered strike through the ball
##             toward the goal mouth (x ~ 0), aimed at the predicted ball pos.
##   CHASE   : otherwise -> approach a behind-the-ball point on the predicted ball.

const ST_CHASE := 0
const ST_LINEUP := 1
const ST_COMMIT := 2
const ST_DEFEND := 3
const ST_RECOVER := 4

var _state: int = ST_CHASE


## Pick the state for this frame from context (with recover hysteresis).
func _pick_state(glider: Glider, ctx: Dictionary) -> int:
	var gp: Vector3 = ctx["gp"]
	var bp: Vector3 = ctx["bp"]
	var speed: float = ctx["speed"]
	var behindness: float = ctx["behindness"]
	var dist: float = ctx["dist"]
	var goal: Vector3 = ctx["goal"]

	# Jammed against a wall/corner at low speed is its own kind of stall.
	var near_wall: bool = absf(gp.x) > 108.0 or absf(gp.z) > 188.0
	var wall_pinned: bool = near_wall and speed < 18.0

	# RECOVER with hysteresis: enter when truly stalled, stay until comfortably
	# re-energised so we don't oscillate against the chase/commit states.
	var stalled_enter: bool = (gp.y < 22.0 and speed < 16.0) or wall_pinned
	var stalled_stay: bool = (gp.y < 30.0 and speed < 24.0) or (near_wall and speed < 22.0)
	if _state == ST_RECOVER:
		if stalled_stay:
			return ST_RECOVER
	elif stalled_enter:
		return ST_RECOVER

	# DEFEND: our own goal is the mirror of target_goal in z. If the ball is on
	# our side (between centre and our goal) or moving toward our goal, defend.
	var own_goal: Vector3 = Vector3(0.0, 15.0, -goal.z)
	var goal_sign: float = signf(goal.z)            # +1 if we attack +z
	var ball_on_our_side: bool = bp.z * goal_sign < -20.0
	var ball_vel: Vector3 = ctx["ball_vel"]
	var heading_own: bool = ball_vel.z * goal_sign < -6.0 and bp.z * goal_sign < 40.0
	if ball_on_our_side or heading_own:
		return ST_DEFEND

	# COMMIT: lined up behind and within striking range.
	if behindness > 0.5 and dist < 32.0:
		return ST_COMMIT

	# LINEUP: wrong side of the ball, or not yet behind it.
	if behindness < 0.25:
		return ST_LINEUP

	return ST_CHASE


## Predict where the ball will be after `t` seconds (flat-ish lead).
func _predict(bp: Vector3, ball_vel: Vector3, t: float) -> Vector3:
	return bp + ball_vel * t


## A point behind the ball along the shoot direction, slightly low so we tend to
## come up underneath / level rather than diving past.
func _behind_point(bp: Vector3, shoot_dir: Vector3, back: float) -> Vector3:
	var p: Vector3 = bp - shoot_dir * back
	p.y = bp.y - 1.0
	return p


func _compute_aim(glider: Glider, _ball: Node3D, ctx: Dictionary) -> Vector3:
	_state = _pick_state(glider, ctx)
	var bp: Vector3 = ctx["bp"]
	var gp: Vector3 = ctx["gp"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var goal: Vector3 = ctx["goal"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	var dist: float = ctx["dist"]
	var speed: float = ctx["speed"]
	var aim: Vector3

	if _state == ST_RECOVER:
		# Climb and build energy. If we're near a wall, steer the horizontal
		# component back toward arena centre so we don't grind the boundary.
		var near_wall: bool = absf(gp.x) > 100.0 or absf(gp.z) > 180.0
		var flat: Vector3
		if near_wall:
			flat = Vector3(-gp.x, 0.0, -gp.z)
		else:
			var fwd: Vector3 = ctx["nose"]
			flat = Vector3(fwd.x, 0.0, fwd.z)
		if flat.length() < 0.1:
			flat = -shoot_dir
		flat = flat.normalized()
		aim = gp + flat * 30.0
		aim.y = gp.y + 40.0
		return aim

	if _state == ST_DEFEND:
		# Get goal-side of the ball (between ball and our goal) then clear it
		# back upfield toward the opponent goal.
		var own_goal: Vector3 = Vector3(0.0, 15.0, -goal.z)
		var clear_dir: Vector3 = Vector3(bp.x, 0.0, bp.z) - Vector3(own_goal.x, 0.0, own_goal.z)
		if clear_dir.length() < 0.1:
			clear_dir = shoot_dir
		clear_dir = clear_dir.normalized()
		# Lead the ball a little so we meet it.
		var lead_t: float = clampf(dist / maxf(speed, 12.0), 0.0, 0.7)
		var future: Vector3 = _predict(bp, ball_vel, lead_t)
		# Aim just on the goal side of the ball, slightly low, to wedge it away.
		aim = future - clear_dir * 7.0
		aim.y = future.y - 1.0
		return aim

	if _state == ST_LINEUP:
		# Arc around to behind the ball. Add a lateral offset perpendicular to
		# the shoot dir, on whichever side we're already on, to swing wide
		# instead of charging through the ball's side.
		var perp: Vector3 = Vector3(-shoot_dir.z, 0.0, shoot_dir.x)
		var to_glider: Vector3 = Vector3(gp.x - bp.x, 0.0, gp.z - bp.z)
		var side: float = signf(perp.dot(to_glider))
		if side == 0.0:
			side = 1.0
		var lead_t: float = clampf(dist / maxf(speed, 12.0), 0.0, 0.5)
		var future: Vector3 = _predict(bp, ball_vel, lead_t)
		aim = _behind_point(future, shoot_dir, 16.0)
		aim += perp * side * 10.0
		return aim

	if _state == ST_COMMIT:
		# Centered strike: aim THROUGH the predicted ball toward the goal mouth
		# centre (x ~ 0), not toward the wide goal corners. Blend the goal-centre
		# direction with the shoot dir so we both go forward and recentre.
		var lead_t: float = clampf(dist / maxf(speed, 18.0), 0.0, 0.5)
		var future: Vector3 = _predict(bp, ball_vel, lead_t)
		var to_center: Vector3 = Vector3(0.0, 0.0, goal.z) - Vector3(future.x, 0.0, future.z)
		if to_center.length() < 0.1:
			to_center = shoot_dir
		to_center = to_center.normalized()
		# The wider the ball, the harder we bias toward goal centre so we don't
		# hammer it further into the side wall.
		var wide: float = clampf(absf(future.x) / 60.0, 0.0, 1.0)
		var cw: float = lerpf(0.55, 0.9, wide)
		var strike_dir: Vector3 = (to_center * cw + shoot_dir * (1.0 - cw))
		if strike_dir.length() < 0.1:
			strike_dir = shoot_dir
		strike_dir = strike_dir.normalized()
		aim = future + strike_dir * 26.0
		aim.y = future.y
		return aim

	# ST_CHASE: approach a behind-the-ball point on the predicted ball. When the
	# ball is wide, aim for a behind point that lines us up with goal CENTRE
	# rather than the (wide) ball->goal line, so the eventual strike recentres.
	var lead_t: float = clampf(dist / maxf(speed, 14.0), 0.0, 0.8)
	var future: Vector3 = _predict(bp, ball_vel, lead_t)
	var center_dir: Vector3 = Vector3(0.0, 0.0, goal.z) - Vector3(future.x, 0.0, future.z)
	if center_dir.length() < 0.1:
		center_dir = shoot_dir
	center_dir = center_dir.normalized()
	var wide: float = clampf(absf(future.x) / 60.0, 0.0, 1.0)
	var approach: Vector3 = (center_dir * wide + shoot_dir * (1.0 - wide))
	if approach.length() < 0.1:
		approach = shoot_dir
	approach = approach.normalized()
	aim = _behind_point(future, approach, 14.0)
	return aim


func _decide_boost(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return false
	var facing: float = ctx["nose"].dot(desired.normalized())
	var speed: float = ctx["speed"]
	match _state:
		ST_RECOVER:
			# Always boost while recovering, even pointing up.
			return facing > 0.0
		ST_COMMIT:
			# Drive hard through the ball when roughly facing it.
			return facing > 0.2
		ST_DEFEND:
			# Boost to beat the ball to the clearing point if behind on pace.
			return facing > 0.25 and (speed < 30.0 or ctx["dist"] > 25.0)
		ST_LINEUP:
			# Keep some pace while arcing, but not a full charge.
			return facing > 0.4 and speed < 24.0
		_:
			# CHASE
			var slow_or_far: bool = speed < 26.0 or desired.length() > 40.0
			return slow_or_far and facing > 0.3


func _brake_amount(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())
	var behindness: float = ctx["behindness"]
	match _state:
		ST_LINEUP:
			# Handbrake to snap around when badly misaligned (wrong side / aim
			# well off the nose), so we don't sail wide. Ramp on both cues.
			return maxf(smoothstep(0.1, -0.3, behindness), smoothstep(0.45, -0.05, facing))
		ST_DEFEND:
			# Sharp pivot to recover goal-side when pointing wrong way.
			return smoothstep(0.25, -0.25, facing)
		_:
			return 0.0


func _decide_slow(glider: Glider, _ball: Node3D, ctx: Dictionary, aim: Vector3) -> float:
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.001:
		return 0.0
	var facing: float = ctx["nose"].dot(desired.normalized())
	var speed: float = ctx["speed"]
	match _state:
		ST_COMMIT:
			# Don't bleed speed on the strike.
			return 0.0
		ST_RECOVER:
			return 0.0
		ST_LINEUP:
			# Ease off if going fast and aim is off the nose, to tighten the arc.
			if facing < 0.2 and speed > 26.0:
				return 0.5
			return 0.0
		_:
			return 0.0
