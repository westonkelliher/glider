extends TutorialStage
## Stage 1 — Hold to Glide. Teaches the primary control: holding the RIGHT
## TRIGGER extends the wings ("grip"), so the craft carves cleanly along its
## nose. Objective: fly through three wide gates. Reference implementation other
## stages template from.

const SPEED: float = 20.0

var _gates: Array[TutGate] = []
var _passed: int = 0


func stage_title() -> String:
	return "1 · Hold to Glide"


func intro_lines() -> Array[String]:
	return [
		"Hold the RIGHT TRIGGER to open your wings and glide.",
		"With wings out, you go where your nose points.",
		"Fly through all three rings.",
	]


func start_pose() -> Transform3D:
	# High up, nose pointing forward (-Z) and tilted gently down.
	return pose_facing(Vector3(0.0, 60.0, 60.0), Vector3(0.0, -0.18, -1.0))


func par_time() -> float:
	return 14.0


func build() -> void:
	var nose: Vector3 = Vector3(0.0, -0.18, -1.0).normalized()
	var positions: Array[Vector3] = [
		Vector3(0.0, 54.0, 20.0),
		Vector3(0.0, 46.0, -30.0),
		Vector3(0.0, 38.0, -80.0),
	]
	for p: Vector3 in positions:
		var g: TutGate = TutGate.make(p, nose, 9.0)
		g.glider = glider
		g.passed.connect(_on_gate_passed)
		add_child(g)
		_gates.append(g)
	_update_objective()


func on_begin() -> void:
	# Give a gentle forward push so the lesson is about holding grip, not diving.
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Right trigger = wings out (grip). Steer with the stick.")


func update(_delta: float) -> void:
	# Safety reset if the player flies far past / belly-flops the floor.
	if glider.global_position.y < 2.0 or glider.global_position.z < -160.0:
		failed.emit("flew off course")


func _on_gate_passed() -> void:
	_passed += 1
	_update_objective()
	if _passed >= _gates.size():
		completed.emit()


func _update_objective() -> void:
	ui.set_objective("Rings: %d / %d" % [_passed, _gates.size()])
