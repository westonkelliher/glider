extends TutorialStage
## Stage 3 — Trade Altitude. The "aha" stage: altitude IS speed. Diving converts
## potential energy (height) into speed; climbing spends speed to gain height.
## Two parts: (1) dive into the valley to build speed past a threshold, then
## (2) convert that speed back into altitude by climbing through a high ring.

const DIVE_SPEED_TARGET: float = 30.0

var _high_gate: TutGate = null
var _dive_done: bool = false
var _speed: float = 0.0


func stage_title() -> String:
	return "3 · Trade Altitude"


func intro_lines() -> Array[String]:
	return [
		"Altitude turns into speed.",
		"DIVE into the valley to trade height for speed.",
		"Then use that speed to climb through the high ring.",
	]


func start_pose() -> Transform3D:
	# High and nearly level, nose forward (-Z) with a slight downward bias so the
	# dive is a deliberate push, not a free fall.
	return pose_facing(Vector3(0.0, 70.0, 80.0), Vector3(0.0, -0.12, -1.0))


func par_time() -> float:
	return 18.0


func build() -> void:
	var nose: Vector3 = Vector3(0.0, -1.0, -1.0).normalized()
	# (1) Low gate at the bottom of the valley — reaching it requires diving ~55m.
	var low_gate: TutGate = TutGate.make(Vector3(0.0, 12.0, 10.0), nose, 10.0)
	low_gate.glider = glider
	add_child(low_gate)
	# (2) High gate beyond the valley — only reachable by trading dive speed back
	# into altitude (climb of ~43m from the valley floor).
	var climb_dir: Vector3 = Vector3(0.0, 1.0, -1.0).normalized()
	_high_gate = TutGate.make(Vector3(0.0, 55.0, -70.0), climb_dir, 11.0)
	_high_gate.glider = glider
	_high_gate.passed.connect(_on_high_gate_passed)
	add_child(_high_gate)
	_update_objective()


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	var seed: float = 12.0
	glider.velocity = nose * seed
	glider.pot_height = glider.global_position.y + seed * seed / (2.0 * Glider.G)
	ui.set_hint("Point the nose down and dive to build speed.")


func update(_delta: float) -> void:
	_speed = glider.velocity.length()
	if not _dive_done:
		if _speed >= DIVE_SPEED_TARGET:
			_dive_done = true
			ui.set_hint("Now pull up and turn that speed back into height.")
		# Floor guard: only bites before the dive earns its speed.
		elif glider.global_position.y < 4.0:
			failed.emit("hit the ground before building speed")
			return
	_update_objective()


func _on_high_gate_passed() -> void:
	# Only counts once the player has actually traded altitude for speed first.
	if _dive_done:
		completed.emit()


func _update_objective() -> void:
	if not _dive_done:
		ui.set_objective("① Dive to %d m/s (now %d)" % [int(DIVE_SPEED_TARGET), int(_speed)])
	else:
		ui.set_objective("② Climb through the high ring")
