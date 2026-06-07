extends Node3D

@export var mouse_sensitivity: float = 0.0012
@export var stick_sensitivity: float = 3.0  # radians/sec at full deflection
@export var min_pitch: float = -1.4
@export var max_pitch: float = 1.4


@export var target: Node3D

var yaw: float = 0.0
var pitch: float = 0.0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	yaw = rotation.y
	pitch = rotation.x


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		#pitch = clamp(pitch, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	# Right stick: analog rotation. Magnitude of deflection scales pan speed,
	# integrated per frame (a stick reports a held position, not a delta).
	var stick := Vector2(
		Input.get_axis("cam_left", "cam_right"),
		Input.get_axis("cam_up", "cam_down"))
	if stick != Vector2.ZERO:
		yaw -= stick.x * stick_sensitivity * delta
		pitch -= stick.y * stick_sensitivity * delta
		pitch = clamp(pitch, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0.0)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target := target.position - position
	var sped := 0.2 + 3.0 * to_target.length() + 2.0 * to_target.length()**2
	position = position.move_toward(target.position, sped * delta)
