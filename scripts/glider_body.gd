extends CharacterBody3D
class_name Glider

const HUD := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")

const G := 9.8
const SURFACE_DEFLECT := 0.7 # visual surface tilt (rad) at full deflection
const FLOOR_HEIGHT := 0.5
const MAX_SPEED := 35.0

## Boost reserve: a limited tank that drains while boosting and refills only
## after a short idle, so boost is a resource to manage rather than spam.
const BOOST_MAX := 100.0
const BOOST_DRAIN := 45.0          # units/sec while boosting (~2.2s of full tank)
const BOOST_RECHARGE := 22.0       # units/sec once recharging
const BOOST_RECHARGE_DELAY := 5.0  # sec of no boosting before the tank refills
const BOOST_FORCE := 50.0           # nose-ward accel while boosting (player)
const AI_BOOST_FORCE := 35.0        # 70% of player BOOST_FORCE (see AI boost below)
const AI_FX_SCALE := 0.55           # AI boost FX (particle count/size, glow) vs player


## Flight tuning — PRIMARY/SECONDARY presets, toggled live with T or the pause menu.
var _tunings := [FlightTuning.primary(), FlightTuning.secondary()]
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

## How far the wings are extended (1.0 = fully out, max drag; 0.08 = retracted,
## nearly frictionless). Smoothed toward a handbrake-driven target — drives both
## the aerodynamic drag and the visual wing mesh, so they always move together.
var wing_extension := 1.0
## Units/sec the wing extension eases toward its target (full sweep ~ 0.3s).
var wing_extend_rate := 8.5


## Collision mass (heavy — the ball reacts to us far more than we react to it).
var mass := 160.0
## Accumulated external knock (e.g. from the ball), applied once per frame.
var _external_impulse := Vector3.ZERO


## Pot height (stored potential energy as an equivalent altitude).
var pot_height := 0.0
var _hud: CanvasLayer

## Boost reserve state. Starts full and ready (idle past the recharge delay).
var boost_amount := BOOST_MAX
var _boost_idle := BOOST_RECHARGE_DELAY
## Latched true when the tank empties mid-boost; blocks re-firing until the
## player releases the button, so a held boost doesn't waste the first recharge.
var _boost_locked := false
## Exhaust flame, emitting only while boosting (created for every glider).
var _boost_fx: CPUParticles3D
## Warm point light pulsing at the tail while boosting (sells the glow).
var _boost_light: OmniLight3D


## Controls.
@export var is_ai := false
## Which AI brain to load: scripts/ai_variants/ai_<ai_variant>.gd (AI only).
@export var ai_variant := "base"
## World point this glider attacks. Default = BLUE goal (north, +Z).
@export var target_goal := Vector3(0.0, 10.5, 143.5)
var control_scheme := GliderInput.Scheme.RL
var _menu: CanvasLayer
var controller: RefCounted
var _spawn_transform: Transform3D
## +1 for the blue/player side (spawn z > 0), -1 for the orange/AI side.
var side := 1


## Team tint — players fly blue, the AI flies orange (matching the goals).
## Slightly deep/desaturated so the metal sheen reads instead of glowing flat.
const PLAYER_COLOR := Color(0.12, 0.32, 0.78)
const AI_COLOR := Color(0.85, 0.38, 0.08)


func _ready() -> void:
	tuning = _tunings[_tuning_idx]
	_spawn_transform = global_transform
	side = -1 if global_position.z < 0.0 else 1
	add_to_group("glider")
	_apply_team_color(AI_COLOR if is_ai else PLAYER_COLOR)
	_boost_fx = _make_boost_fx()
	add_child(_boost_fx)
	_boost_light = _make_boost_light()
	add_child(_boost_light)
	if is_ai:
		controller = _make_ai_controller()
	else:
		controller = HumanController.new()
		_hud = HUD.new()
		add_child(_hud)
		_menu = PauseMenu.new()
		_menu.glider = self
		add_child(_menu)


