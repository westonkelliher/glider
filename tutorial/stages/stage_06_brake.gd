extends TutorialStage
## Stage 6 — Hard Brake. Teaches the LEFT TRIGGER ("slow_down"): pulling it
## actively bleeds off forward speed and height. The player flies in fast and
## must STOP inside a small landing box and hold still there.

# The glide model floors forward speed around ~4 m/s (the craft never fully
# stalls in the air), so the target must sit comfortably above that.
const SEED_SPEED: float = 18.0
const STOP_SPEED: float = 8.0
const DWELL_NEEDED: float = 0.5
const BOX_Z: float = -65.0

var _zone: TutZone = null
var _dwell: float = 0.0
# Big and long so there's runway to bleed off speed inside it.
var _box_size: Vector3 = Vector3(34.0, 30.0, 50.0)
var _idle_color: Color = Color(0.3, 0.6, 1.0)
var _hold_color: Color = Color(0.3, 1.0, 0.45)


func allow_boost() -> bool:
	return true


func allow_slow() -> bool:
	return true


func stage_title() -> String:
	return "6 · Hard Brake"


func intro_lines() -> Array[String]:
	return [
		"Pull the LEFT TRIGGER to brake hard — it bleeds off speed fast.",
		"Fly into the box ahead, then brake to a near-stop.",
		"Hold still inside the box to finish.",
	]


func start_pose() -> Transform3D:
	# High enough to glide in level toward the box at -Z.
	return pose_facing(Vector3(0.0, 40.0, 30.0), Vector3(0.0, 0.0, -1.0))


func par_time() -> float:
	return 12.0


func build() -> void:
	_zone = TutZone.make(Vector3(0.0, 40.0, BOX_Z), _box_size)
	_zone.glider = glider
	add_child(_zone)
	_zone.set_color(_idle_color)
	_update_objective(SEED_SPEED)


func on_begin() -> void:
	var nose: Vector3 = -glider.global_transform.basis.z.normalized()
	glider.velocity = nose * SEED_SPEED
	glider.pot_height = glider.global_position.y + SEED_SPEED * SEED_SPEED / (2.0 * Glider.G)
	ui.set_hint("Left trigger = hard brake. Stop inside the box.")


func update(delta: float) -> void:
	var speed: float = glider.velocity.length()
	var inside: bool = _zone.is_inside(glider.global_position)
	var holding: bool = inside and speed < STOP_SPEED

	if holding:
		_dwell += delta
		_zone.set_color(_hold_color)
	else:
		_dwell = 0.0
		_zone.set_color(_idle_color)

	_update_objective(speed)

	if _dwell >= DWELL_NEEDED:
		completed.emit()
		return

	# Only bail if they sail well past the box still carrying speed (press R to
	# retry); a gentle drift past is fine.
	if glider.global_position.z < BOX_Z - _box_size.z and speed > STOP_SPEED:
		failed.emit("overshot — brake earlier")
	elif glider.global_position.y < 2.0:
		failed.emit("hit the ground")


func _update_objective(speed: float) -> void:
	ui.set_objective("Stop inside the box — speed %.1f (need <%.0f)" % [speed, STOP_SPEED])
