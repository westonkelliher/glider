extends CharacterBody3D


const TURN_SPEED = 2.5  # radians/sec
const JUMP_VELOCITY = 4.5
const G := 9.8


## Ailerons
# Pitch
const AIL_PITCH_SPEED := 7.0 # 1/s: how fast a surface eases toward its target
const PITCH_MULT := 3.5 # craft turn authority per unit of deflection
# Roll
const AIL_ROLL_SPEED := 5.0
const ROLL_MULT := 5.0
# Yaw
const AIL_YAW_SPEED := 7.0
const YAW_MULT := 2.0
#
const SURFACE_DEFLECT := 0.7 # visual surface tilt (rad) at full deflection
#
var ail_pitch := 0.0
var ail_pitch_target := 0.0
var ail_roll := 0.0
var ail_roll_target := 0.0
var ail_yaw := 0.0
var ail_yaw_target := 0.0


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
		speed = 0.1
	else:
		speed = sqrt(d_h*G*2) # solved for speed in terms of d_h
	
	# adjust ailerons
	adjust_ailerons(delta)

	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	rotate_object_local(Vector3.RIGHT, ail_pitch * PITCH_MULT * delta) # pitch
	rotate_object_local(Vector3.BACK, ail_roll * ROLL_MULT * delta)    # roll
	rotate_object_local(Vector3.UP, ail_yaw * YAW_MULT * delta)        # yaw
	
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
	# Pitch from F/B. L/R rolls while air_roll is held, otherwise yaws (RL-style).
	ail_pitch_target = Input.get_axis("move_forward", "move_back")
	var lr := Input.get_axis("move_right", "move_left")
	if Input.is_action_pressed("air_roll"):
		ail_roll_target = lr
		ail_yaw_target = 0.0
	else:
		ail_yaw_target = lr
		ail_roll_target = 0.0

	ail_pitch = move_toward(ail_pitch, ail_pitch_target, AIL_PITCH_SPEED * delta)
	ail_roll = move_toward(ail_roll, ail_roll_target, AIL_ROLL_SPEED * delta)
	ail_yaw = move_toward(ail_yaw, ail_yaw_target, AIL_YAW_SPEED * delta)

	# Deflect each visual surface about its correct local hinge axis.
	$Ailerons/Pitch.rotation.x = ail_pitch * -SURFACE_DEFLECT  # elevator (both together)
	$Ailerons/LRoll.rotation.x = ail_roll * SURFACE_DEFLECT    # ailerons deflect
	$Ailerons/RRoll.rotation.x = ail_roll * -SURFACE_DEFLECT   # oppositely
	$Ailerons/Yaw.rotation.z = ail_yaw * SURFACE_DEFLECT       # rudder
