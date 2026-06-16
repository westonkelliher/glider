extends TutorialStage
## Stage 2 — Steer. Teaches pitch / roll / yaw with a gentle banked S-bend
## slalom. Gates drift left then right (X) while descending gently (Y) and
## progressing forward (-Z); each gate's look_dir is tangent to the curve so the
## player must bank and turn smoothly to line them up.

const SPEED: float = 20.0
const RING_RADIUS: float = 9.0

var _gates: Array[TutGate] = []
var _passed: int = 0


func stage_title() -> String:
	return "2 · Steer"


func intro_lines() -> Array[String]:
	return [
		"Tilt the stick to pitch, roll, and yaw your craft.",
		"Bank into each turn to line up with the next ring.",
		"Weave the S-bend through all the gates.",
	]


func start_pose() -> Transform3D:
	# High up, nose forward (-Z) with a slight downward tilt.
	return pose_facing(Vector3(0.0, 60.0, 70.0), Vector3(0.0, -0.16, -1.0))


func par_time() -> float:
	return 16.0


func build() -> void:
	# Centres of an S curve: drift left, then right, descending while moving -Z.
	var positions: Array[Vector3] = [
		Vector3(0.0, 54.0, 20.0),
		Vector3(-18.0, 49.0, -28.0),
		Vector3(-22.0, 44.0, -78.0),
		Vector3(2.0, 39.0, -126.0),
		Vector3(24.0, 34.0, -174.0),
		Vector3(20.0, 29.0, -222.0),
	]
	for i: int in range(positions.size()):
		var p: Vector3 = positions[i]
		# look_dir = tangent of the curve (toward the next gate, or extrapolated
		# past the last one) so the ring faces the player's flight path.
		var look_dir: Vector3
		if i < positions.size() - 1:
			look_dir = positions[i + 1] - p
		else:
			look_dir = p - positions[i - 1]
		var g: TutGate = TutGate.make(p, look_dir.normalized(), RING_RADIUS)
		g.glider = glider
		g.passed.connect(_on_gate_passed)
		add_child(g)
		_gates.append(g)
	_update_objective()


func on_begin() -> void:
	# Gentle forward push so the lesson is about steering, not diving.
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Bank into the turn, then level out for the next ring.")


func update(_delta: float) -> void:
	# Safety reset if the player drops out of the course.
	if glider.global_position.y < 2.0:
		failed.emit("flew off course")


func _on_gate_passed() -> void:
	_passed += 1
	_update_objective()
	if _passed >= _gates.size():
		completed.emit()


func _update_objective() -> void:
	ui.set_objective("Gates: %d / %d" % [_passed, _gates.size()])
