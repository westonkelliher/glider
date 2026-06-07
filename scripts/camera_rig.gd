extends Node3D
## Camera rig PARENT (the "empty" pivot).
## Smoothly follows the target's POSITION only. Rotation is handled by the
## Camera3D child (camera_swivel.gd) so position lags but rotation stays snappy.
## Runs in _physics_process to stay on the physics-interpolation timeline.

@export var target: Node3D
## Higher = snappier position follow. Exponential, frame-rate independent.
@export var follow_sharpness: float = 6.0

func _ready() -> void:
	if target == null:
		return
	global_position = target.global_position
	reset_physics_interpolation()  # avoid first-frame smear from origin

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var t: float = 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(target.global_position, t)
