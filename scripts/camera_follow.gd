extends Camera3D
## Smooth follow camera.
##
## Anti-jitter strategy (see notes at bottom):
##  - Project has Physics Interpolation enabled, so the engine interpolates
##    every node's RENDERED transform between physics ticks. This kills the
##    "render fps != physics fps" stepping that causes jitter.
##  - Therefore ALL follow logic lives in _physics_process (never _process),
##    so the camera and its target share the same snapshot timeline and the
##    engine interpolates them in lockstep.
##  - On spawn we position the camera, then reset_physics_interpolation() so
##    it doesn't smear/streak from the origin on the first rendered frame.

@export var target: Node3D
## World-space offset from the target (behind +Z and above).
@export var offset: Vector3 = Vector3(0.0, 8.0, 16.0)
## Higher = snappier follow. Exponential, frame-rate independent.
@export var follow_sharpness: float = 6.0

func _ready() -> void:
	if target == null:
		return
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)
	# Avoid a one-frame smear from the camera's initial/origin transform.
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if target == null:
		return
	var desired: Vector3 = target.global_position + offset
	var t: float = 1.0 - exp(-follow_sharpness * delta)
	global_position = global_position.lerp(desired, t)
	look_at(target.global_position, Vector3.UP)

# --- Why this avoids jitter ---
# Naive follow reads target.global_position in _process() (render rate, e.g.
# 144 Hz) while the body only moves in _physics_process() (60 Hz). The target
# is stale for several render frames then jumps a tick's worth -> visible
# jitter, made worse because the target mesh itself only updates at 60 Hz.
# Fix: enable Physics Interpolation (engine smooths rendered transforms
# between ticks) AND drive the camera in _physics_process so it lives on the
# same tick timeline. reset_physics_interpolation() prevents the startup smear.
