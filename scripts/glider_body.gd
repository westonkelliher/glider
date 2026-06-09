extends CharacterBody3D

const HUD := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")

const G := 9.8
const SURFACE_DEFLECT := 0.7 # visual surface tilt (rad) at full deflection


## Flight tuning — TEST/PLAY presets, toggled live with T or the pause menu.
var _tunings := [FlightTuning.test(), FlightTuning.play()]
var _tuning_idx := 1
var tuning: FlightTuning


## Aileron surface state (smoothed deflections + their input targets).
var ail_pitch := 0.0
var ail_pitch_target := 0.0
var ail_pitch_speed := 0.0
var ail_roll := 0.0
var ail_roll_speed := 0.0
var ail_roll_target := 0.0
var ail_yaw := 0.0
var ail_yaw_speed := 0.0
var ail_yaw_target := 0.0

## rotational speeds
var pitch_v := 0.0
var roll_v := 0.0
var yaw_v := 0.0

## Air-brake friction: drops while heavy, eases back to 1.0 otherwise.
var air_friction := 1.0

## Heavy dive state (hold air_brake): tucked wings + extra gravity, release pops.
var is_heavy := false
var was_heavy := false
var release_grace := 0.0 # seconds left where the release launch keeps its speed
var target_scale := 1.0
var current_scale := 1.0


## Pot height (stored potential energy as an equivalent altitude).
var pot_height := 0.0
var _hud: CanvasLayer


## Controls.
var control_scheme := GliderInput.Scheme.RL
var _menu: CanvasLayer


func _ready() -> void:
	tuning = _tunings[_tuning_idx]
	_hud = HUD.new()
	add_child(_hud)
	_menu = PauseMenu.new()
	_menu.glider = self
	add_child(_menu)


## --- Tuning / control toggles (also driven by the pause menu) ------------

func toggle_tuning() -> void:
	_tuning_idx = (_tuning_idx + 1) % _tunings.size()
	tuning = _tunings[_tuning_idx]


func toggle_control() -> void:
	control_scheme = GliderInput.Scheme.PILOT if control_scheme == GliderInput.Scheme.RL \
		else GliderInput.Scheme.RL


func menu_labels() -> Dictionary:
	return {"tuning": tuning.DISPLAY_NAME, "control": GliderInput.name_of(control_scheme)}


func _process(delta: float) -> void:
	# Squash the visual mesh toward the dive scale; collision shape is untouched.
	current_scale = move_toward(current_scale, target_scale, 2.0 * delta)
	$Mesh.scale = Vector3.ONE * current_scale


func _unhandled_input(event: InputEvent) -> void:
	# T / Back toggles TEST <-> PLAY tuning live.
	if event.is_action_pressed("toggle_tuning"):
		toggle_tuning()
		_menu.refresh_labels()
	# C / Start toggles RL <-> PILOT control scheme live.
	elif event.is_action_pressed("toggle_scheme"):
		toggle_control()
		_menu.refresh_labels()


