extends CharacterBody3D
class_name Glider

const HUD := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
const Missile := preload("res://missile.tscn")

const G := 9.8
const SURFACE_DEFLECT := 0.7 # visual surface tilt (rad) at full deflection
const FLOOR_HEIGHT := 0.5
const MAX_SPEED := 35.0


## Flight tuning — TEST/PLAY presets, toggled live with T or the pause menu.
var _tunings := [FlightTuning.test(), FlightTuning.play()]
var _tuning_idx := 0
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

## Air-brake friction: drops while braked, eases back to 1.0 otherwise.
var air_friction := 1.0


## Collision mass (heavy — the ball reacts to us far more than we react to it).
var mass := 160.0
## Accumulated external knock (e.g. from the ball), applied once per frame.
var _external_impulse := Vector3.ZERO


## Pot height (stored potential energy as an equivalent altitude).
var pot_height := 0.0
var _hud: CanvasLayer


## Controls.
@export var is_ai := false
## Which AI brain to load: scripts/ai_variants/ai_<ai_variant>.gd (AI only).
@export var ai_variant := "base"
## World point this glider attacks. Default = BLUE goal (north, +Z).
@export var target_goal := Vector3(0.0, 15.0, 205.0)
var control_scheme := GliderInput.Scheme.RL
var _menu: CanvasLayer
var controller: RefCounted
var _spawn_transform: Transform3D


## Team tint — players fly blue, the AI flies orange (matching the goals).
## Slightly deep/desaturated so the metal sheen reads instead of glowing flat.
const PLAYER_COLOR := Color(0.12, 0.32, 0.78)
const AI_COLOR := Color(0.85, 0.38, 0.08)


func _ready() -> void:
	tuning = _tunings[_tuning_idx]
	_spawn_transform = global_transform
	add_to_group("glider")
	_apply_team_color(AI_COLOR if is_ai else PLAYER_COLOR)
	if is_ai:
		controller = _make_ai_controller()
	else:
		controller = HumanController.new()
		_hud = HUD.new()
		add_child(_hud)
		_menu = PauseMenu.new()
		_menu.glider = self
		add_child(_menu)


## Paint the body in the team color with a Rocket-League-ish metallic finish.
## Each mesh keeps its original relative brightness (wings stay light, fins/
## accents stay dark) so the craft reads as shaded paint, not one flat slab.
## Overrides leave the shared wingmat/material resources untouched.
func _apply_team_color(color: Color) -> void:
	for mesh in $Mesh.find_children("*", "MeshInstance3D", true, false):
		var src := mesh.get_active_material(0) as StandardMaterial3D
		var shade := clampf((src.albedo_color.v if src else 0.6) * 1.35, 0.35, 1.0)
		var m := StandardMaterial3D.new()
		m.albedo_color = color * Color(shade, shade, shade)
		m.metallic = 0.55
		m.metallic_specular = 0.65
		m.roughness = 0.32
		mesh.material_override = m


## Load the AI brain named by `ai_variant`, falling back to the base striker if
## the file is missing or fails to compile (so one broken variant can't crash a
## whole tournament).
func _make_ai_controller() -> RefCounted:
	var path := "res://scripts/ai_variants/ai_%s.gd" % ai_variant
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res != null:
			var c: RefCounted = res.new()
			if c != null:
				return c
		push_warning("AI variant '%s' failed to load; using base." % ai_variant)
	return AiBase.new()


## --- Tuning / control toggles (also driven by the pause menu) ------------

func toggle_tuning() -> void:
	_tuning_idx = (_tuning_idx + 1) % _tunings.size()
	tuning = _tunings[_tuning_idx]


func toggle_control() -> void:
	control_scheme = GliderInput.Scheme.PILOT if control_scheme == GliderInput.Scheme.RL \
		else GliderInput.Scheme.RL


func menu_labels() -> Dictionary:
	return {"tuning": tuning.DISPLAY_NAME, "control": GliderInput.name_of(control_scheme)}


func _unhandled_input(event: InputEvent) -> void:
	if is_ai:
		return
	# T / Back toggles TEST <-> PLAY tuning live.
	if event.is_action_pressed("toggle_tuning"):
		toggle_tuning()
		_menu.refresh_labels()
	# C / Start toggles RL <-> PILOT control scheme live.
	elif event.is_action_pressed("toggle_scheme"):
		toggle_control()
		_menu.refresh_labels()
	if event.is_action_pressed("launch"):
		launch_missile()


func launch_missile() -> void:
	var missile := Missile.instantiate()
	get_parent().add_child(missile)
	missile.global_position = global_position
	var nose_dir := (transform.basis * Vector3.FORWARD).normalized()
	var speed := velocity.length()
	var vel_dir := velocity.normalized()
	missile.launch(0.6 * speed * vel_dir + 0.6 * speed * nose_dir)


