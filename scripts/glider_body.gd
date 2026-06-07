extends CharacterBody3D


const TURN_SPEED = 2.5  # radians/sec
const JUMP_VELOCITY = 4.5
const G := 9.8

var pot_height := 0.0
var PH_MARGIN := 0.1
## Pot Height Equation:
# v1 at h1,ph1 allows us to get to ph1 under g deceleration:
# dH = v1


func _physics_process(delta: float) -> void:
	
	if position.y > pot_height-0.5:
		pot_height = position.y+0.5
	
	var d_h := pot_height - position.y
	
	var speed := 0.0
	if d_h < PH_MARGIN:
		speed = 0.2
	else:
		speed = sqrt(d_h*G*2) # solved for speed in terms of d_h
	
	# Left/right rotate (yaw) the character; forward/back drive along facing.
	var roll := Input.get_axis("move_right", "move_left")
	rotation.z += roll * TURN_SPEED * delta

	var pitch := Input.get_axis("move_forward", "move_back")
	rotation.x += pitch * TURN_SPEED * delta
	#rotation.x = clampf(rotation.x, deg_to_rad(-89.0), deg_to_rad(89.0))
	
	var facing_dir := (transform.basis * Vector3.FORWARD).normalized()
	var v_dir := velocity.normalized()
	if v_dir:
		#var d_dir :=  
		v_dir = v_dir.move_toward(facing_dir, 1.0 * delta).normalized()
	else:
		v_dir = facing_dir
	
	velocity = v_dir * speed

	move_and_slide()
