extends AiBase
## Defensive striker: when our own goal is threatened, race goal-side of the ball
## and clear it away from our net; otherwise fall back to the base attacker.
##
## Our target goal mirrors to our own goal: own_goal.z = -target_goal.z.
## We treat the ball as a THREAT when it is in our defensive half (the own-goal
## side of midfield) and/or carrying velocity toward our own goal. Threatened, we
## position between the ball and our own goal and aim to punt it back to midfield.

const THREAT_DEPTH := 20.0      # buffer past midfield (into attacking half) before reacting
const GOAL_SIDE_OFFSET := 14.0  # stand this far goal-side of the ball
const CLEAR_REACH := 30.0       # drive this far through the ball when clearing


func _own_goal(glider: Glider) -> Vector3:
	return Vector3(0.0, 15.0, -glider.target_goal.z)


## True when the ball threatens our own goal: it sits in our defensive half or is
## moving toward our net. `to_own` is the (signed) z-direction toward our goal.
func _is_threatened(_glider: Glider, ctx: Dictionary, own_goal: Vector3) -> bool:
	var bp: Vector3 = ctx["bp"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	var to_own_z: float = signf(own_goal.z)            # +1 if own goal at +Z, else -1
	# Ball is on our half when its z, projected toward our goal, is past midfield.
	var ball_depth: float = bp.z * to_own_z            # >0 means ball on our side
	var on_our_half: bool = ball_depth > -THREAT_DEPTH
	# Ball heading toward our goal (its z-velocity points the same way as to_own).
	var closing: bool = ball_vel.z * to_own_z > 3.0
	return on_our_half or closing


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var own_goal: Vector3 = _own_goal(glider)
	if not _is_threatened(glider, ctx, own_goal):
		return super._compute_aim(glider, ball, ctx)

	var bp: Vector3 = ctx["bp"]
	var ball_flat := Vector3(bp.x, 0.0, bp.z)
	var own_flat := Vector3(own_goal.x, 0.0, own_goal.z)

	# Direction from ball toward our own goal (the side we must defend).
	var to_goal: Vector3 = own_flat - ball_flat
	var goal_dir: Vector3 = Vector3.FORWARD
	if to_goal.length() > 0.1:
		goal_dir = to_goal.normalized()

	# Clear direction = away from our goal, biased to a sideline so we don't punt
	# it straight back into a dangerous central area.
	var clear_dir: Vector3 = -goal_dir
	var side: float = signf(bp.x)
	if absf(side) < 0.01:
		side = 1.0 if ctx["gp"].x >= 0.0 else -1.0
	var side_bias := Vector3(side, 0.0, 0.0)
	var clear_blend: Vector3 = clear_dir + side_bias * 0.5
	if clear_blend.length() > 0.1:
		clear_dir = clear_blend.normalized()

	# If we are already goal-side of the ball and lined up, commit a clearing
	# strike straight through it; otherwise get to the goal-side staging point.
	var from_ball: Vector3 = Vector3(ctx["gp"].x, 0.0, ctx["gp"].z) - ball_flat
	var goal_side: float = -1.0
	if from_ball.length() > 0.1:
		goal_side = from_ball.normalized().dot(goal_dir)  # 1 = between ball and own goal

	var aim: Vector3
	if goal_side > 0.3 and ctx["dist"] < 26.0:
		aim = bp + clear_dir * CLEAR_REACH  # punt it away
		aim.y = bp.y
	else:
		# Stage goal-side of the ball, slightly low so a dive feeds the clear.
		aim = bp + goal_dir * GOAL_SIDE_OFFSET
		aim.y = bp.y - 1.0
	return aim


func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	var own_goal: Vector3 = _own_goal(glider)
	# When defending and not yet goal-side of the ball, sprint back to beat it.
	if _is_threatened(glider, ctx, own_goal):
		var ball_flat := Vector3(ctx["bp"].x, 0.0, ctx["bp"].z)
		var own_flat := Vector3(own_goal.x, 0.0, own_goal.z)
		var goal_dir: Vector3 = own_flat - ball_flat
		var from_ball: Vector3 = Vector3(ctx["gp"].x, 0.0, ctx["gp"].z) - ball_flat
		var goal_side: float = -1.0
		if from_ball.length() > 0.1 and goal_dir.length() > 0.1:
			goal_side = from_ball.normalized().dot(goal_dir.normalized())
		if goal_side < 0.3:
			var desired: Vector3 = aim - glider.global_position
			if desired.length() > 0.1 and ctx["nose"].dot(desired.normalized()) > 0.1:
				return true
	return super._decide_boost(glider, ball, ctx, aim)