func _physics_process(delta: float) -> void:
	## inputs
	adjust_ailerons(delta)
	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	#
	## air brake — held brake kills friction so the craft drifts on its momentum.
	## heavy dive — tucks the wings and goes full ballistic.
	is_heavy = GliderInput.read_heavy()
	var braked := GliderInput.read_braked()
	if braked:
		air_friction = 0.05
	else:
		air_friction = move_toward(air_friction, 1.0, 200.0 * delta)
	pull_in_wings(braked or is_heavy)
	target_scale = 0.78 if is_heavy else 1.0
	#
	## current values
	var current_speed := velocity.length()
	var current_dir := velocity.normalized() # TODO: look out for magnitude 0 velocity
	if !current_dir.length():
		current_dir = Vector3.DOWN
	#
	var nose_dir := (transform.basis * Vector3.FORWARD).normalized()
	#var drag_factor := air_friction * tuning.DRAG * current_speed * nose_dir.cross(current_dir).length()
	var nose_dot := velocity.normalized().dot(nose_dir)
	var drag_factor := 1 - absf(nose_dot)
	var rrate := 0.2 + 0.15 * sqrt(velocity.length()) #* nose_dot
	#
	## adjust rotation
	rotate_object_local(Vector3.RIGHT, rrate * ail_pitch * tuning.PITCH_MULT * delta) # pitch
	rotate_object_local(Vector3.BACK, rrate * ail_roll * tuning.ROLL_MULT * delta)    # roll
	rotate_object_local(Vector3.DOWN, rrate * ail_yaw * tuning.YAW_MULT * delta)      # yaw (right = nose right)
	#
	#
	## speeds, directions and velocities from potential (pot) values
	release_grace = maxf(0.0, release_grace - delta)
	var d_h := pot_height - position.y
	var pot_speed := 0.0
	var new_speed := current_speed
	var pot_speed_catchup := 0.0
	var pot_dir_catchup := 0.0
	if is_heavy:
		## heavy — full ballistic: gravity only, momentum carries, no aero or
		## energy model; pot_height freezes until the release refill.
		velocity += G * tuning.HEAVY_GRAV_MULT * Vector3.DOWN * delta
	else:
		# pot values
		if position.y > pot_height && position.y > 2.0:
			pot_height = position.y
		d_h = pot_height - position.y
		pot_speed = sqrt(maxf(0.0, d_h)*G*2) # solved for speed in terms of d_h ##########
		# during the post-release grace the heavy cap still applies, so the launch
		# carries instead of snapping back to cruise speed
		var speed_cap := tuning.HEAVY_MAX_SPEED if release_grace > 0.0 else tuning.MAX_SPEED
		pot_speed = min(pot_speed, speed_cap)
		#
		# new values
		pot_speed_catchup = 1.0+tuning.POT_SPEED_CATCHUP_MULT*(0.1+current_speed)
		new_speed = move_toward(current_speed, pot_speed, pot_speed_catchup * delta)
		var dir_offset := nose_dir.angle_to(current_dir)
		var closeness_to_45 := 1.0 - (absf(PI/4.0 - absf(fmod(dir_offset, PI/2.0)))/(PI/4))
		pot_dir_catchup = 0.2 + air_friction * tuning.POT_DIR_CATCHUP_MULT * current_speed * sqrt(closeness_to_45)
		var new_dir := current_dir.move_toward(nose_dir, pot_dir_catchup * delta)# TODO: calculate shortest direct arc from current_dir to pot_dir
		var new_velocity := new_speed * new_dir + Vector3.UP*0.01
		#
		## Nose Pull
		var nose_pull_r := tuning.NOSE_PULL_MULT * drag_factor * delta
		nose_pull_r = min(nose_pull_r, nose_dir.angle_to(current_dir)) # dont overshoot
		var nose_axis := nose_dir.cross(current_dir).normalized()
		rotate(nose_axis, nose_pull_r)
		#
		## Accelerations
		var a_gravity := G * Vector3.DOWN * delta
		var a_drag := tuning.DRAG * drag_factor * -velocity.normalized()
		#
		## velocity
		velocity = new_velocity + a_gravity + a_drag
		#
		# reduce pot_height towards low speed:
		var d_h_2 := pow(velocity.length(), 2)/(G*2.0)
		var dhd := absf(d_h - d_h_2)
		var reduction_speed := 2.2 * pow(dhd, 1.2)
		pot_height = move_toward(pot_height, position.y + d_h_2, reduction_speed * delta)

	## Release boost — Tiny-Wings pop the frame the dive ends.
	if was_heavy and not is_heavy:
		var rel_speed := velocity.length()
		if rel_speed > 0.0:
			velocity *= 1.0 / (1.0 - tuning.RELEASE_BOOST_RATIO)
			velocity *= (rel_speed + tuning.RELEASE_BOOST_FLAT) / rel_speed
			# lift scales with how fast we exit the dive
			var speed_factor := rel_speed / tuning.MAX_SPEED
			velocity += Vector3.UP * maxf(0.0, Vector3.UP.dot(velocity.normalized())) \
				* tuning.RELEASE_LIFT * speed_factor
		# refill the energy model so it doesn't immediately eat the boost
		pot_height = maxf(pot_height, position.y + pow(velocity.length(), 2) / (2.0 * G))
		release_grace = 1.2
	was_heavy = is_heavy

	if Input.is_action_pressed("boost"):
		pot_height += 30.0 * delta
		velocity += nose_dir * 10.0 * delta
	
	# terrain skimming — deflect along the slope instead of stopping, so a heavy
	# dive into a downslope keeps its speed along the hill (the valley swoop)
	var gy := GroundMath.height(position.x, position.z)
	if position.y < gy + 0.9:
		position.y = gy + 0.9
		var n := GroundMath.normal(position.x, position.z)
		var pre_deflect_speed := velocity.length()
		# take away the into-ground component of velocity
		velocity -= n * minf(0.0, n.dot(velocity))
		if velocity.length() > 0.001:
			# keep the speed through the deflection, minus mild time-based ground friction
			velocity = velocity.normalized() * pre_deflect_speed * pow(0.94, delta)
		velocity += Vector3.UP*0.1
	
	#if velocity.length() < 0.1:
		#velocity += Vector3.DOWN * 0.05
	#
	set_stats(d_h, current_speed, pot_speed, new_speed, nose_dir, current_dir,
		pot_speed_catchup, pot_dir_catchup)
	#
	#velocity = Vector3.ZERO# TODONOW uncomment
	#rotation = Vector3.ZERO# TODONOW uncomment
	move_and_slide()


