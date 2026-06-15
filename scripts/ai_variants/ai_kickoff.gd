extends AiBase
## Dedicated kickoff-rush striker.
##
## After each goal the ball resets near center field and moves slowly. In that
## window the fastest, most central first touch usually wins the exchange. This
## variant detects that "kickoff-like" state (ball near center + slow) and
## commits a boosted, CENTERED rush: it aims straight through the ball toward
## the goal center so the contact is a strong, on-target shot, and it gets there
## before the opponent. Outside kickoff states it plays exactly like base.


## True when the ball looks like a fresh, slow, center-field kickoff.
func _is_kickoff(ctx: Dictionary) -> bool:
	var bp: Vector3 = ctx["bp"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	var near_center: bool = absf(bp.x) < 55.0 and absf(bp.z) < 55.0
	var slow: bool = ball_vel.length() < 12.0
	return near_center and slow


## During a kickoff: aim straight through the ball toward the goal center so the
## first contact drives the ball centrally at the mouth. We bias the contact
## point slightly past the ball along the (ball -> goal-center) line so we don't
## decelerate into it.
func _compute_aim(glider: Glider, ball: Node3D, ctx: Dictionary) -> Vector3:
	if not _is_kickoff(ctx):
		return super._compute_aim(glider, ball, ctx)

	var bp: Vector3 = ctx["bp"]
	var goal: Vector3 = ctx["goal"]
	# Direction from the ball to the CENTER of the target goal (horizontal).
	var to_goal: Vector3 = Vector3(goal.x - bp.x, 0.0, goal.z - bp.z)
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	if to_goal.length() > 0.1:
		shoot_dir = to_goal.normalized()

	# Are we already on the correct (defensive) side of the ball to strike
	# toward goal, or do we need to swing behind it first?
	var behindness: float = ctx["behindness"]

	var aim: Vector3
	if behindness > 0.2:
		# Lined up enough: commit a strike straight through the ball toward the
		# goal center. Reaching well past the ball keeps us accelerating into it.
		aim = bp + shoot_dir * 30.0
		aim.y = bp.y
	else:
		# Not behind yet: dive to a point just behind the ball (on the line back
		# from the goal) so the next frame we can strike through it centrally.
		aim = bp - shoot_dir * 14.0
		# Dive slightly to build speed from potential energy for the rush.
		aim.y = bp.y - 4.0

	# Keep a touch of randomness (base also adds aim_noise); jitter the contact
	# point laterally so repeated kickoffs aren't identical, but stay centered.
	aim.x += rng.randfn(0.0, 1.0)
	return aim


## Boost hard through the kickoff rush so we win the ball first and hit it with
## energy. Outside kickoff, defer to base's boost logic.
func _decide_boost(glider: Glider, ball: Node3D, ctx: Dictionary, aim: Vector3) -> bool:
	if not _is_kickoff(ctx):
		return super._decide_boost(glider, ball, ctx, aim)

	# Only boost when roughly facing the aim point, so we don't accelerate the
	# wrong way while swinging behind the ball.
	var desired: Vector3 = aim - glider.global_position
	if desired.length() < 0.1:
		return true
	var nose: Vector3 = ctx["nose"]
	var facing: float = nose.dot(desired.normalized())
	return facing > 0.1
