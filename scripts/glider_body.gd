extends CharacterBody3D


const TURN_SPEED = 2.5  # radians/sec
const JUMP_VELOCITY = 4.5
const G := 9.8


## Flight tuning: TEST = gentle accelerations (forces easy to see),
## PLAY = snappy. Toggle live with the T key. Applied via _apply_tuning().
enum Mode { TEST, PLAY }
@export var mode: Mode = Mode.TEST
const PRESETS := {
	Mode.TEST: {
		"AIL_PITCH_SPEED": 7.0, "AIL_ROLL_SPEED": 5.0, "AIL_YAW_SPEED": 7.0,
		"PITCH_MULT": 3.5, "ROLL_MULT": 5.0, "YAW_MULT": 2.0,
		"POT_SPEED_CATCHUP_MULT": 2.0, "POT_DIR_CATCHUP_MULT": 0.15, "DRAG": 1.0,
	},
	Mode.PLAY: {
		"AIL_PITCH_SPEED": 12.0, "AIL_ROLL_SPEED": 10.0, "AIL_YAW_SPEED": 12.0,
		"PITCH_MULT": 3.5, "ROLL_MULT": 5.0, "YAW_MULT": 2.0,
		"POT_SPEED_CATCHUP_MULT": 3.0, "POT_DIR_CATCHUP_MULT": 0.2, "DRAG": 0.2,
	},
}


## Ailerons (rate/authority values populated from PRESETS by _apply_tuning)
var AIL_PITCH_SPEED: float # 1/s: how fast a surface eases toward its target
var PITCH_MULT: float      # craft turn authority per unit of deflection
var AIL_ROLL_SPEED: float
var ROLL_MULT: float
var AIL_YAW_SPEED: float
var YAW_MULT: float
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
var _pot_label: Label
const PH_MARGIN := 0.1
#const POT_SPEED_CATCHUP := 20.0 # meters/s^2
var POT_SPEED_CATCHUP_MULT: float
#const POT_DIR_CATCHUP := 2.0 # radians / s
var POT_DIR_CATCHUP_MULT: float
var DRAG: float # pot-height bled per (speed * misalignment) per second
## Pot Height Equation:
# v1 at h1,ph1 allows us to get to ph1 under g deceleration:
# dH = v1


## Controls / pause menu
## RL: roll while air_roll held, else yaw. PILOT: roll always on stick,
## yaw on Q/E or LB/RB bumpers.
enum Scheme { RL, PILOT }
var control_scheme := Scheme.RL
var menu_open := false
var _menu_root: Control
var _tuning_btn: Button
var _control_btn: Button


func _ready() -> void:
	_apply_tuning()
	# Run even while the tree is paused so the menu's Esc still toggles it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Top-left HUD readout, built in code so no scene edit is needed.
	var layer := CanvasLayer.new()
	add_child(layer)
	_pot_label = Label.new()
	_pot_label.position = Vector2(12, 8)
	_pot_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_pot_label)
	_build_menu()


