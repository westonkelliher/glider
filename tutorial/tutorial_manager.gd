class_name TutorialManager
extends Node
## Drives the stage sequence. Loads each stage script, places the glider, builds
## props, runs the intro -> play -> medal flow, and advances. The on-screen
## Restart / Skip buttons (TutorialUI) drive _on_restart / _on_skip.

const GLIDER_DISPLAY_SCALE: float = 2.5

## Ordered stage scripts. Add new stages here.
const STAGE_PATHS: Array[String] = [
	"res://tutorial/stages/stage_01_grip.gd",
	"res://tutorial/stages/stage_02_roll_yaw.gd",
	"res://tutorial/stages/stage_02_steer.gd",
	"res://tutorial/stages/stage_03_energy.gd",
	"res://tutorial/stages/stage_04_drift.gd",
	"res://tutorial/stages/stage_05_boost.gd",
	"res://tutorial/stages/stage_06_brake.gd",
	"res://tutorial/stages/stage_07_ballcam.gd",
	"res://tutorial/stages/stage_08_dribble.gd",
	"res://tutorial/stages/stage_09_score.gd",
]

## VELOCITY follow-cam: the sane default for flight stages (ball stages opt in).
const CAM_VELOCITY: int = 2

## Loaded after the final stage — a full match against the AI.
const MATCH_SCENE: String = "res://scenes/main.tscn"

## Returned to when the player exits the tutorials.
const MENU_SCENE: String = "res://scenes/main_menu.tscn"

enum State { INTRO, PLAYING, COMPLETE }

var glider: Glider = null
var ui: TutorialUI = null
var props_root: Node3D = null
var camera: Node3D = null
var input_ctl: TutorialController = null

var _idx: int = 0
var _state: int = State.INTRO
var _stage: TutorialStage = null
var _elapsed: float = 0.0
var _timed: bool = false


func setup(g: Glider, u: TutorialUI, props: Node3D, cam: Node3D) -> void:
	glider = g
	ui = u
	props_root = props
	camera = cam
	# Replace the glider's human controller with one that masks untaught powers.
	input_ctl = TutorialController.new()
	glider.controller = input_ctl
	ui.restart_requested.connect(_on_restart)
	ui.skip_requested.connect(_on_skip)
	ui.back_requested.connect(_on_back)
	ui.exit_requested.connect(_on_exit)


func _on_restart() -> void:
	_load_stage(_idx)


func _on_skip() -> void:
	if _idx >= STAGE_PATHS.size() - 1:
		_start_match()
	else:
		_load_stage(_idx + 1)


## Step back to the previous stage. No-op on the first stage.
func _on_back() -> void:
	if _idx > 0:
		_load_stage(_idx - 1)


## Leave the tutorials and return to the main menu.
func _on_exit() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)


## Leave the tutorial and drop into a full match against the AI.
func _start_match() -> void:
	get_tree().change_scene_to_file(MATCH_SCENE)


func begin() -> void:
	_load_stage(0)


func _load_stage(index: int) -> void:
	if _stage != null:
		_stage.teardown()
		_stage.queue_free()
		_stage = null
	_idx = clampi(index, 0, STAGE_PATHS.size() - 1)
	ui.clear_banner()
	ui.set_back_enabled(_idx > 0)
	_elapsed = 0.0

	var script: GDScript = load(STAGE_PATHS[_idx]) as GDScript
	if script == null:
		ui.set_header("Missing stage")
		ui.set_objective("Could not load %s" % STAGE_PATHS[_idx])
		return
	# Reset the camera to the flight default; ball stages re-register a ball and
	# the player opts into ball-cam themselves.
	if camera != null:
		camera.set("ball", null)
		camera.set("mode", CAM_VELOCITY)

	_stage = script.new() as TutorialStage
	_stage.glider = glider
	_stage.ui = ui
	_stage.camera = camera
	props_root.add_child(_stage)
	# Unlock only the powers this stage teaches.
	input_ctl.boost_allowed = _stage.allow_boost()
	input_ctl.slow_allowed = _stage.allow_slow()
	_stage.completed.connect(_on_stage_completed)
	_stage.failed.connect(_on_stage_failed)

	_place_glider(_stage.start_pose())
	# Freeze the craft while the intro panel is up: its flight model logs a
	# normalize warning at zero velocity, and a still glider reads better.
	glider.set_physics_process(false)
	_stage.build()

	_timed = _stage.par_time() > 0.0
	ui.set_header(_stage.stage_title())
	ui.set_objective("")
	ui.set_hint("")
	ui.set_timer(-1.0)
	ui.intro(_stage.stage_title(), _stage.intro_lines())
	_state = State.INTRO


func _place_glider(pose: Transform3D) -> void:
	var scaled: Basis = pose.basis.scaled(Vector3.ONE * GLIDER_DISPLAY_SCALE)
	glider.global_transform = Transform3D(scaled, pose.origin)
	glider.velocity = Vector3.ZERO
	glider.pot_height = pose.origin.y
	glider.ail_pitch = 0.0
	glider.ail_pitch_target = 0.0
	glider.ail_pitch_speed = 0.0
	glider.ail_roll = 0.0
	glider.ail_roll_target = 0.0
	glider.ail_roll_speed = 0.0
	glider.ail_yaw = 0.0
	glider.ail_yaw_target = 0.0
	glider.ail_yaw_speed = 0.0
	glider.wing_extension = 1.0


func _begin_play() -> void:
	ui.dismiss_intro()
	glider.set_physics_process(true)
	_state = State.PLAYING
	_elapsed = 0.0
	if _timed:
		ui.set_timer(0.0)
	_stage.on_begin()


func _on_stage_completed() -> void:
	if _state != State.PLAYING:
		return
	_state = State.COMPLETE
	var msg: String = "STAGE COMPLETE"
	var col: Color = Color(0.4, 1.0, 0.5)
	if _timed:
		var par: float = _stage.par_time()
		if _elapsed <= par:
			msg = "GOLD  ·  %.2fs" % _elapsed
			col = Color(1.0, 0.85, 0.2)
		else:
			msg = "CLEAR  ·  %.2fs  (par %.2fs)" % [_elapsed, par]
	var tail: String = "Next stage" if _idx < STAGE_PATHS.size() - 1 else "Start match vs AI"
	ui.banner("%s\n\n[ Space / A: %s ]" % [msg, tail], col)


func _on_stage_failed(reason: String) -> void:
	if _state != State.PLAYING:
		return
	ui.set_hint("✗ %s — resetting…" % reason)
	_load_stage(_idx)


func _physics_process(delta: float) -> void:
	if _stage == null:
		return
	match _state:
		State.PLAYING:
			_elapsed += delta
			if _timed:
				ui.set_timer(_elapsed)
			_stage.update(delta)


func _unhandled_input(event: InputEvent) -> void:
	# The Back button (mapped to "reset") restarts the current stage, mirroring
	# how it resets a match.
	if event.is_action_pressed("reset"):
		_on_restart()
		return
	var accept: bool = event.is_action_pressed("ui_accept") or event.is_action_pressed("launch")
	match _state:
		State.INTRO:
			if accept:
				_begin_play()
		State.COMPLETE:
			if accept:
				if _idx < STAGE_PATHS.size() - 1:
					_load_stage(_idx + 1)
				else:
					_start_match()
		State.PLAYING:
			pass
