extends TutorialStage
## Stage 4 — Let Go to Drift. Reframes the control: the RIGHT TRIGGER is the
## primary input. Default (trigger NOT held) = handbrake ON = wings retracted =
## the craft DRIFTS (momentum slides, nose pivots sharply). Holding the trigger
## RELEASES the brake = wings extend = GRIP (velocity follows the nose).
##
## The signature move: RELEASE the trigger mid-turn to let the nose slide around
## a tight hairpin, then re-grip (squeeze) to launch out in the new direction.
## A near-180 hairpin around a pylon teaches this; it is only makeable by
## drifting the nose through the turn.

const SPEED: float = 22.0
const HAIRPIN_R: float = 22.0

var _gates: Array[TutGate] = []
var _passed: int = 0


func stage_title() -> String:
	return "4 · Let Go to Drift"


func intro_lines() -> Array[String]:
	return [
		"The RIGHT TRIGGER is your main control. Hold it = wings out = GRIP.",
		"Let it GO and the handbrake bites: wings retract and you DRIFT,",
		"sliding with your momentum while the nose snaps around fast.",
		"RELEASE the right trigger mid-turn to drift the nose around,",
		"then squeeze it again to launch out.",
		"Round the pylon through this tight hairpin and hit the exit ring.",
	]


func start_pose() -> Transform3D:
	# Down low on the approach, nose pointing forward (-Z), level.
	return pose_facing(Vector3(0.0, 14.0, 70.0), Vector3(0.0, 0.0, -1.0))


func par_time() -> float:
	return 17.0


func build() -> void:
	# Layout (top-down, +X right): fly forward (-Z) through the entry gate, round
	# the pylon on the right via a near-180 hairpin, then come back through the
	# exit gate heading roughly back the way we came (+Z).
	var forward: Vector3 = Vector3(0.0, 0.0, -1.0)
	var back: Vector3 = Vector3(0.0, 0.0, 1.0)

	# Entry gate: cross heading forward (-Z).
	var entry: TutGate = TutGate.make(Vector3(0.0, 14.0, 40.0), forward, 9.0)
	entry.glider = glider
	entry.passed.connect(_on_gate_passed)
	add_child(entry)
	_gates.append(entry)

	# Visible pylon to round, sitting at the apex of the hairpin.
	var pylon: TutMarker = TutMarker.make(Vector3(HAIRPIN_R, 14.0, -6.0), 7.0)
	pylon.glider = glider
	add_child(pylon)

	# Exit gate: cross heading back (+Z), offset to the right so the path is a
	# tight U-turn around the pylon rather than a straight pass-through.
	var exit: TutGate = TutGate.make(Vector3(HAIRPIN_R * 2.0, 14.0, 40.0), back, 9.0)
	exit.glider = glider
	exit.passed.connect(_on_gate_passed)
	add_child(exit)
	_gates.append(exit)

	_update_objective()


func on_begin() -> void:
	# Moderate seed speed so the lesson is the drift-pivot, not building pace.
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SPEED
	glider.pot_height = glider.global_position.y + SPEED * SPEED / (2.0 * Glider.G)
	ui.set_hint("Hold trigger to grip in. LET GO mid-turn to drift the nose around, then squeeze to shoot out.")


func update(_delta: float) -> void:
	if glider.global_position.y < 2.0:
		failed.emit("too low")


func _on_gate_passed() -> void:
	_passed += 1
	_update_objective()
	if _passed >= _gates.size():
		completed.emit()


func _update_objective() -> void:
	ui.set_objective("Gates: %d / %d" % [_passed, _gates.size()])