func _build_menu() -> void:
	var menu := CanvasLayer.new()
	menu.layer = 10
	menu.process_mode = Node.PROCESS_MODE_ALWAYS # clickable while paused
	add_child(menu)

	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.mouse_filter = Control.MOUSE_FILTER_STOP # eat clicks behind the menu
	_menu_root.visible = false
	menu.add_child(_menu_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_root.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "Paused"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_tuning_btn = Button.new()
	_tuning_btn.pressed.connect(_on_tuning_pressed)
	vbox.add_child(_tuning_btn)

	_control_btn = Button.new()
	_control_btn.pressed.connect(_on_control_pressed)
	vbox.add_child(_control_btn)

	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(_close_menu)
	vbox.add_child(resume)

	_refresh_menu_labels()


func _refresh_menu_labels() -> void:
	_tuning_btn.text = "Tuning: %s" % Mode.keys()[mode]
	_control_btn.text = "Controls: %s" % ("ROCKET LEAGUE" if control_scheme == Scheme.RL else "PILOT")


func _on_tuning_pressed() -> void:
	mode = Mode.PLAY if mode == Mode.TEST else Mode.TEST
	_apply_tuning()
	_refresh_menu_labels()


func _on_control_pressed() -> void:
	control_scheme = Scheme.PILOT if control_scheme == Scheme.RL else Scheme.RL
	_refresh_menu_labels()


const BINDS_TEXT := "[controls]\n" \
	+ "pitch/roll: W A S D\n" \
	+ "yaw (pilot): Q E / LB RB\n" \
	+ "air roll (RL): Shift / LB\n" \
	+ "camera: right stick\n" \
	+ "tuning TEST/PLAY: T / Back\n" \
	+ "scheme RL/PILOT: C / Start\n" \
	+ "pause: Esc"


func _open_menu() -> void:
	menu_open = true
	_menu_root.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _close_menu() -> void:
	menu_open = false
	_menu_root.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _apply_tuning() -> void:
	var preset: Dictionary = PRESETS[mode]
	for key: String in preset:
		set(key, preset[key])


func _unhandled_input(event: InputEvent) -> void:
	# Esc toggles the pause menu (keyboard only).
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		if menu_open: _close_menu()
		else: _open_menu()
	# T / Back toggles TEST <-> PLAY tuning live.
	elif event.is_action_pressed("toggle_tuning"):
		_on_tuning_pressed()
	# C / Start toggles RL <-> PILOT control scheme live.
	elif event.is_action_pressed("toggle_scheme"):
		_on_control_pressed()


func _physics_process(delta: float) -> void:
	if menu_open: # frozen while the menu is up (node is PROCESS_MODE_ALWAYS)
		return

	## inputs
	# adjust ailerons
	adjust_ailerons(delta)
	# The smoothed control surfaces drive the craft's rotation about its own
	# local axes, so control stays relative to the glider's orientation.
	rotate_object_local(Vector3.RIGHT, ail_pitch * PITCH_MULT * delta) # pitch
	rotate_object_local(Vector3.BACK, ail_roll * ROLL_MULT * delta)    # roll
	rotate_object_local(Vector3.DOWN, ail_yaw * YAW_MULT * delta)      # yaw (right = nose right)
	
	## speeds, directions and velocities from potential (pot) values
	# pot values
	if position.y > pot_height && position.y > 2.0:
		pot_height = position.y
	var d_h := pot_height - position.y
	var pot_speed := sqrt(d_h*G*2) # solved for speed in terms of d_h
	var nose_dir := (transform.basis * Vector3.FORWARD).normalized()
	#var pot_velocity := pot_speed*nose_dir
	# current values
	var current_speed := velocity.length()
	var current_dir := velocity.normalized() # TODO: look out for magnitude 0 velocity
	# new values
	var speed_offset := absf(pot_speed - current_speed)
	var pot_speed_catchup := 1.0+POT_SPEED_CATCHUP_MULT*(0.1+current_speed)
	var new_speed := move_toward(current_speed, pot_speed, pot_speed_catchup * delta)
	#if new_speed < 0.1:
			#new_speed += 0.1
	var dir_offset := nose_dir - current_dir
	var pot_dir_catchup := POT_DIR_CATCHUP_MULT * current_speed * dir_offset.length()
	var new_dir := current_dir.move_toward(nose_dir, pot_dir_catchup * delta)# TODO: calculate shortest direct arc from current_dir to pot_dir 
	var new_velocity := new_speed * new_dir
	
	## forces
	# grav for no stuck (100% gravity when speed is 0)
	var dv_gravity := G*Vector3.DOWN * delta
	new_velocity += dv_gravity
	# drag: bleed pot energy when moving crosswise to the nose (1 - alignment)
	var alignment_drag_factor := (1.0 - nose_dir.dot(current_dir))
	pot_height -= DRAG * current_speed * alignment_drag_factor * delta
	if pot_height < 0:
		pot_height = 0
	if position.y < 2.0:
		pot_height += 5 * delta # recover pot for testing
	
	## velocity
	velocity = new_velocity

	var scheme_name := "ROCKET LEAGUE" if control_scheme == Scheme.RL else "PILOT"
	_pot_label.text = "pot height: %.1f m\ntuning: %s\nscheme: %s\n\n%s" \
		% [pot_height, Mode.keys()[mode], scheme_name, BINDS_TEXT]

	
	#var speed := 0.0
	#if d_h < PH_MARGIN:
		#speed = 0.1
	#else:
		#speed = sqrt(d_h*G*2) # solved for speed in terms of d_h
	#
	#
	#var facing_dir := (transform.basis * Vector3.FORWARD).normalized()
	#var v_dir := velocity.normalized()
	#if v_dir:
		##var d_dir :=  
		#v_dir = v_dir.move_toward(facing_dir, 1.0 * delta).normalized()
	#else:
		#v_dir = facing_dir
	
	#if is_on_floor() && velocity.length() > 2.0:
		#var n_speed := velocity.length()*0.5 * delta
		#velocity *= 1 - (0.5 * delta)
		#var pot_dheight := velocity.length()**2/(G*2)
		#pot_height = position.y + pot_dheight
		
	move_and_slide()


func adjust_ailerons(delta: float) -> void:
	# Pitch from F/B. L/R rolls while air_roll is held, otherwise yaws (RL-style).
	ail_pitch_target = Input.get_axis("move_forward", "move_back")
	var lr := Input.get_axis("move_right", "move_left")
	if control_scheme == Scheme.RL:
		# L/R rolls while air_roll held, otherwise yaws.
		if Input.is_action_pressed("air_roll"):
			ail_roll_target = lr
			ail_yaw_target = 0.0
		else:
			ail_yaw_target = lr
			ail_roll_target = 0.0
	else: # PILOT: stick always rolls; yaw on Q/E or LB/RB.
		ail_roll_target = lr
		ail_yaw_target = Input.get_axis("yaw_left", "yaw_right")

	ail_pitch = move_toward(ail_pitch, ail_pitch_target, AIL_PITCH_SPEED * delta)
	ail_roll = move_toward(ail_roll, ail_roll_target, AIL_ROLL_SPEED * delta)
	ail_yaw = move_toward(ail_yaw, ail_yaw_target, AIL_YAW_SPEED * delta)

	# Deflect each visual surface about its correct local hinge axis.
	$Ailerons/Pitch.rotation.x = ail_pitch * -SURFACE_DEFLECT  # elevator (both together)
	$Ailerons/LRoll.rotation.x = ail_roll * SURFACE_DEFLECT    # ailerons deflect
	$Ailerons/RRoll.rotation.x = ail_roll * -SURFACE_DEFLECT   # oppositely
	$Ailerons/Yaw.rotation.z = ail_yaw * SURFACE_DEFLECT       # rudder
