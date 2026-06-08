extends CharacterBody3D

const HUD := preload("res://scripts/hud.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")

const G := 9.8
const SURFACE_DEFLECT := 0.7 # visual surface tilt (rad) at full deflection


## Flight tuning — TEST/PLAY presets, toggled live with T or the pause menu.
var _tunings := [FlightTuning.test(), FlightTuning.play()]
var _tuning_idx := 0
var tuning: FlightTuning


## Aileron surface state (smoothed deflections + their input targets).
var ail_pitch := 0.0
var ail_pitch_target := 0.0
var ail_roll := 0.0
var ail_roll_target := 0.0
var ail_yaw := 0.0
var ail_yaw_target := 0.0


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
	return {"tuning": tuning.display_name, "control": GliderInput.name_of(control_scheme)}


func _unhandled_input(event: InputEvent) -> void:
	# T toggles TEST <-> PLAY tuning live.
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_T:
		toggle_tuning()
		_menu.refresh_labels()


func _physics_process(delta: float) -> void:
	## inputs
	adjust_ailerons(delta)
	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	rotate_object_local(Vector3.RIGHT, ail_pitch * tuning.pitch_mult * delta) # pitch
	rotate_object_local(Vector3.BACK, ail_roll * tuning.roll_mult * delta)    # roll
	rotate_object_local(Vector3.DOWN, ail_yaw * tuning.yaw_mult * delta)      # yaw (right = nose right)

	## speeds, directions and velocities from potential (pot) values
	# pot values
	if position.y > pot_height && position.y > 2.0:
		pot_height = position.y
	var d_h := pot_height - position.y
	var pot_speed := sqrt(d_h*G*2) # solved for speed in terms of d_h
	var nose_dir := (transform.basis * Vector3.FORWARD).normalized()
	# current values
	var current_speed := velocity.length()
	var current_dir := velocity.normalized() # TODO: look out for magnitude 0 velocity
	# new values
	var pot_speed_catchup := 1.0+tuning.pot_speed_catchup_mult*(0.1+current_speed)
	var new_speed := move_toward(current_speed, pot_speed, pot_speed_catchup * delta)
	var dir_offset := nose_dir - current_dir
	var pot_dir_catchup := tuning.pot_dir_catchup_mult * current_speed * dir_offset.length()
	var new_dir := current_dir.move_toward(nose_dir, pot_dir_catchup * delta)# TODO: calculate shortest direct arc from current_dir to pot_dir
	var new_velocity := new_speed * new_dir

	## forces
	# grav for no stuck (100% gravity when speed is 0)
	var dv_gravity := G*Vector3.DOWN * delta
	new_velocity += dv_gravity
	# drag: bleed pot energy when moving crosswise to the nose (1 - alignment)
	var alignment_drag_factor := (1.0 - nose_dir.dot(current_dir))
	pot_height -= tuning.drag * current_speed * alignment_drag_factor * delta
	if pot_height < 0:
		pot_height = 0
	if position.y < 2.0:
		pot_height += 5 * delta # recover pot for testing

	## velocity
	velocity = new_velocity

	_hud.set_readout(pot_height, tuning.display_name)
	move_and_slide()


func adjust_ailerons(delta: float) -> void:
	var targets := GliderInput.read_targets(control_scheme)
	ail_pitch_target = targets.x
	ail_roll_target = targets.y
	ail_yaw_target = targets.z

	ail_pitch = move_toward(ail_pitch, ail_pitch_target, tuning.ail_pitch_speed * delta)
	ail_roll = move_toward(ail_roll, ail_roll_target, tuning.ail_roll_speed * delta)
	ail_yaw = move_toward(ail_yaw, ail_yaw_target, tuning.ail_yaw_speed * delta)

	# Deflect each visual surface about its correct local hinge axis.
	$Ailerons/Pitch.rotation.x = ail_pitch * -SURFACE_DEFLECT  # elevator (both together)
	$Ailerons/LRoll.rotation.x = ail_roll * SURFACE_DEFLECT    # ailerons deflect
	$Ailerons/RRoll.rotation.x = ail_roll * -SURFACE_DEFLECT   # oppositely
	$Ailerons/Yaw.rotation.z = ail_yaw * SURFACE_DEFLECT       # rudder
