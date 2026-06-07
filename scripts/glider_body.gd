extends CharacterBody3D


const TURN_SPEED = 2.5  # radians/sec
const JUMP_VELOCITY = 4.5
const G := 9.8


## Ailerons
const AIL_PITCH_SPEED := 7.0 # radians/s
const PITCH_MULT := 3.5
# TODO: yaw and roll
var ail_pitch := 0.0
var ail_pitch_target := 0.0
# TODO: yaw and roll


## Pot Height
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
	
	# adjust ailerons
	adjust_ailerons(delta)
	
	# L/R yaws by default, but rolls while air_roll is held (RL-style).
	# Pitch is always about the craft's own right axis. All local-axis based,
	# so control is relative to the glider's orientation, not the world axes.
	var lr := Input.get_axis("move_right", "move_left")
	if Input.is_action_pressed("air_roll"):
		rotate_object_local(Vector3.BACK, lr * TURN_SPEED * delta)
	else:
		rotate_object_local(Vector3.UP, lr * TURN_SPEED * delta)

	#var pitch := Input.get_axis("move_forward", "move_back")
	rotate_object_local(Vector3.RIGHT, ail_pitch * PITCH_MULT * delta)
	
	var facing_dir := (transform.basis * Vector3.FORWARD).normalized()
	var v_dir := velocity.normalized()
	if v_dir:
		#var d_dir :=  
		v_dir = v_dir.move_toward(facing_dir, 1.0 * delta).normalized()
	else:
		v_dir = facing_dir
	velocity = v_dir * speed
	move_and_slide()


func adjust_ailerons(delta: float) -> void:
	ail_pitch_target = Input.get_axis("move_forward", "move_back")
	ail_pitch = move_toward(ail_pitch, ail_pitch_target, AIL_PITCH_SPEED * delta)
	$Ailerons/Pitch.rotation.x = ail_pitch*-0.9
	# TODO: r and y


#func set_aileron_pitch_target(pitch: float) -> void:
	#ail_pitch_target = pitch
	
# TODO: y and r
