extends AiBase
## Ball-prediction / interception striker.
##
## The base aims relative to the ball's CURRENT position, so it perpetually
## chases stale positions when the ball is moving. This variant computes a lead
## time `t` (how long it'll take to reach the ball given current speed) and aims
## relative to the PREDICTED ball position `predicted = bp + ball_vel * t`,
## reapplying the base's line-up-behind / commit-through logic about that point.


func _compute_aim(_glider: Glider, _ball: Node3D, ctx: Dictionary) -> Vector3:
	var bp: Vector3 = ctx["bp"]
	var ball_vel: Vector3 = ctx["ball_vel"]
	var dist: float = ctx["dist"]
	var speed: float = ctx["speed"]

	# Lead time: roughly how long to reach the ball at our current speed, capped
	# and scaled down so we refine the aim toward where the ball is heading
	# without over-predicting a curving ball (a full lead overshoots and
	# destabilises play).
	var t: float = clampf(dist / maxf(speed, 1.0), 0.0, 0.8) * 0.4
	var predicted: Vector3 = bp + ball_vel * t

	# Re-derive shoot direction toward goal from the PREDICTED ball position so
	# the commit line stays correct for where the ball will be.
	var goal: Vector3 = ctx["goal"]
	var pred_flat := Vector3(predicted.x, 0.0, predicted.z)
	var goal_flat := Vector3(goal.x, 0.0, goal.z)
	var to_goal: Vector3 = goal_flat - pred_flat
	var shoot_dir: Vector3 = ctx["shoot_dir"]
	if to_goal.length() > 0.1:
		shoot_dir = to_goal.normalized()

	# Behindness measured against the predicted intercept point.
	var gp: Vector3 = ctx["gp"]
	var from_pred: Vector3 = Vector3(gp.x, 0.0, gp.z) - pred_flat
	var behindness: float = ctx["behindness"]
	if from_pred.length() > 0.1:
		behindness = from_pred.normalized().dot(-shoot_dir)

	var aim: Vector3
	if behindness > 0.55 and dist < 30.0:
		aim = predicted + shoot_dir * 25.0   # committed: drive through toward goal
		aim.y = predicted.y
	else:
		aim = predicted - shoot_dir * 12.0   # reposition behind the predicted ball
		aim.y = predicted.y - 1.0
	return aim
