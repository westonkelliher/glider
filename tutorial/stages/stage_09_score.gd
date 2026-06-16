extends TutorialStage
## Stage 9 — Score (capstone). Combine everything: dive for speed, line up the
## ball, and drive it into the goal. Spawns a Ball (res://ball.tscn) ahead near
## the floor and a generous bluish TutZone goal behind it. The player arrives
## with seed speed and must strike the ball through the goal mouth.

const SPEED: float = 6.0

var _ball: Node3D = null
var _ball_start: Vector3 = Vector3(0.0, 2.4, -40.0)  # y = ball radius: resting on the floor
var _goal: TutZone = null
var _scored: bool = false


func allow_boost() -> bool:
	return true


func allow_slow() -> bool:
	return true


func stage_title() -> String:
	return "9 · Score"


func intro_lines() -> Array[String]:
	return [
		"The big finish — put it all together.",
		"Dive for speed, line up with ball-cam, and smash it into the goal.",
	]


func start_pose() -> Transform3D:
	# Up and back (+Z behind the ball), nose toward the ball/goal (-Z), tilted down.
	return pose_facing(Vector3(0.0, 50.0, 30.0), Vector3(0.0, -0.22, -1.0))


func par_time() -> float:
	return 0.0


func build() -> void:
	# The ball, registered with the camera so ball-cam tracks it.
	_ball = spawn_ball(_ball_start)
	_ball.set("velocity", Vector3.ZERO)  # cancel the default pop-up; rest it on the floor

	# The goal: a generous soccer-mouth zone past the ball, recolored bluish.
	_goal = TutZone.make(Vector3(0.0, 12.0, -90.0), Vector3(40.0, 24.0, 8.0))
	add_child(_goal)
	_goal.set_color(Color(0.35, 0.6, 1.0, 0.18))

	ui.set_objective("Strike the ball into the goal!")


func on_begin() -> void:
	# Seed speed so the player arrives with pace.
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Hold grip, dive in, and smash the ball forward.")


func update(_delta: float) -> void:
	if _scored:
		return
	if not is_instance_valid(_ball) or _goal == null:
		return

	if _goal.is_inside(_ball.global_position):
		_scored = true
		ui.set_objective("GOAL!")
		completed.emit()
		return

	# If the ball rolls far out of bounds, gently respawn it (no failure).
	var p: Vector3 = _ball.global_position
	if absf(p.x) > 80.0 or p.z > 30.0 or p.z < -130.0:
		_ball.global_position = _ball_start
		if _ball.has_method("set"):
			_ball.set("velocity", Vector3.ZERO)
