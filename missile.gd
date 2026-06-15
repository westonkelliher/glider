extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# point the nose (-Z) along the direction of travel
	if velocity.length_squared() > 0.001:
		look_at(global_position + velocity)

	move_and_slide()

func launch(v: Vector3) -> void:
	velocity = v
