extends AiBase
## Opponent-aware striker. When the other glider is clearly winning the ball we
## stop contesting head-on and instead drop goal-side / cut off their clear; when
## we are favored we attack normally (base striker). Small avoidance offset keeps
## us from plowing through the opponent when we are not the one striking.


func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	var opp: Node = ctx["opponent"]
	if opp == null:
		return super._compute_aim(glider, ball, ctx)

	var bp: Vector3 = ctx["bp"]
	var gp: Vector3 = ctx["gp"]
	var goal: Vector3 = ctx["goal"]
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	var behindness: float = ctx["behindness"]
	var dist: float = ctx["dist"]

	# Opponent's standing relative to the ball.
	var opp_pos: Vector3 = opp.global_position
	var opp_dist: float = Vector3(opp_pos.x, 0.0, opp_pos.z).distance_to(Vector3(bp.x, 0.0, bp.z))

	# How well the opponent is lined up to strike (they attack the OTHER goal,
	# i.e. opposite to our shoot_dir). 1 == perfectly behind ball for their shot.
	var opp_from_ball: Vector3 = Vector3(opp_pos.x, 0.0, opp_pos.z) - Vector3(bp.x, 0.0, bp.z)
	var opp_behindness: float = -1.0
	if opp_from_ball.length() > 0.1:
		opp_behindness = opp_from_ball.normalized().dot(shoot_dir)

	# We are losing the race if the opponent is MUCH closer AND well lined up to
	# strike it back toward our half, and we ourselves are not already committing.
	# Kept strict so we don't bail out of attacks we could win. dist guarded below.
	var safe_dist: float = maxf(dist, 0.5)
	var striking: bool = behindness > 0.55 and dist < 30.0
	# Only worth dropping back when the ball is on the half we DEFEND (the side of
	# centre opposite our attacking goal); otherwise pressing forward is correct.
	var ball_in_our_half: bool = bp.z * goal.z < 0.0
	var opp_winning: bool = (opp_dist < safe_dist * 0.5) and (opp_behindness > 0.6) \
		and (opp_dist < 22.0) and ball_in_our_half and not striking
	var we_favored: bool = striking or (safe_dist <= opp_dist)

	if we_favored or not opp_winning:
		# Attack normally, but nudge off the opponent if it sits on our path and we
		# are not yet committing a strike (avoid wrecking our own setup).
		var aim: Vector3 = super._compute_aim(glider, ball, ctx)
		if not striking:
			var to_opp: Vector3 = Vector3(opp_pos.x, 0.0, opp_pos.z) - Vector3(gp.x, 0.0, gp.z)
			var to_aim: Vector3 = Vector3(aim.x - gp.x, 0.0, aim.z - gp.z)
			var opp_near: float = to_opp.length()
			if opp_near > 0.5 and opp_near < 18.0 and to_aim.length() > 0.5:
				# Is the opponent roughly ahead of us toward our aim?
				if to_opp.normalized().dot(to_aim.normalized()) > 0.6:
					# Sidestep perpendicular to our heading, sign chosen randomly but
					# biased away from the opponent.
					var perp: Vector3 = Vector3(-to_aim.z, 0.0, to_aim.x).normalized()
					if perp.dot(to_opp) > 0.0:
						perp = -perp
					var jitter: float = 1.0 + rng.randf_range(-0.2, 0.2)
					aim += perp * (10.0 * jitter)
		return aim

	# --- Opponent is winning the ball: don't contest head-on. ---
	# Drop GOAL-SIDE: get between the ball and the goal WE DEFEND (the opposite
	# end from the goal we attack), on the line the opponent would clear through,
	# so we can intercept the clear and stay ready to pounce on a loose ball.
	var ball_flat: Vector3 = Vector3(bp.x, 0.0, bp.z)
	# Our defensive goal mouth is the mirror of our attacking goal across centre.
	var def_goal: Vector3 = Vector3(0.0, 0.0, -goal.z)
	var to_def: Vector3 = def_goal - ball_flat
	var cover_dir: Vector3 = -shoot_dir   # away from attacking goal == toward defence
	if to_def.length() > 0.1:
		cover_dir = to_def.normalized()

	# Sit on the ball->our-goal line, ball-side of midway, so we shade the lane
	# without abandoning the ball entirely.
	var intercept: Vector3 = ball_flat + cover_dir * 14.0
	# Pull slightly toward our goal's centre so we cover the dangerous middle.
	intercept.x = lerpf(intercept.x, 0.0, 0.3)
	var jitter2: float = rng.randf_range(-3.0, 3.0)
	intercept.x += jitter2
	intercept.y = bp.y
	return intercept
