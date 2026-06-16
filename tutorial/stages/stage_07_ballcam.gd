extends TutorialStage
## Stage 7 — Ball Cam. Teaches the camera toggle (Y / ▲, action "cam_ball_toggle")
## that locks the view onto the ball — essential for tracking it during play.
## The player engages ball-cam and keeps it on while flying near the ball.

const SPEED: float = 15.0
const BALL_POS: Vector3 = Vector3(0.0, 36.0, -55.0)
const HOLD_NEEDED: float = 4.0

var _ball: Node3D = null
var _hold: float = 0.0
var _engaged: bool = false


func allow_boost() -> bool:
	return true


func allow_slow() -> bool:
	return true


func stage_title() -> String:
	return "7 · Ball Cam"


func intro_lines() -> Array[String]:
	return [
		"Here's the ball. To play, you have to keep your eye on it.",
		"Press Y (▲) to lock the camera onto the ball. Press again to release.",
		"Turn on ball-cam and keep it on while you fly around the ball.",
	]


func start_pose() -> Transform3D:
	# Behind the ball, nose pointed at it.
	return pose_facing(Vector3(0.0, 36.0, 25.0), Vector3(0.0, 0.0, -1.0))


func par_time() -> float:
	return 0.0


func build() -> void:
	_ball = spawn_ball(BALL_POS)
	ui.set_objective("Press Y (▲) to lock the camera onto the ball.")


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Y (▲) toggles ball-cam. Keep the ball framed while you fly.")


func update(delta: float) -> void:
	# Keep the floating ball pinned in place (it has its own gravity/physics).
	if is_instance_valid(_ball):
		_ball.global_position = BALL_POS
		if _ball.has_method("set"):
			_ball.set("velocity", Vector3.ZERO)

	if ball_cam_on():
		_engaged = true
		_hold += delta
		var left: float = maxf(0.0, HOLD_NEEDED - _hold)
		ui.set_objective("Ball-cam locked, keep flying (%.1fs)" % left)
		ui.set_hint("The camera keeps the ball in view as you turn.")
		if _hold >= HOLD_NEEDED:
			completed.emit()
	else:
		if _engaged:
			ui.set_hint("Ball-cam off. Press Y (▲) to turn it back on.")
		ui.set_objective("Press Y (▲) to lock the camera onto the ball.")