func _physics_process(delta: float) -> void:
	## inputs
	var ctl: GliderControls = controller.sample(self, control_scheme)
	adjust_ailerons(delta, ctl.targets)
	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	#
	## air brake — held brake kills friction so the craft drifts on its momentum.
	if ctl.braked:
		air_friction = 0.05
		pull_in_wings(true)
	else:
		air_friction = move_toward(air_friction, 1.0, 200.0 * delta)
		pull_in_wings(false)
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
	var drag_factor := (1 - absf(nose_dot))*air_friction
	var rrate := 0.5 + 0.1 * sqrt(velocity.length()) #* nose_dot
	if ctl.braked:
		rrate = 0.8 + 0.06 * sqrt(velocity.length()) #* nose_dot
	#rrate = 1.0
	#
	## adjust rotation
	rotate_object_local(Vector3.RIGHT, rrate * ail_pitch * tuning.PITCH_MULT * delta) # pitch
	rotate_object_local(Vector3.BACK, rrate * ail_roll * tuning.ROLL_MULT * delta)    # roll
	rotate_object_local(Vector3.DOWN, rrate * ail_yaw * tuning.YAW_MULT * delta)      # yaw (right = nose right)
	#
	#
	## speeds, directions and velocities from potential (pot) values
	# pot values
	if position.y > pot_height:
		pot_height = position.y
	var d_h := pot_height - position.y
	var pot_speed := sqrt(d_h*G*2) # solved for speed in terms of d_h ##########
	pot_speed = min(pot_speed, MAX_SPEED) # max speed
	#
	# new values
	var pot_speed_catchup := 1.0+tuning.POT_SPEED_CATCHUP_MULT*(0.1+current_speed)
	var new_speed := move_toward(current_speed, pot_speed, pot_speed_catchup * delta)
	var dir_offset := nose_dir.angle_to(current_dir)
	var closeness_to_45 := 1.0 - (absf(PI/4.0 - absf(fmod(dir_offset, PI/2.0)))/(PI/4))
	var pot_dir_catchup := 0.2 + air_friction * tuning.POT_DIR_CATCHUP_MULT * current_speed * sqrt(closeness_to_45)
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
	# Sum
	var a_total := a_gravity + a_drag
	#
	## velocity
	velocity = new_velocity + a_total
	
	# reduce pot_height towards low speed:
	var d_h_2 := pow(velocity.length(), 2)/(G*2.0)
	var dhd := absf(d_h - d_h_2)
	var reduction_speed := 2.2 * pow(dhd, 1.2)
	pot_height = move_toward(pot_height, position.y + d_h_2, reduction_speed * delta)
	
	if ctl.boost:
		pot_height += 30.0 * delta
		velocity += nose_dir * 10.0 * delta

	var slow := ctl.slow
	if slow > 0.0 and current_speed > 1.0:
		# flat component
		pot_height -= 45.0 * slow * delta
		var forward_speed := maxf(0.0, velocity.dot(nose_dir))
		velocity -= nose_dir * minf(15.0 * slow * delta, forward_speed)
		# fractional component: lose 50%/s of speed (speed scales as sqrt(d_h))
		var speed_factor := maxf(0.0, 1.0 - 0.5 * slow * delta)
		pot_height = position.y + (pot_height - position.y) * speed_factor * speed_factor
		velocity *= speed_factor
		pot_height = maxf(pot_height, position.y)
	
	# keep from touching floor
	if position.y < FLOOR_HEIGHT:
		position.y = FLOOR_HEIGHT
		# take away downward component of velocity
		var down_of_v := Vector3.DOWN * Vector3.DOWN.dot(velocity)
		velocity -= down_of_v
		velocity += Vector3.UP*0.1
	
	#if velocity.length() < 0.1:
		#velocity += Vector3.DOWN * 0.05
	#
	# apply any external knock (e.g. ball impact) on top of the flight model
	if _external_impulse != Vector3.ZERO:
		velocity += _external_impulse / mass
		_external_impulse = Vector3.ZERO
		# bake the new speed into pot_height (the source of truth for speed),
		# else the flight model regenerates the old speed next frame.
		pot_height = position.y + velocity.length_squared() / (2.0 * G)
	#
	set_stats(d_h, current_speed, pot_speed, new_speed, nose_dir, current_dir,
		pot_speed_catchup, pot_dir_catchup)
	#
	#velocity = Vector3.ZERO# TODONOW uncomment
	#rotation = Vector3.ZERO# TODONOW uncomment
	move_and_slide()


func apply_impulse(impulse: Vector3) -> void:
	_external_impulse += impulse


## Restore the glider to its spawn pose and zero all motion/aileron state.
## Intended for the referee to call after a goal.
func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	pot_height = global_position.y
	ail_pitch = 0.0
	ail_pitch_target = 0.0
	ail_pitch_speed = 0.0
	ail_roll = 0.0
	ail_roll_target = 0.0
	ail_roll_speed = 0.0
	ail_yaw = 0.0
	ail_yaw_target = 0.0
	ail_yaw_speed = 0.0


var p_is_start := true

func adjust_ailerons(delta: float, targets: Vector3) -> void:
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
	if not _hud:
		return
	_hud.set_readout(pot_height, tuning.DISPLAY_NAME, GliderInput.name_of(control_scheme))
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
	