var p_is_start := true

func adjust_ailerons(delta: float) -> void:
	var targets := GliderInput.read_targets(control_scheme)
	var p_target := targets.x
	var r_target := targets.y
	var y_target := targets.z
	# rename
	var damp_size := tuning.AIL_DAMP_ZONES_SIZE
	var p_s := tuning.AIL_PITCH_SPEED
	var acc := tuning.AIL_ACC
	var r_s := tuning.AIL_ROLL_SPEED
	var y_s := tuning.AIL_YAW_SPEED
	#
	# pitch
	var p_dir := 1.0
	if p_target < ail_pitch:
		p_dir = -1.0
	if ail_pitch_speed * p_dir < 0: # if moving in opposite direction we want, acc * 2
		ail_pitch_speed = move_toward(ail_pitch_speed, p_s, acc)
	ail_pitch_speed = move_toward(ail_pitch_speed, p_s, acc)
	# if we're close to the target, damp speed
	var p_dist_to_target := absf(p_target - ail_pitch)
	if p_dist_to_target < damp_size:
		ail_pitch_speed = 0.03 + p_s * pow((p_dist_to_target+0.1)/(damp_size+0.1), 1.5)
	ail_pitch = move_toward(ail_pitch, p_target, ail_pitch_speed * delta)
	# roll
	var r_dir := 1.0
	if r_target < ail_roll:
		r_dir = -1.0
	if ail_roll_speed * r_dir < 0: # moving the wrong way — burn extra accel to reverse
		ail_roll_speed = move_toward(ail_roll_speed, r_s, acc)
	ail_roll_speed = move_toward(ail_roll_speed, r_s, acc)
	var r_dist_to_target := absf(r_target - ail_roll)
	if r_dist_to_target < damp_size:
		ail_roll_speed = 0.03 + r_s * pow((r_dist_to_target+0.1)/(damp_size+0.1), 1.5)
	ail_roll = move_toward(ail_roll, r_target, ail_roll_speed * delta)
	# yaw
	var y_dir := 1.0
	if y_target < ail_yaw:
		y_dir = -1.0
	if ail_yaw_speed * y_dir < 0:
		ail_yaw_speed = move_toward(ail_yaw_speed, y_s, acc)
	ail_yaw_speed = move_toward(ail_yaw_speed, y_s, acc)
	var y_dist_to_target := absf(y_target - ail_yaw)
	if y_dist_to_target < damp_size:
		ail_yaw_speed = 0.03 + y_s * pow((y_dist_to_target+0.1)/(damp_size+0.1), 1.5)
	ail_yaw = move_toward(ail_yaw, y_target, ail_yaw_speed * delta)
	#
	# Deflect each visual surface about its correct local hinge axis.
	$Ailerons/Pitch.rotation.x = ail_pitch * -SURFACE_DEFLECT  # elevator (both together)
	$Ailerons/LRoll.rotation.x = ail_roll * SURFACE_DEFLECT    # ailerons deflect
	$Ailerons/RRoll.rotation.x = ail_roll * -SURFACE_DEFLECT   # oppositely
	$Ailerons/Yaw.rotation.z = ail_yaw * SURFACE_DEFLECT       # rudder


## Smoothstep-interpolate: val1 below thresh1, val2 above thresh2, smooth between.
## Order-agnostic — pass thresholds in either order.
static func interstep(thresh1: float, val1: float, thresh2: float, val2: float, variable: float) -> float:
	if thresh1 > thresh2:
		var t := thresh1; thresh1 = thresh2; thresh2 = t
		var v := val1; val1 = val2; val2 = v
	return lerpf(val1, val2, smoothstep(thresh1, thresh2, variable))


func pull_in_wings(inny: bool) -> void:
	if inny:
		$Mesh/Q/LWing.position.x = -.4
		$Mesh/Q/RWing.position.x = 0.4
	else:
		$Mesh/Q/LWing.position.x = -.655
		$Mesh/Q/RWing.position.x = 0.655


func set_stats(
	d_h: float,
	current_speed: float,
	pot_speed: float,
	new_speed: float,
	nose_dir: Vector3,
	current_dir: Vector3,
	pot_speed_catchup: float,
	pot_dir_catchup: float,
) -> void:
	_hud.set_readout(pot_height, tuning.DISPLAY_NAME, GliderInput.name_of(control_scheme), is_heavy)
	var align := nose_dir.dot(current_dir)
	_hud.set_stats({
		"alt": position.y,
		"d_h": d_h,
		"pot_h": pot_height,
		"speed": current_speed,
		"pot_spd": pot_speed,
		"new_spd": new_speed,
		"align": align,
		"spd_catch": pot_speed_catchup,
		"dir_catch": pot_dir_catchup,
		"drag": tuning.DRAG * current_speed * (1.0 - align),
	})
	