## Orange exhaust flame streamed out the tail (local +Z; the nose faces -Z).
## local_coords=false so spawned particles stay in world space and trail behind
## the craft. Toggled on/off by `emitting` each frame while boosting.
func _make_boost_fx() -> CPUParticles3D:
	var fx := CPUParticles3D.new()
	# The AI's exhaust is dialed down so the player's boost reads as the stronger,
	# flashier one (fewer, smaller particles and a dimmer glow; see _physics_process).
	var fx_scale := AI_FX_SCALE if is_ai else 1.0
	fx.emitting = false
	fx.local_coords = false
	fx.amount = int(140 * fx_scale)
	fx.lifetime = 0.5
	fx.position = Vector3(0.0, 0.05, 0.7)
	# Seed the jet from a small disc across the exhaust so it reads as a column,
	# not a single point.
	fx.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fx.emission_sphere_radius = 0.12
	fx.direction = Vector3(0.0, 0.0, 1.0)
	fx.spread = 11.0
	fx.initial_velocity_min = 11.0
	fx.initial_velocity_max = 18.0
	fx.gravity = Vector3.ZERO
	# A touch of drag so the tail decelerates and bunches into a soft smoke puff.
	fx.damping_min = 6.0
	fx.damping_max = 10.0
	fx.scale_amount_min = 0.6 * fx_scale
	fx.scale_amount_max = 1.1 * fx_scale
	# Grow slightly off the nozzle, then taper to nothing as it cools.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.55))
	taper.add_point(Vector2(0.18, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	fx.scale_amount_curve = taper
	# White-yellow core -> orange -> red -> dark smoke fade.
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 1.0, 0.92, 1.0),   # white-hot core
		Color(1.0, 0.78, 0.25, 1.0),  # yellow
		Color(1.0, 0.30, 0.04, 0.7),  # orange-red
		Color(0.25, 0.10, 0.08, 0.0), # smoke fade-out
	])
	fx.color_ramp = grad
	var ball := SphereMesh.new()
	ball.radius = 0.14
	ball.height = 0.28
	ball.radial_segments = 6
	ball.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	# Additive billboards give the overlapping particles a bloomy glow.
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.disable_receive_shadows = true
	ball.material = mat
	fx.mesh = ball
	return fx


## Warm omni light parented at the tail, lit only while boosting so the exhaust
## casts a believable glow on the craft and nearby surfaces.
func _make_boost_light() -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.05, 0.85)
	light.light_color = Color(1.0, 0.55, 0.18)
	light.light_energy = 0.0          # off until boosting (set in toggle)
	light.omni_range = 3.5
	light.shadow_enabled = false
	return light


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
	# T toggles PRIMARY <-> SECONDARY tuning live (also a pause-menu button).
	if event.is_action_pressed("toggle_tuning"):
		toggle_tuning()
		_menu.refresh_labels()
	# C toggles RL <-> PILOT control scheme live (also a pause-menu button).
	elif event.is_action_pressed("toggle_scheme"):
		toggle_control()
		_menu.refresh_labels()


