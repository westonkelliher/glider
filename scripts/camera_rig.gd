extends Node3D

@export var mouse_sensitivity: float = 0.0012
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
		pitch = clamp(pitch, min_pitch, max_pitch)
		rotation = Vector3(pitch, yaw, 0.0)
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var to_target := target.position - position
	var sped := 0.2 + to_target.length()*5.0
	position = position.move_toward(target.position, sped * delta)
