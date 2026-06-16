extends TutorialStage
## Stage 5 — Boost. Teaches forward thrust: holding the BOOST button adds
## `nose * 50 * delta` to velocity each frame. The gate chain climbs uphill —
## gliding up a slope trades speed back into altitude and stalls out, so the
## only way to keep climbing through every ring and reach the top is to BOOST.

const SPEED: float = 16.0
const BASE_ALT: float = 18.0
const RISE: float = 10.0          # how much each successive gate climbs
const FLOOR_Y: float = 2.0
const GATE_RADIUS: float = 9.0
const GATE_SPACING: float = 45.0
const FIRST_GATE_Z: float = -45.0
const LAST_GATE_Z: float = -225.0
const SLOW_SPEED: float = 12.0

# Direction the player flies through the rising corridor (up and forward).
var _climb_dir: Vector3 = Vector3(0.0, RISE, -GATE_SPACING).normalized()


## Altitude of a gate at corridor depth `z` (gates step upward as z decreases).
func _alt_for_z(z: float) -> float:
	var step: float = (FIRST_GATE_Z - z) / GATE_SPACING + 1.0
	return BASE_ALT + RISE * step

var _gates: Array[TutGate] = []
var _finish: TutMarker = null
var _passed: int = 0
var _done: bool = false


func stage_title() -> String:
	return "5 · Boost"


func intro_lines() -> Array[String]:
	return [
		"Press and hold BOOST to fire your thrusters forward.",
		"The rings climb uphill — gliding up a slope bleeds speed and stalls.",
		"BOOST is the only way to power up the incline.",
		"Hold BOOST to climb through every ring and reach the top.",
	]


func start_pose() -> Transform3D:
	# Aimed up the slope so the player is already climbing from the start.
	return pose_facing(Vector3(0.0, BASE_ALT, 0.0), _climb_dir)


func par_time() -> float:
	return 15.0


func build() -> void:
	var z: float = FIRST_GATE_Z
	while z >= LAST_GATE_Z:
		var g: TutGate = TutGate.make(Vector3(0.0, _alt_for_z(z), z), _climb_dir, GATE_RADIUS)
		g.glider = glider
		g.passed.connect(_on_gate_passed)
		add_child(g)
		_gates.append(g)
		z -= GATE_SPACING
	# Finish marker one step further up the slope.
	var finish_z: float = LAST_GATE_Z - GATE_SPACING
	_finish = TutMarker.make(Vector3(0.0, _alt_for_z(finish_z), finish_z), 8.0)
	_finish.glider = glider
	_finish.reached.connect(_on_finish_reached)
	add_child(_finish)
	_update_objective()


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Hold BOOST to power up the slope — climbing bleeds speed.")


func update(_delta: float) -> void:
	if _done:
		return
	if glider.global_position.y < FLOOR_Y:
		_done = true
		failed.emit("dropped too low")
		return
	var speed: float = glider.velocity.length()
	if speed < SLOW_SPEED and not Input.is_action_pressed("boost"):
		ui.set_hint("Hold BOOST!")
	else:
		ui.set_hint("Hold BOOST to power up the slope.")


func _on_gate_passed() -> void:
	_passed += 1
	_update_objective()


func _on_finish_reached() -> void:
	if _done:
		return
	_done = true
	completed.emit()


func _update_objective() -> void:
	ui.set_objective("Gates: %d / %d  —  reach the finish, hold BOOST" % [_passed, _gates.size()])