func _physics_process(delta: float) -> void:
	## inputs
	var ctl: GliderControls = controller.sample(self, control_scheme)
	adjust_ailerons(delta, ctl.targets)
	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	#
	## air brake — analog handbrake retracts the wings, cutting drag so the craft
	## drifts on its momentum. Smooth toward the target so the discrete X button
	## (snaps 0->1) doesn't jolt; the analog trigger already varies smoothly. The
	## same smoothed value drives the wing mesh below, keeping visual == physics.
	var target_extension := lerpf(1.0, 0.00, ctl.hand_brake)
	wing_extension = move_toward(wing_extension, target_extension, wing_extend_rate * delta)
	set_wing_extension(wing_extension)
	#
	## current values
	var current_speed := velocity.length()
	var current_dir := velocity.normalized() # TODO: look out for magnitude 0 velocity
	if !current_dir.length():
		current_dir = Vector3.DOWN
	#
	var nose_dir := (transform.basis * Vector3.FORWARD).normalized()
	#var drag_factor := wing_extension * tuning.DRAG * current_speed * nose_dir.cross(current_dir).length()
	var nose_dot := velocity.normalized().dot(nose_dir)
	var drag_factor := (1 - absf(nose_dot))*wing_extension
	# handbrake sharpens turn rate: lerp both coefficients from cruise to braked.
	var rrate := lerpf(0.5, 0.8, ctl.hand_brake) \
		+ lerpf(0.1, 0.06, ctl.hand_brake) * sqrt(velocity.length()) #* nose_dot
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
	var pot_speed_catchup := 1.0+tuning.POT_SPEED_CATCHUP_MULT*(current_speed)
	var new_speed := move_toward(current_speed, pot_speed, pot_speed_catchup * delta)
	var dir_offset := nose_dir.angle_to(current_dir)
	var closeness_to_45 := 1.0 - (absf(PI/4.0 - absf(fmod(dir_offset, PI/2.0)))/(PI/4))
	var pot_dir_catchup := 0.2 + wing_extension * tuning.POT_DIR_CATCHUP_MULT * current_speed * sqrt(closeness_to_45 + 0.2)
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
	
	# Boost only fires while there's reserve left; it drains the tank, which
	# refills once we've gone BOOST_RECHARGE_DELAY seconds without boosting.
	# Releasing the button clears the empty-tank lock so the next press can boost.
	if not ctl.boost:
		_boost_locked = false
	# The AI gets unlimited but softer boost: boost-tank management is hard to
	# train, so the AI never runs dry and just thrusts a bit weaker than the
	# player. The player still drains a finite, lockable reserve.
	var boosting := ctl.boost if is_ai else (ctl.boost and boost_amount > 0.0 and not _boost_locked)
	if boosting:
		velocity += nose_dir * (AI_BOOST_FORCE if is_ai else BOOST_FORCE) * delta
		if not is_ai:
			boost_amount = maxf(0.0, boost_amount - BOOST_DRAIN * delta)
			_boost_idle = 0.0
			if boost_amount <= 0.0:
				_boost_locked = true  # drained while held; require a release to re-fire
	else:
		_boost_idle += delta
		if _boost_idle >= BOOST_RECHARGE_DELAY:
			boost_amount = minf(BOOST_MAX, boost_amount + BOOST_RECHARGE * delta)
	if _boost_fx:
		_boost_fx.emitting = boosting
	if _boost_light:
		# Flicker the glow a little so the exhaust feels alive while boosting.
		var fx_scale := AI_FX_SCALE if is_ai else 1.0
		var target := ((2.4 + 0.5 * sin(_boost_idle * 60.0)) * fx_scale) if boosting else 0.0
		_boost_light.light_energy = lerpf(_boost_light.light_energy, target, minf(1.0, delta * 18.0))

	var slow := ctl.slow
	if slow > 0.0 and current_speed > 4.0:
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
	update_hud()
	#
	#velocity = Vector3.ZERO# TODONOW uncomment
	#rotation = Vector3.ZERO# TODONOW uncomment
	move_and_slide()


func apply_impulse(impulse: Vector3) -> void:
	_external_impulse += impulse


## Move this glider's spawn point to a kickoff (x, z) given for the blue side;
## the orange side (-Z) is mirrored. Only the position moves — the original
## facing (basis) and spawn height are preserved. Call before reset_to_spawn().
func set_kickoff_position(blue_xz: Vector2) -> void:
	var origin := _spawn_transform.origin
	origin.x = blue_xz.x * side
	origin.z = blue_xz.y * side
	_spawn_transform.origin = origin


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
	# Refill the boost tank and clear the empty-tank lock, so a player who
	# drained boost before a goal isn't left with none after the reset.
	boost_amount = BOOST_MAX
	_boost_idle = BOOST_RECHARGE_DELAY
	_boost_locked = false


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


func set_wing_extension(ext: float) -> void:
	# ext in [0,1]: 1 = wings fully out (unchanged), 0 = pulled in to the body.
	$Mesh/Q/LWing.position.x = lerpf(-0.12, -0.655, ext)
	$Mesh/Q/RWing.position.x = lerpf(0.12, 0.655, ext)


var _referee: Node


func update_hud() -> void:
	if not _hud:
		return
	_hud.set_boost(boost_amount, BOOST_MAX)
	if not is_instance_valid(_referee):
		_referee = get_tree().get_first_node_in_group("referee")
	if _referee:
		_hud.set_score(_referee.score_blue, _referee.score_orange)
