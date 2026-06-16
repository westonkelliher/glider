extends Node3D
## Tutorial scene entry point (run with F6). Wires the existing glider + camera,
## spawns the UI and the stage manager, and starts the sequence. Self-contained
## so it never touches the main game scene.

@onready var glider: Glider = $GliderBody
@onready var camera_rig: Node3D = $CameraRig
@onready var props: Node3D = $Props

var ui: TutorialUI = null
var manager: TutorialManager = null


func _ready() -> void:
	# Point the camera at the player glider, follow its velocity by default.
	camera_rig.set("target", glider)
	camera_rig.set("ball", null)

	ui = TutorialUI.new()
	add_child(ui)

	manager = TutorialManager.new()
	add_child(manager)
	manager.setup(glider, ui, props, camera_rig)
	manager.begin()

	# Show the cursor so the Restart / Skip buttons are clickable (the camera rig
	# captures the mouse on _ready). Deferred so it wins over the camera's call.
	call_deferred("_show_cursor")


func _show_cursor() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
