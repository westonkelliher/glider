extends Camera3D
## Camera3D CHILD on a swivel around the rig pivot.
## Yaw is set to the target's Y-rotation EVERY tick with no smoothing, so the
## camera snaps around to stay behind the player as they turn (rotation snappy),
## while the parent rig glides the position (movement smooth).

@export var target: Node3D
## Local offset from the pivot: behind (+Z) and above (+Y).
@export var offset: Vector3 = Vector3(0.0, 4.0, 8.0)

const YAW_SNAP := 10.0

func _physics_process(delta: float) -> void:
	if target == null:
		return
	# Swivel pivot == player's Y rotation, applied instantly.
	var yaw: float = target.rotation.y
	# Position relative to the rig (rig sits at the player's position).
	var t_position := Basis(Vector3.UP, yaw) * offset
	var p_delt := t_position - position
	var snap_speed := 0.1 + p_delt.length()*YAW_SNAP
	position = position.move_toward(t_position, snap_speed * delta)
	# Look at the pivot (rig origin == player position).
	look_at(get_parent().global_position, Vector3.UP)
