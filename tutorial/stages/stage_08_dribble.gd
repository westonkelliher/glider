extends TutorialStage
## Stage 8 — Dribble. Teaches controlled touches on the ball: approach gently and
## nudge it into a target ring off to one side (a straight smash overshoots, so
## the player has to steer the ball, not just hit it). Uses ball-cam from stage 7.

const SPEED: float = 14.0

var _ball: Node3D = null
var _ball_start: Vector3 = Vector3(0.0, 5.0, -40.0)
var _target: TutZone = null
var _target_pos: Vector3 = Vector3(26.0, 8.0, -78.0)
var _done: bool = false


func stage_title() -> String:
	return "8 · Dribble"


func intro_lines() -> Array[String]:
	return [
		"Now move the ball with control.",
		"Approach gently and nudge it — a full-speed smash will overshoot.",
		"Dribble the ball into the green ring.",
	]


func start_pose() -> Transform3D:
	# Up and back, nose toward the ball, gentle downward tilt.
	return pose_facing(Vector3(0.0, 30.0, 25.0), Vector3(0.0, -0.2, -1.0))


func par_time() -> float:
	return 0.0


func build() -> void:
	_ball = spawn_ball(_ball_start)
	_target = TutZone.make(_target_pos, Vector3(22.0, 16.0, 22.0))
	add_child(_target)
	_target.set_color(Color(0.3, 1.0, 0.45))
	ui.set_objective("Dribble the ball into the green ring.")


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Soft touches. Use ball-cam (Y/▲) to keep the ball in view.")


func update(_delta: float) -> void:
	if _done or not is_instance_valid(_ball) or _target == null:
		return

	if _target.is_inside(_ball.global_position):
		_done = true
		ui.set_objective("Nice touch!")
		completed.emit()
		return

	# Respawn the ball if it rolls far out of bounds (no failure).
	var p: Vector3 = _ball.global_position
	if absf(p.x) > 90.0 or p.z > 30.0 or p.z < -130.0:
		_ball.global_position = _ball_start
		if _ball.has_method("set"):
			_ball.set("velocity", Vector3.ZERO)
