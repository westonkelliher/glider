extends Node3D

@export var mouse_sensitivity: float = 0.0012
@export var stick_sensitivity: float = 3.0  # radians/sec at full deflection
@export var min_pitch: float = -1.4
@export var max_pitch: float = 1.4
@export var rotate_lerp: float = 5.0  # how fast ball/velocity cams swing to aim

@export var target: Node3D
@export var ball: Node3D

# FREE: manual mouse/stick aim. BALL: keep the ball framed (RL ball cam).
# VELOCITY: look down the glider's travel direction (RL default cam).
enum Mode { FREE, BALL, VELOCITY }
var mode: Mode = Mode.FREE

var yaw: float = 0.0
var pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	yaw = rotation.y
	pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Any mouse aim drops back to free cam.
		mode = Mode.FREE
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		rotation = Vector3(pitch, yaw, 0.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("cam_free"):
		_sync_free_from_rotation()
		mode = Mode.FREE
	elif Input.is_action_just_pressed("cam_ball_toggle"):
		# Toggle between the two follow cams; entering from free starts on ball.
		mode = Mode.VELOCITY if mode == Mode.BALL else Mode.BALL

	match mode:
		Mode.FREE:
			_process_free(delta)
		Mode.BALL:
			_aim_at(_ball_aim_point(), delta)
		Mode.VELOCITY:
			_aim_at(position + _velocity_dir(), delta)


func _process_free(delta: float) -> void:
	# Right stick: analog rotation. Magnitude scales pan speed, integrated per
	# frame (a stick reports a held position, not a delta).
	var stick := Vector2(
		Input.get_axis("cam_left", "cam_right"),
		Input.get_axis("cam_up", "cam_down"))
	if stick != Vector2.ZERO:
		yaw -= stick.x * stick_sensitivity * delta
		pitch -= stick.y * stick_sensitivity * delta
		pitch = clamp(pitch, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0.0)


# Smoothly swing the rig so its -Z forward points at `look_point`.
func _aim_at(look_point: Vector3, delta: float) -> void:
	var dir := look_point - global_position
	if dir.length_squared() < 0.0001:
		return
	var goal := Basis.looking_at(dir, Vector3.UP)
	transform.basis = transform.basis.slerp(goal, clampf(rotate_lerp * delta, 0.0, 1.0)).orthonormalized()


func _ball_aim_point() -> Vector3:
	if ball != null:
		return ball.global_position
	return global_position - global_transform.basis.z


func _velocity_dir() -> Vector3:
	if target is CharacterBody3D and (target as CharacterBody3D).velocity.length() > 1.0:
		return (target as CharacterBody3D).velocity.normalized()
	if target != null:
		return -target.global_transform.basis.z  # fall back to glider heading
	return -global_transform.basis.z


# Re-read yaw/pitch from the current orientation so re-entering free cam
# doesn't snap the view.
func _sync_free_from_rotation() -> void:
	yaw = rotation.y
	pitch = clamp(rotation.x, min_pitch, max_pitch)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target := target.position - position
	var sped := 0.2 + 3.0 * to_target.length() + 2.0 * to_target.length()**2
	position = position.move_toward(target.position, sped * delta)
