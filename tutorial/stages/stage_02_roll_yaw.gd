extends TutorialStage
## Stage (early) — Roll vs Yaw. Foundational lesson on the two ways the nose can
## move, taught one axis at a time so the difference is felt directly:
##
##   ROLL = bank the wings around the nose axis (the horizon tilts; nose stays
##          pointed the same way).
##   YAW  = swing the nose left/right while the craft stays level (the horizon
##          stays flat; the nose sweeps across the world).
##
## Phase 1: BANK past a roll threshold (tilt the wings) — measured from how far
##          the craft's up-vector leans off true vertical.
## Phase 2: level the wings, then YAW the nose to turn through a target heading,
##          flying through the goal ring set off to the side.
##
## Because each phase isolates one axis, the player learns that roll alone does
## not change where the nose points, and yaw alone changes heading without
## banking.

const SPEED: float = 18.0
## Bank past this many degrees (either direction) to clear the roll phase.
const ROLL_TARGET_DEG: float = 35.0
## Re-level the wings to under this bank before the yaw phase opens.
const LEVEL_DEG: float = 12.0

enum Phase { ROLL, LEVEL, YAW }

var _phase: int = Phase.ROLL
var _goal: TutGate = null
var _passed: bool = false


func stage_title() -> String:
	return "Roll vs Yaw"


func intro_lines() -> Array[String]:
	return [
		"ROLL and YAW move the craft in different ways.",
		"ROLL spins you around your nose. The wings tip over,",
		"but the nose keeps pointing the same way.",
		"YAW swings the nose left or right.",
		"Roll hard to feel it. Then level the wings and yaw",
		"the nose over to the side ring and fly through.",
	]


func start_pose() -> Transform3D:
	# High up, nose forward (-Z), level wings so the bank is obvious.
	return pose_facing(Vector3(0.0, 60.0, 40.0), Vector3(0.0, -0.06, -1.0))


func par_time() -> float:
	return 0.0  # Untimed: this is about feel, not speed.


func build() -> void:
	# Goal ring sits off to the LEFT and ahead, facing back toward the player so
	# the only way to line up is to YAW the nose left and fly through it.
	var goal_pos: Vector3 = Vector3(-46.0, 52.0, -34.0)
	var face: Vector3 = Vector3(0.6, 0.0, -1.0)
	_goal = TutGate.make(goal_pos, face, 10.0)
	_goal.glider = glider
	_goal.passed.connect(_on_goal_passed)
	add_child(_goal)
	# Dim it until the yaw phase so the player focuses on the roll first.
	_goal.set_color(Color(0.3, 0.35, 0.45))
	_update_objective()


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Roll: tilt the stick. The craft spins around its nose.")


func update(_delta: float) -> void:
	if glider.global_position.y < 2.0:
		failed.emit("flew off course")
		return

	var bank: float = _bank_degrees()
	match _phase:
		Phase.ROLL:
			if bank >= ROLL_TARGET_DEG:
				_phase = Phase.LEVEL
				ui.set_hint("Good roll! Now level the wings out.")
				_update_objective()
		Phase.LEVEL:
			if bank <= LEVEL_DEG:
				_phase = Phase.YAW
				_goal.set_color(Color(0.25, 0.8, 1.0))
				ui.set_hint("Yaw: swing the nose to the side ring and fly through.")
				_update_objective()
		Phase.YAW:
			if _passed:
				completed.emit()


## Bank angle in degrees: how far the craft's up-vector leans off true vertical.
func _bank_degrees() -> float:
	var up: Vector3 = glider.global_transform.basis.y.normalized()
	var dot: float = clampf(up.dot(Vector3.UP), -1.0, 1.0)
	return rad_to_deg(acos(dot))


func _on_goal_passed() -> void:
	_passed = true


func _update_objective() -> void:
	match _phase:
		Phase.ROLL:
			ui.set_objective("1. ROLL past %d°" % int(ROLL_TARGET_DEG))
		Phase.LEVEL:
			ui.set_objective("2. LEVEL the wings  (under %d°)" % int(LEVEL_DEG))
		Phase.YAW:
			ui.set_objective("3. YAW through the side ring")
